# coding: utf-8

require 'priority_queue'
require 'trollop'
# require 'active_support/core_ext/hash'

class String 

	def last
		self[-1,1]
	end

	def insert!(appending_string)
		self[0,0] = appending_string
	end

end

module Cake

	@@opt = {}

	@@key = {}

	class << self

		def options
			@@opt
		end

		def options=(hash)
			@@opt = hash.inject({}){|memo,(key,value)| memo[key] = key==:mode ? value.to_sym : value; memo}
		end

		def key
			@@key
		end

		def key=(hash)
			@@key.merge! hash
		end

		def encode
			puts "Input size: #{File.size(@@opt[:file]).round}"
			extension = File.extname(@@opt[:file])
			file_name = File.basename(@@opt[:file], extension)
			path = File.dirname(@@opt[:file])
			result = BWT::encode(File.read(@@opt[:file]))
			encoding = Huffman::huffman_encoding result
			result = Huffman::encode(result, encoding)
			puts "Output size: #{(result.join.length/8.0).round}"
			Cake::key = {extension: extension, huffman_encoding: encoding, length: result.join.length}
			write_to_file(result, file_name, path)
		end

		def decode
			raise "Key should be a file with *.donut extension" if File.extname(@@opt[:pubkey])!=".donut"
			extension = File.extname(@@opt[:file])
			raise "You could decode files with *.cake extension only!" if extension!=".cake"
			file_name = File.basename(@@opt[:file], extension)
			@@key = eval File.read(@@opt[:pubkey])
			raise "You should use the same algorithm as you used for incoding!" if @@opt[:mode]==:RLE and @@key.has_key?(:mtf_alphabet)
			unpacked = File.binread(@@opt[:file]).unpack("B*")[0]
			result = Huffman::decode(unpacked[0..@@key[:length]-unpacked.length-1], @@key[:huffman_encoding])
			result = BWT::decode result
			IO.write("#{File.dirname(@@opt[:file])}/#{file_name}.awesome#{@@key[:extension]}", result)
		end

		def debug(string)
			puts string if @@opt[:verbose]
		end

		def write_to_file(result, name="enot.awesome", path)
			IO.write("#{path}/#{name}.donut", Cake::key)
			File.open("#{path}/#{name}.cake", 'wb' ) do |output|
				output.write [result.join].pack("B*")
			end
		end

	end

	class BWT

		class << self

			def encode(initial_string)
				encoded_string = bwt_encode initial_string
				Cake::debug "BWT encoded: #{encoded_string.join}"
				mode = Cake::options[:mode]
				encoded_string = mode==:MTF ? mtf_encode(encoded_string) : rle_encode(encoded_string.join)
				Cake::debug "#{mode} encoded: #{eval(encoded_string).join}"
				encoded_string
			end

			def decode(encoded_string)
				mode = Cake::options[:mode]
				decoded_string = mode==:MTF ? mtf_decode(eval(encoded_string)) : rle_decode(eval(encoded_string)).split('')
				Cake::debug "#{mode} decoded: #{decoded_string.join}"
				decoded_string = bwt_decode decoded_string
				Cake::debug "BWT decoded: #{decoded_string}"
				decoded_string
			end

			private

				def bwt_encode(string)
					matrix = [] << string
					initial_array = string.split('')#.force_encoding("iso-8859-1").split('')
					((initial_array.count)-1).times { matrix << initial_array.rotate!.join }
					matrix.sort!
					old_index = matrix.index(string)
					Cake::key = { bwt_index: old_index }
					matrix.map(&:last)
				end

				def bwt_decode(string)
					index = Cake::key[:bwt_index]
					matrix = string.join.split('').sort
					((string.count)-1).times do
						matrix.zip(string).map! { |first_c, last_c| first_c.insert! last_c }
						matrix.sort!
					end
					matrix[index.to_i]
				end

				def mtf_encode(string)
					alphabet = string.sort_by(&:to_s).uniq!
					encoded_string = []
					string.each do |char|
						encoded_string << alphabet.index(char)
						alphabet.insert(0, alphabet.delete(char))
					end
					Cake::key = { mtf_alphabet: alphabet}
					encoded_string.inspect
				end

				def mtf_decode(string)
					alphabet = Cake::key[:mtf_alphabet].sort_by!(&:to_s)
					decoded_string = []
					string.each do |index|
						alphabet_char = alphabet[index]
						decoded_string << alphabet_char
						alphabet.insert(0, alphabet.delete_at(index))
					end
					decoded_string
				end

				def rle_encode(string)
					string.scan(/(.)(\1*)/).collect{ |char, repeat| [1 + repeat.length, char] }.inspect
				end

				def rle_decode(string)
					string.collect { |length, char| char * length }.join
				end

		end
		
	end

	class Huffman

		class << self

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
				string.each_char.collect {|char| encoding[char]}
				#string.each_char.collect {|char| encoding[char]}.join
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
end

p = Trollop::Parser.new do
	version "Cake 0.0.1 (c) 2013 Ivan Kozlov"
	banner <<-EOS
Cake - the most awesome file archiver ever!
Usage:
 test [options] <filename>*
 where [options] are:
EOS
	opt :encode, "Use encode operation", short: "-e"
	opt :decode, "Use decode operation", short: "-d"
	opt :file, "File to encode/decode", type: :string, short: "-f"
	opt :pubkey, "Key to unarchieve", type: :string, short: "-k"
	opt :mode, "BWT post encoding mode MTF/RLE", type: :string, short: "-m", default: "MTF"
	opt :verbose, "Enable verbose mode", short: "-v"
	opt :enot,  "For Huffman only compute", type: :string
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

if !options.decode.nil? and options.pubkey.nil?
	abort <<-EOS
Error: argument --key You can't decode wothout a key
Try --help for help.
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

##################### MAIN CODE #####################

if options[:enot]
	puts "#"*10 + " Encoding: " + "#"*10
	text = options[:enot]
	encoding = Cake::Huffman::huffman_encoding text
	encoding.to_a.sort.each {|x| p x}
	puts "#"*10 + " Huffman code: " + "#"*10
	result = Cake::Huffman::encode(text, encoding)
	puts result.inspect
	Cake::write_to_file result
	abort
end

Cake::options = options

if options.encode
	Cake::encode
elsif options.decode
	Cake::decode
end



