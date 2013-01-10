#!/usr/bin/ruby

require 'set'

module SmarterCSV

	class Parser
		def initialize options={}
			@options = options

			@separator = (options[:separator] or ";")
			@quote     = (options[:quote] or "\"")
			@newline   = (options[:newline] or "\n")
			@escape    = (options[:escape] or "\\")

			@column    = 1
			@line      = 1

			@state = :BEFORE_FIELD

			@field, @row = "", []
		end
		def emit_field
			@row << @field
			if on_field = @options[:on_field] then on_field.call @field end
		end
		def emit_row
			if on_row = @options[:on_row] then on_row.call @row end
		end
		def got_field
			emit_field
			@field = ""
		end
		def got_row
			emit_row
			@row = []
		end
		def push token
			@field += token
		end
		def consume token
			#puts "#{@state} - Token: #{token}"
			@state = case @state
			when :BEFORE_FIELD
				case token
				when @separator
					got_field
					:BEFORE_FIELD
				when @quote
					:QOTED_FIELD
				when @newline
					got_field
					got_row
					:BEFORE_FIELD
				else
					push token
					:FIELD
				end
			when :FIELD
				case token
				when @newline
					got_field
					got_row
					:BEFORE_FIELD
				when @separator
					got_field
					:BEFORE_FIELD
				else
					push token
					:FIELD
				end
			when :QOTED_FIELD
				case token
				when @escape
					:MAYBE_ESCAPED_QUOTE
				when @quote
					:BEFORE_SEPARATOR
				else
					push token
					:QOTED_FIELD
				end
			when :MAYBE_ESCAPED_QUOTE
				case token
				when @quote
					push @quote
					:QOTED_FIELD
				else
					push @escape
					push @quote
					:QOTED_FIELD
				end
			when :BEFORE_SEPARATOR
				case token
				when @separator
					got_field
					:BEFORE_FIELD
				when @newline
					got_field
					got_row
					:BEFORE_FIELD
				else
					raise "Error: Separator or newline expected! Got: #{token} at (#{@line}:#{@column})"
				end
			end
			
			if token == @newline
				@column =  1
				@line   += 1
			else
				@column += token.length
			end
			#puts "Switched to #{@state}"
		end
		def << str
			str.each_char do |c|
				consume c
			end
		end
	end


	class Row
		
		def initialize table, data
			@table  = table
			@values = {}
			if @table.has_headers and @table.headers.empty?
				@table.headers = data.map{|h| unique_header_name h}
				data.each {|h| @values[h] = h}
			else
				for i in 0 ... data.count
					@table.headers << unique_header_name(i) unless @table.headers[i]
					@values[@table.headers[i]] = data[i]
				end
			end
		end

		def unique_header_name h
			name = h.to_s
			name ="_#{name}" while @table.header_set.include? name
			@table.header_set << name
			name
		end

		def headers
			@table.headers
		end

		def each_column
			headers.each do |h|
				yield @values[h]
			end
		end

		def each_column_with_header
			headers.each do |h|
				yield h, @values[h]
			end
		end

		def to_s
			@table.headers.map{|h| @values[h]}.join(", ")
		end

	end


	class BaseTable
		attr_accessor :headers, :has_headers, :header_set
		def initialize options={}
			
			final_options = options.merge(:has_headers => true)

			@has_headers = final_options[:has_headers]
			@headers     = (final_options[:headers] or [])
			@header_set  = Set.new
		end
	end

	class StreamTable < BaseTable
		def initialize options={}
			super options
			
			on_row = lambda do |r|
				hdr = (@has_headers and @headers.empty?)
				row = Row.new self, r
				yield row unless hdr
			end

			@parser = Parser.new options.merge(:on_row => on_row)
		end

		def << str
			str.each_char{|c| @parser << c}
		end
	end

	class Table < StreamTable
		
		def initialize options={}
			@rows = []

			super options do |row|
				@rows << row
				yield row if block_given?
			end
		end

		def add_row data
			row = Row.new self, data
			@rows << row unless is_header
		end

		def each_row
			@rows.each do |row|
				yield row
			end
		end

		def to_s
			"("+@headers.join(", ")+")"+"\n"+@rows.map{|r| r.to_s}.join("\n")
		end
	end

	def self.read_string str, options={}
		t = Table.new(options)
		t << str
		t
	end

	def self.read_file path, options={}
		self.read_string File.new(path), options
	end

	def self.each_row_in_file path, options={}
		t = StreamTable.new options do |row|
			yield row
		end
		File.new(path).each_line do |line|
			t << line
		end
		t
	end

end
	

data = <<EOF
z;2
a;b;c
"d";e;f
"\\"g\\"hi";j;"k";lm"n
x;y;
EOF

if false


t = SmarterCSV::Table.new do |row|
	puts row
end

t << data

puts t
end

t=SmarterCSV.each_row_in_file("/home/fram/Downloads/_1.5.3.1_bk.csv") do |row|
	puts row
end