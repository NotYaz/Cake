#!ruby
require 'strscan'
require 'stringio'

# A useful method for my priority queue implementation
class Array
    def swap(a,b)
        self[a], self[b] = self[b], self[a]
    end
end

# Inspired by, but totally different from, the heap in
# ruby quiz 40
class PriorityQueue
    # Actually, this is more inspired by the summary on
    # quiz number 98 than the implementation in quiz 40.
    def initialize
        @items=[]
        @priorities=[]
    end

    def add(priority, item)
        @priorities.push priority
        @items.push item
        bubble_up
        self
    end

    def empty?
        @items.empty?
    end

    def shift
        return nil if empty?
        retval = @items.shift
        @priorities.shift
        if ! @items.empty? then
            @priorities.unshift @priorities.pop
            @items.unshift @items.pop
            bubble_down
        end
        retval
    end

    # Inspired by mapn in quiz 122
    def eachn(&b)
        arglen = b.arity
        while !empty?
            args = Array.new(arglen){shift}
            b.call(*args)
        end
    end

    private

    def bubble_up
        wi = @priorities.size - 1
        pr = @priorities[wi]
        until wi == 0
            pi = (wi-1)/2
            return if @priorities[pi] <= pr
            @items.swap(pi,wi)
            @priorities.swap(pi,wi)
            wi = pi
        end
    end

    def bubble_down
        wi = 0
        pr = @priorities[wi]
        until false   # i.e. until I return
            ci = 2*wi + 1
            return if ci >= @priorities.size
            ci += 1 if ci + 1 < @priorities.size and
                        @priorities[ci+1] < @priorities[ci]
            return if @priorities[ci] >= pr
            @items.swap(ci,wi)
            @priorities.swap(ci,wi)
            wi = ci
        end
    end
end

# Okay, that's all for utilities.  Now on with stuff for this quiz;
# basically, I have two classes: HuffmanNode and HuffmanCoder.
# HuffmanNode is the tree structure.  HuffmanCoder handles the
# dirty business of encoding and decoding given the tree structure.

# A HuffmanNode either has data or it has both left and right children,
# but not both.

HuffmanNode = Struct.new("HuffmanNode", :frequency, :data, :left, 
:right)

class HuffmanNode
    def inspect
        "HuffmanNode.from_s(#{to_s.inspect})"
    end

    def to_s
        if self.data.nil? then
            "(" + self.left.to_s + ' ' + self.right.to_s + ")"
        else
            self.data.to_s
        end
    end

    def to_h(forencode, prefix='')
        if self.data.nil? then
            l = self.left.to_h(forencode,prefix + '0')
            r = self.right.to_h(forencode,prefix + '1')
            l.update(r)
        else
            if forencode then
                {self.data => prefix}
            else
                {prefix => self.data}
            end
        end
    end

    def HuffmanNode.from_s(s)
        begin
            return from_s_internal(StringScanner.new(s))
        rescue
            raise "Malformed string: '#{s}'"
        end
    end

    def HuffmanNode.from_s_internal(scanner)
        data = scanner.scan(/\s*-?\d+/)
        if data.nil? then
            scanner.scan(/\s*\(/) or raise 'err'
            rei = from_s_internal(scanner)
            scanner.scan(/\s+/) or raise 'err'
            ichi = from_s_internal(scanner)
            scanner.scan(/\s*\)/) or raise 'err'
            return new(0,nil,rei,ichi)
        else
            return new(0,data.to_i,nil,nil)
        end
    end

    def HuffmanNode.make_tree(freqhash, add_everything=false)
        pqueue = PriorityQueue.new
        # node with data -1 is used to mean "end of data"
        universe = {-1=>1}
        if add_everything then
            # Assume anything we haven't seen at all is an order of
            # magnitude less likely than those things we've seen once
            256.times{|i|universe[i]=0.1;}
        end
        universe.update(freqhash)
        universe.each {|charcode,freq|
            pqueue.add(freq, new(freq,charcode,nil,nil))
        }
        pqueue.eachn {|node1, node2|
            return node1 if node2.nil?

            n = new(node1.frequency + node2.frequency, \
                            nil, node2, node1)
            pqueue.add(n.frequency, n)
        }
    end
end

