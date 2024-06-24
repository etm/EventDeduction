require 'csv'
require 'yaml'
require 'time'
require 'json'

#require 'kmeans-clusterer'

module EvDed
  class Series #{{{
    attr_accessor :classification
    attr_reader :changes, :series

    def initialize
      @series = {}
      @classification = 1
      @changes = []
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
    def get_times()
      #@series.keys()
      @series.map() { |k,v| k }
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
    def set(series, changes = [])
      @series = series
      @changes = changes
    end
    def time_map(times) ### TODO linear axproximation
      times.sort!
      ret = {}
      stimes = @series.keys.sort
      t = stimes.shift
      times.each do |time|
        if time < t
          ret[time] = nil
        elsif time > t
          t = stimes.shift
          t = @series.keys.last if t.nil?
          ret[time] = @series[t]
        else
          ret[time] = @series[t]
        end
      end
      ret
    end
    def change_calc()
      changes = []
      last = nil
      @series.each() { |timestamp,value|
        if(!last.nil?() && last != value)
          changes.push(Time.at(timestamp.to_f.round(1)))
        end
        last = value
      }
      changes
    end
    def each(&block)
      @series.each do |t,v|
        block.call(t,v)
      end
    end
  end #}}}

  def self::load_transform_classify(configpath) #{{{
    configpathbase = File.dirname(configpath)
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

        loc = File.join(configpathbase,details.dig('location') ? details.dig('location') : g.dig('location'))
        tsn = details.dig('timestamp') ? details.dig('timestamp') : g.dig('timestamp')
        CSV.foreach(loc, headers: true) do |row|
          if row[tsn].to_i < 100000 && row[tsn].length() <= 5
            ts = Time.at(row[tsn].to_i)
          else
            ts = Time.parse(row[tsn]) rescue Time.at(row[tsn].to_i)
          end
          value = row[name]
          data[id][name][ts] = case da
            when 'integer'; value.to_i
            when 'float'; value.to_f
            when 'datetime'; Time.parse(value)
            else
              value
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
      data[id].each{|k,sensor| sensor.classification = so.index(sensor.classification) + 1}
    end
    data
  end #}}}

  def self::align_timestamps(groups) #{{{
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
          ret.set(series.time_map(timestamps),series.change_calc())
          [l,ret]
        }.to_h
      ]
    end.to_h
  end #}}}

  def self::write_timestamps(groups,name)
    r = groups.map do |g,sensor|
      sensor.map do |name,s|
        [ name, s.series.map{|k,v| [k.xmlschema(2),v] }.to_h ]
      end
    end
    File.write name + '_data.txt', JSON::pretty_generate(r)
  end

  def self::joint_changes_naive(groups) #{{{
    changes = {}
    stamps = []
    groups.each do |k,sensors|
      sensors.each do |l,series|
        changes[l] = {}
        pval = nil
        first = true
        series.each do |t,val|
          changes[l][t] = if val != pval && !first
            1
          else
            0
          end
          first = false
          pval = val
          stamps << t
        end
        stamps.uniq!
      end
    end
    tseries = {}
    stamps.each do |t|
      tseries[t] ||= []
      changes.each do |l,v|
        if v[t] == 1
          tseries[t] << l
        end
      end
    end
    tseries
  end #}}}

  def self::joint_changes_m(group_id,sensors) #{{{
    puts "  #{group_id}:"
    timestamps = sensors.map() { |sensor,series|
      series.get_times()
    }.flatten().uniq()
    change_list = sensors.map() { |sensor,series|
      [sensor,{:changes => series.changes, :classification => series.classification}]
    }.to_h()

    changes_per_timestamp = {:participating_sensors => change_list.map() { |sensor_name, sensor_info| [sensor_name,1.0/sensor_info[:classification]] }.to_h(), :timestamps => {}}
    timestamps.each() { |ts|
      changes_per_timestamp[:timestamps][ts] = change_list.filter() { |name,characteristics|
        characteristics[:changes].include?(ts)
      }.keys()
    }
    #pp changes_per_timestamp
    puts "    sensors: #{changes_per_timestamp[:participating_sensors]}"
    puts "    changes: \n      #{changes_per_timestamp[:timestamps].sort() {|a,b| a <=> b}.map() { |k,v| "#{k.strftime('%Y-%m-%dT%H:%M:%S.%1N')}:#{v}" }.join("\n      ") }"
    return changes_per_timestamp
  end #}}}

  def self::sensor_importance_naive(groups,tseries) #{{{
    prios_timestamp_per_sensor = {}
    max_prios = {}
    tseries.each do |t,v|
      alpha = v.length

      ### find best matching group
      best_match = nil
      best_match_len = 0
      success = false
      groups.each do |k,sensors|
        if sensors.keys.intersection(v) == v
          prios_timestamp_per_sensor[t] ||= {}
          v.each do |sname|
            prios_timestamp_per_sensor[t][sname] = sensors[sname].classification
          end
          success = true
        else
          ### if not in group remember how good it matched
          if sensors.keys.intersection(v).length > best_match_len
            best_match_len =  sensors.keys.intersection(v).length
            best_match = sensors
          end
        end
        ### also remember all the max sensor priorities (min) for later, i.e., should we find no good match
        sensors.each do |sname,v|
          if max_prios[sname].nil?
            max_prios[sname] = v.classification
          else
            max_prios[sname] = [max_prios[sname],v.classification].min
          end
        end
      end

      ### if wo found no exact group, use the best, and fill all missing sensors with the max sensor prios
      unless success
        v.each do |sname|
          prios_timestamp_per_sensor[t] ||= {}
          prios_timestamp_per_sensor[t][sname] = best_match[sname]&.classification || max_prios[sname]
        end
      end

      ### calculate the prios
      prios_timestamp_per_sensor[t].each do |sname,prio|
        prios_timestamp_per_sensor[t][sname] = alpha  * 1/prio.to_f
      end
    end

    ### sum up all the sensors, and count how often it occurs
    res_sum = {}
    res_num = {}
    prios_timestamp_per_sensor.each do |t,sensors|
      sensors.each do |s,prio|
        res_sum[s] ||= 0
        res_sum[s] += prio
        res_num[s] ||= 0
        res_num[s] += 1
      end
    end

    ### calculate importance
    res_imp = {}
    res_sum.each do |s,prio_sum|
      res_imp[s] = [prio_sum / res_num[s].to_f,[]]
    end

    ### sensors that only changes at first timestamp, and never again are not part of res_imp. Set the all to 0
    groups.each do |k,sensors|
      sensors.each do |sname,_|
        if !res_imp[sname]
          res_imp[sname] = [0,[]]
        end
      end
    end

    ### attach timestamp
    res_imp.each do |s,imp|
      tseries.each do |t,v|
        if v.include? s
          res_imp[s][1] << t
        end
      end
    end

    # sort, and convert to default output format
    res_imp.sort_by{ |k,v| v[0] }.reverse.to_h.map do |s,i|
      {
        "name" => s,
        "ranking" => i[0].round(3),
        "meta" => {
          "description" => s
        },
        "events" => i[1].map { |ts| { 'timestamp' => ts.xmlschema(2), "annotation" => '' } }
      }
    end
  end #}}}

  def self::sensor_importance_print(sis) #{{{
    sis.each do |s,i|
      puts "  #{s['name']}: #{s['ranking']} (#{s['events'].length} events#{s['ranking'] == 0 ? ' -> no events, or only event on first timestamp' : ''})"
    end
  end #}}}

  def self::sensor_importance_write(sis,name) #{{{
    File.write name + '_result.txt', JSON::pretty_generate(sis)
  end #}}}


  def self::sensor_importance_m(changes_per_timestamp) #{{{
    max_importance = changes_per_timestamp[:participating_sensors].sum() { |sensor_name,classification| classification}
    results = []
    changes_per_timestamp[:participating_sensors].each() { |sensor,classification|
      max_importance_sensor = max_importance - changes_per_timestamp[:participating_sensors][sensor]
      x = 0.0
      changes_per_timestamp[:timestamps].each() { |timestamp,participating_sensors|
        #x += participating_sensors.include?(sensor) ? participating_sensors.sum() { |s,_| s == sensor ? 0.0 : changes_per_timestamp[:participating_sensors][s]} : max_importance_sensor - participating_sensors.sum() { |s,_| s == sensor ? 0.0 : changes_per_timestamp[:participating_sensors][s]}
        x += participating_sensors.include?(sensor) ? participating_sensors.sum() { |s,_| changes_per_timestamp[:participating_sensors][s]} : max_importance - participating_sensors.sum() { |s,_| changes_per_timestamp[:participating_sensors][s]}
      }
      #puts "    #{sensor} -> #{x} / #{max_importance_sensor*changes_per_timestamp[:timestamps].length()}"

      #puts "    #{sensor} -> #{x} / #{max_importance*changes_per_timestamp[:timestamps].length()}"
      results.push({:sensor => sensor, :value => x, :max_value => max_importance*changes_per_timestamp[:timestamps].length()})
    }
    results.sort() { |a,b| b[:value] <=> a[:value] }.each() { |result|
      puts "    #{result[:sensor]} -> #{result[:value]} / #{result[:max_value]}"
    }

  end #}}}

  def self::fts(ts) #{{{
    ts.year == 1970 ? ts.to_i : ts
  end #}}}
  def self::ftsa(tss) #{{{
    tss.map { |ts| fts(ts) }
  end #}}}
end
