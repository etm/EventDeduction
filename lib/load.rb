require 'csv'
require 'yaml'
require 'time'
require 'json'

module EvDed
  class Series
    attr_accessor :classification

    def initialize
      @series = {}
      @classification = 1
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
    def set(series)
      @series = series
    end
    def time_map(times) ### TODO linear axproximation
      ret = {}
      t = Time.at(0)
      stimes = @series.keys
      times.each do |time|
        while !t.nil? && time > t
          t = stimes.shift
        end
        ret[time] = @series[t || @series.keys.last]
      end
      ret
    end
    def each(&block)
      @series.each do |t,v|
        block.call(t,v)
      end
    end
  end

  def self::align_timestamps(groups)
    timestamps = []
    groups.each do |k,sensors|
      sensors.each do |l,series|
        series.each do |t,val|
          timestamps << Time.at(t.to_f.round(1))
        end
      end
    end

    timestamps.uniq!
    groups.map do |k,sensors|
      [
        k, sensors.map{ |l,series|
          ret = EvDed::Series.new
          ret.classification = series.classification
          ret.set series.time_map(timestamps)
          [l,ret]
        }.to_h
      ]
    end.to_h
  end

  def self::sax(groups)
    values = []
    groups.each do |k,sensors|
      sensors.each do |l,series|
        series.each do |t,val|
          values << val
        end
      end
    end

    p values.uniq.length
    exit

    timestamps.uniq!
    groups.map do |k,sensors|
      [
        k, sensors.map{ |l,series|
          ret = EvDed::Series.new
          ret.classification = series.classification
          ret.set series.time_map(timestamps)
          [l,ret]
        }.to_h
      ]
    end.to_h
  end

  def self::load_transform_classify(configpath)
    data = {}
    groups = YAML.load_file(configpath)
    groups.each do |g|
      g = g['group']
      id = g.dig('id')
      data[id] ||= {}
      g.dig('sensors').each do |s|
        name = s.keys.first
        details = s[name]
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

        case ty
          when 'continuous'; data[id][name].classification = 20000
          when 'discrete'; data[id][name].classification = 10000
          when 'binary'; data[id][name].classification = 0
        end
        part = details.dig('partition')
        if part
          data[id][name].classification += part.keys.uniq.length - part.values.uniq.length
          data[id][name].classification += case da
            when 'integer'; part.keys.map{|e| e.is_a?(Integer) ? 0 : 1}
            when 'float'; part.keys.map{|e|e.is_a?(Float) ? 0 : 1}
            else; []
          end.sum
        else
          data[id][name].classification += (data[id][name].classification - 1)
        end

        CSV.foreach(g.dig('location'), headers: true) do |row|
          ts = Time.parse(row[g.dig('timestamp')])
          value = row[name]
          data[id][name][ts] = case da
            when 'integer'; value.to_i
            when 'float'; value.to_f
            when 'string'; value
            when 'datetime'; Time.parse(value)
          end

          if part = details.dig('partition')
            res = []
            part.each do |k,v|
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
      so = data[id].map{|k,sensor|sensor.classification}.sort
      data[id].each{|k,sensor| sensor.classification = so.index(sensor.classification)}
    end
    data
  end
end
