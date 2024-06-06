#!/usr/bin/ruby
require 'csv'
require 'time'
require 'psych'
require 'typhoeus'
require 'optparse'

def wrap(s, width=78, indent=23)
	lines = []
	line, s = s[0..indent-2], s[indent..-1]
  s.split(/\n/).each do |ss|
    ss.split(/[ \t]+/).each do |word|
      if line.size + word.size >= width
        lines << line
        line = (" " * (indent)) + word
      else
        line << " " << word
      end
    end
    lines << line if line
    line = (" " * (indent-1))
  end
	return lines.join "\n"
end

ARGV.options { |opt|
  opt.summary_indent = ' ' * 2
  opt.summary_width = 20
  opt.banner = "Usage:\n#{opt.summary_indent}#{File.basename($0)} TARGET (URL|FILE)\n"
  opt.on("Options:")
  opt.on("--help", "-h", "This text") { puts opt; exit }
	opt.on("")
  opt.on(wrap("[TARGET]               name of the extracted sensorstream, e.g., chess_piece_production."))
	opt.on("")
  opt.on(wrap("[URL|FILE]             source file. Must be a .xes.yaml."))
	opt.on("")
	opt.on("Example: ./#{File.basename($0)} chess_piece_production ./chess_piece_production.xes.yaml")
  opt.parse!
}
if (ARGV.length != 2)
  puts ARGV.options
  exit
end

target = ARGV[0]
path = ARGV[1]
if(path =~ /^http.*/) then
  response = Typhoeus.get(path)
  if(response.success?())
    text = response.response_body
  end
else
  text = File.read(File.join(__dir__,path))
end
yaml = Psych.load_stream(text)

info = yaml.shift()

data = {}
yaml.each() { |item|
  if(!item.dig('event','stream:datastream').nil?()) then
    #puts item
    item.dig('event','stream:datastream').each() { |el|
      if(!el.dig('stream:point','stream:id').nil?()) then
        #puts "#{el.dig('stream:point','stream:id')} - #{el.dig('stream:point','stream:value')}  - #{el.dig('stream:point','stream:timestamp')}"
        id = el.dig('stream:point','stream:id')
        id.gsub!(%r!/!,'_')
        value = el.dig('stream:point','stream:value')
        timestamp = el.dig('stream:point','stream:timestamp')
        t = nil
        begin
          t = Time.strptime(timestamp, '%Y-%m-%dT%H:%M:%S.%N%:z')
        rescue
          t = Time.strptime(timestamp + '+02:00', '%Y-%m-%dT%H:%M:%S.%N%:z')
        end
        if(!data.include?(id)) then
          data[id] = {:points => []}
        end
        data[id][:points].push({:value => value, :timestamp => t.strftime('%Y-%m-%d %H:%M:%S.%L')})
      end
    }
  end
}
#pp data.keys()

data.each() { |_,el|
  # binary wenn length 2? -> nochmal checken ob das nicht zu seltsamen Ergebnissen führt
  if (el[:points].map() {|x| x[:value]}.uniq().length() == 2 || el[:points].map() {|x| x[:value]}.all?() { |x| x.is_a?(TrueClass) || x.is_a?(FalseClass) }) then
    el[:type] = "binary"
  elsif(el[:points].map() {|x| x[:value]}.all?(Integer) || el[:points].map() {|x| x[:value]}.all?(String))
    el[:type] = "discrete"
  else
    el[:type] = "continuous"
  end
  if(el[:points].map() {|x| x[:value]}.all?(Integer)) then
    el[:data] = "integer"
  elsif(el[:points].map() {|x| x[:value]}.all?(Float))
    el[:data] = "float"
  elsif(el[:points].map() {|x| x[:value]}.all?(String))
    el[:data] = "string"
  elsif(el[:points].map() {|x| x[:value]}.all?() { |x| x.is_a?(TrueClass) || x.is_a?(FalseClass) } )
    el[:data] = "boolean"
  else
    el[:data] = "unknown"
  end
}

puts data.map() { |key,el| "#{key}: #{el[:type]}/#{el[:data]}" }

to_write = []
to_write.push('group' => {'id' => 'all', 'timestamp' => 'timestamp'})

to_write.first()['group']['sensors'] = []
minmax = {}
data.map() { |k,v| [k,{'location' => File.join(target,"#{k}.csv"), 'type' => v[:type], 'data' => v[:data], 'data-round' => (2 if v[:data] == 'float')}.compact()] }.to_h().each() { |k,v| to_write.first()['group']['sensors'].push({k => v}) }

main = File.open(File.join(target + '.yaml'), 'w')
main.write(to_write.to_yaml())
main.close()

Dir.mkdir(target) rescue nil
data.each() { |k,v|
  csv = CSV.open(File.join(target,"#{k}.csv"), 'w')
  csv.puts(['id','timestamp',k])
  v[:points].each() { |point|
    csv.puts(['i1',point[:timestamp],point[:value]])
  }
  csv.close()
}