class HuffmanCoder
    attr :enchash
    attr :dechash
    attr :decre
    def initialize(nodetree)
        @enchash = nodetree.to_h(true)
        @dechash = nodetree.to_h(false)
        @decre = Regexp.new('^(' + @dechash.keys.join('|') + ')(.*)')
    end

    def encode(io_in,io_out,crunch_binary=true,io_stats=$stderr)
        buff = ''
        outbytes = 0
        inbytes = 0
        io_out.puts "Encoded:" unless crunch_binary
        encode_bits(io_in) { |bits|
            inbytes += 1
            if bits then
                buff += bits
            else
                buff += '0' * ((-buff.length) %  8 )
            end
            while buff.length >= 8 do
                binary = buff.slice!(0..7)
                if crunch_binary then
                    binary = [binary].pack("b*")
                else
                    binary = binary + ' '
                    binary += "\n" if 4 == outbytes % 5
                end
                io_out.print binary
                outbytes += 1
            end
        }
        if 0 != outbytes % 5 and not crunch_binary then
            io_out.print "\n"
        end
        inbytes -= 2
        if io_stats then
            io_stats.puts "Original Bytes: #{inbytes}"
            io_stats.puts "Encoded Bytes: #{outbytes}"
            io_stats.puts "Compressed: %2.1f%%"%  [100.0 - 
(100.0*outbytes)/inbytes]
        end
    end

    def decode(io_in,io_out,crunched_binary=true,io_stats=$stderr)
        buff = ''
        outbytes = 0
        inbytes = decode_bits(io_in,crunched_binary) { |bits|
            buff += bits
            m = @decre.match buff
            while m do
                ch = @dechash[m[1]]
                if ch == -1
                    if m[2] !~ /^0*$/ then
                        raise "Garbage after EOD marker"
                    end
                    break
                end
                io_out.putc ch
                outbytes += 1
                buff = m[2]
                m = @decre.match buff
            end
        }
        if io_stats then
            io_stats.puts "Encoded Bytes: #{inbytes}"
            io_stats.puts "Original Bytes: #{outbytes}"
            io_stats.puts "Compressed: %2.1f%%"%  [100.0 - 
(100.0*inbytes)/outbytes]
        end
    end

    def HuffmanCoder.from_file(treefile)
        tree = nil
        File.open(treefile, "r") { |f|
            treetxt = ''
            f.each{ |treeline| treetxt += treeline }
            tree = HuffmanNode.from_s(treetxt)
        }
        new(tree)
    end

    def HuffmanCoder.generate(io_in, treefile, generate_extended, 
io_stats=$stderr)
        bytecount = 0
        d = Hash.new(0);
        io_in.each_byte {|b| d[b] += 1; bytecount += 1}
        tree = HuffmanNode.make_tree(d,generate_extended)
        if ! treefile.nil?
            File.open(treefile, "w") {|f|
                f.puts tree.to_s
            }
        end
        if io_stats then
            io_stats.puts "Generated tree from input size #{bytecount}"
        end
        new(tree)
    end

    private

    def encode_bits(io_in)
        c = io_in.getc
        until c.nil?
            bits = @enchash[c]
            raise "no code for character #{c}" unless bits
            yield bits
            c = io_in.getc
        end
        yield @enchash[-1]
        yield nil
    end

    def decode_bits(io_in,crunched_binary)
        inbytes = 0
        if crunched_binary then
            until io_in.eof?
                b = io_in.read(4096)
                return if b.nil?
                inbytes += b.length
                yield b.unpack('b*')[0]
            end
        else
            until io_in.eof?
                b = io_in.read(4096)
                return if b.nil?
                b.tr!('^01','')
                inbytes += b.length
                yield b if b.length > 0
            end
            inbytes = (inbytes+7)/8
        end
        inbytes
    end
end

# That's all the interesting stuff.  Everything from here down is
# argument handling.  Basically uninteresting.

if __FILE__ == $0 then
    mode = :encode
    input = nil
    output = nil
    treefile = nil
    crunched_binary = true
    generate_extended = false
    statschannel = $stderr
    while ARGV[0] and ARGV[0] =~ /^-/
        opt = ARGV.shift
        case opt
        when '--'
            break
        when '-t'
            treefile = ARGV.shift
        when '-i'
            input = ARGV.shift
        when '-o'
            output = ARGV.shift
        when '-d'
            mode = :decode
        when '-b'
            crunched_binary = false
        when '-q'
            statschannel = nil
        when '-g'
            mode = :gentree
        when '-x'
            mode = :gentree
            generate_extended = true
        when '-h'
            puts "Usage:"
            puts "Generate tree: #{$0} -g -t treefile [opts|phrase]"
            puts "       encode: #{$0} -t treefile [opts|phrase]"
            puts "       decode: #{$0} -d -t treefile [opts|phrase]"
            puts "[opts]: -i input -o output"
            puts "        -b flip binary mode (default is 0s and 1s"
            puts "           if -o is not given, and bytes if -o is)"
            puts "        -x generate extended tree to also cover bytes"
            puts "           not present in the training input"
            puts "        -q be quiet - no statistics"
            exit 0
        else
            $stderr.puts "Unrecognized option #{opt} -- use -h for help"
            exit 1
        end
    end
    if treefile.nil? then
        # allow no treefile only when encoding command line
        # stuff as a demo.
        if ! (input.nil? and mode == :encode)
            $stderr.puts "Error: no -t option given"
            exit 1
        end
    end
    in_io = nil
    if input.nil?
        in_io = StringIO.new(ARGV.join(' '))
        crunched_binary = ! crunched_binary if mode == :decode
    elsif input == '-'
        in_io = $stdin
    else
        in_io = File.open(input, "rb")
    end
    out_io = nil
    if output.nil?
        out_io = $stdout
        crunched_binary = ! crunched_binary if mode == :encode
    elsif output == '-'
        out_io = $stdout
    else
        out_io = File.open(output, "wb")
    end
    if mode == :gentree then
        HuffmanCoder.generate(in_io, treefile, generate_extended,
                                statschannel)
    else
        coder = nil
        if (treefile.nil?)
            coder = HuffmanCoder.generate(in_io, nil, false, nil)
            in_io.rewind
        else
            coder = HuffmanCoder.from_file(treefile)
        end
        coder.send(mode, in_io,out_io, crunched_binary, statschannel)
    end
end