
require 'priority_queue'
require 'trollop'

module Cake

	class String 

		def last
			self[-1,1]
		end

		def insert!(appending_string)
			self[0,0] = appending_string
		end
		
	end

	class BWT

		def initialize(options)
			@verbose = options.verbose || false
			@mode = options.mode || :mtf
		end
		
		def encode(initial_string)
			encoded_string = bwt_encode initial_string
			puts "BWT encoded: #{encoded_string.join}" if @verbose
			encoded_string = @mode==:mtf ? mtf_encode(encoded_string) : rle_encode(encoded_string.join)
			puts "#{mode.capitalize} encoded: #{encoded_string.join}" if @verbose
			encoded_string
		end

		def decode(encoded_string)
			decoded_string = @mode==:mtf ? mtf_decode(encoded_string) : rle_decode(encoded_string).split('')
			puts "#{mode.capitalize} decoded: #{decoded_string.join}" if @verbose
			decoded_string = bwt_decode decoded_string
			puts "BWT decoded: #{decoded_string}" if @verbose
			decoded_string
		end

		private

			def bwt_encode(string)
				matrix = [] << string
				initial_array = string.split('')
				((initial_array.count)-1).times { matrix << initial_array.rotate!.join }
				matrix.sort!
				old_index = matrix.index(string)
				matrix.map(&:last).unshift(old_index)
			end

			def bwt_decode(string)
				index = string.shift
				matrix = string.join.split('').sort
				((string.count)-1).times do
					matrix.zip(string).map! { |first_c, last_c| first_c.insert! last_c }
					matrix.sort!
				end
				matrix[index.to_i]
			end

			def mtf_encode(string)
				@alphabet = string.sort_by(&:to_s).uniq!
				encoded_string = []
				string.each do |char|
					encoded_string << @alphabet.index(char)
					@alphabet.insert(0, @alphabet.delete(char))
				end
				encoded_string
			end

			def mtf_decode(string)
				@alphabet = @alphabet.sort_by!(&:to_s)
				decoded_string = []
				string.each do |index|
					alphabet_char = @alphabet[index]
					decoded_string << alphabet_char
					@alphabet.insert(0, @alphabet.delete_at(index))
				end
				decoded_string
			end

			def rle_encode(string)
				string.scan(/(.)(\1*)/).collect{ |char, repeat| [1 + repeat.length, char] }
			end

			def rle_decode(string)
				string.collect { |length, char| char * length }.join
			end
		
	end

	class Huffman

		def huffman_encoding(string)
			char_count = Hash.new(0)
			string.each_char {|char| char_count[char] += 1}
			priority_queue = CPriorityQueue.new
			char_count.each {|char, count| priority_queue.push(char, count)}
			while priority_queue.length > 1
				first_key, first_priority = priority_queue.delete_min
				second_key, second_priority = priority_queue.delete_min
				priority_queue.push([first_key, second_key], first_priority + second_priority)
			end
			Hash[*generate_encoding(priority_queue.min_key)]
		end
	 
		def generate_encoding(ary, prefix="")
			case ary
				when Array
					generate_encoding(ary[0], "#{prefix}0") + generate_encoding(ary[1], "#{prefix}1")
				else
					[ary, prefix]
				end
		end
	 
		def encode(string, encoding)
			string.each_char.collect {|char| encoding[char]}.join
		end
		 
		def decode(encoded_string, encoding)
			rev_enc = encoding.invert
			decoded = ""
			pos = 0
			while pos < encoded_string.length
				key = ""
				while rev_enc[key].nil?
					key << encoded_string[pos]
					pos += 1
				end
				decoded << rev_enc[key]
			end
			decoded
		end
		
	end
end

# bwt = BWT.new false
# encoded_string = bwt.encode ARGV[0], false, :rle
# puts "Result: #{encoded_string.join}"
# decoded_string = bwt.decode encoded_string, false, :rle
# puts "Result: #{decoded_string}"

# str = "this is an example for huffman encoding"
# p str
# huffman = Huffman.new("hello")
# encoding = huffman.huffman_encoding(str)
# encoding.to_a.sort.each {|x| p x}
 
# enc = huffman.encode(str, encoding)
# dec = huffman.decode(enc, encoding)
# puts "success!" if str == dec

p = Trollop::Parser.new do
	version "Cake 0.0.1 (c) 2013 Ivan Kozlov"
	banner <<-EOS
Cake - the most awesome file archiver ever!
Usage:
 test [options] <filename>
 where [options] are:
EOS
	opt :encode, "Use encode operation", short: "-e"
	opt :decode, "Use decode operation", short: "-d"
	opt :file, "File to encode/decode", type: :string, short: "-f"
	opt :mode, "BWT post encoding mode MTF/RLE", type: :string, short: "-m", default: "MTF"
	opt :verbose, "Enable verbose mode", short: "-v"
end

options = Trollop::with_standard_exception_handling p do
	raise Trollop::HelpNeeded if ARGV.empty?
	p.parse ARGV
end

if options.encode.nil? and options.decode.nil?
	abort <<-EOS
Error: argument --encode/--decode One of these options is required.
Try --help for help.
EOS
end

if options.file.nil? or options.file.empty?
	abort <<-EOS
Error: argument --file This option is required.
Try --help for help.
EOS
end

if options.mode != "MTF" and options.mode != "RLE"
	abort <<-EOS
Error: argument --mode This option could be 'MTF' or 'RLE'.
Try --help for help.
EOS
end
