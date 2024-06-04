#!/usr/bin/ruby
require_relative 'lib/load'

require 'psych'
require 'typhoeus'

path = ARGV[0]
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
        if(!data.include?(id)) then
          data[id] = {:points => []}
        end
        data[id][:points].push({:value => value, :timestamp => timestamp})
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
data.map() { |k,v| [k,{'location' => File.join('data','chess_piece_production',"#{k}.csv"), 'type' => v[:type], 'data' => v[:data]}] }.to_h().each() { |k,v| to_write.first()['group']['sensors'].push({k => v}) }

main = File.open(File.join('data','chess_piece_production.yaml'), 'w')
main.write(to_write.to_yaml())
main.close()

data.each() { |k,v|
  csv = CSV.open(File.join('data','chess_piece_production',"#{k}.csv"), 'w')
  csv.puts(['id','timestamp',k])
  v[:points].each() { |point|
    csv.puts(['i1',point[:timestamp],point[:value]])
  }
  csv.close()
}
