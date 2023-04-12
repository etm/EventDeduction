require 'csv'
require 'yaml'
require 'time'

module EvDed
  class Series
    def initialize
      @series = {}
    end
    def [](time)
      @series[time]
    end
    def length
      @series.length
    end
    def []=(time,value)
      @series[time] = value
    end
    def find(time)
      time = Time.parse(time) if time.is_a?(String)
      ft = Time.at(0)
      @series.keys.each do |t|
        if (t - time).abs < (ft - time).abs || ft == -1
          ft = t
        end
      end
      { ft => @series[ft] }
    end
  end

  def self::load_and_transform(configpath)
    data = {}
    groups = YAML.load_file(configpath)
    groups.each do |g|
      g = g['group']
      id = g.dig('id')
      data[id] ||= {}
      CSV.foreach(g.dig('location'), headers: true) do |row|
        ts = Time.parse(row[g.dig('timestamp')])
        g.dig('sensors').each do |s|
          name = s.keys.first
          details = s[name]
          value = row[name]
          ty = details.dig('type').nil? ? 'discrete' : details.dig('type')
          da = if details.dig('data').nil?
            case ty
              when 'continuous'; 'float'
              when 'discrete'; 'string'
              when 'binary'; 'string'
            end
          else
            details.dig('data')
          end

          data[id][name] ||= Series.new
          data[id][name][ts] = case da
            when 'integer'; value.to_i
            when 'float'; value.to_f
            when 'string'; value
            when 'datetime'; Time.parse(value)
          end
          res = []
          if details.dig('partition')
            details.dig('partition').each do |k,v|
              ev = case da
                when 'integer', 'float'; eval(k.to_s)
                when 'string', 'datetime'; k
              end
              res << if ev.respond_to?(:include?)
                ev.include?(data[id][name][ts]) ? v : nil
              else
                k == data[id][name][ts] ? v : nil
              end
            end
            res = res.compact.uniq
            data[id][name][ts] = if res.length > 0
              res.first
            else
              details.dig('else')
            end
          end
        end
      end
    end
    data
  end
end
