#!/usr/bin/ruby
require_relative 'lib/load'

groups = EvDed::load_transform_classify(File.join(__dir__,'test.yaml'))

puts "Groups, sensors, number of data points and classification:"
groups.each do |k,sensors|
  puts "  #{k}"
  sensors.each do |k,series|
    puts "    #{k}: #{series.length} (#{series.classification})"
  end
end

puts "\nStep 4: ..."
### Sensor Dependency Deduction
# Sensorenpaare bilden (jeder mit jedem)
# zusammenhaenge pattern bilden
# hoch hoch, runter runter, hoch runter
# einmal gleich verhalten
# immer gleich verhalten
# pair wise dependent vs. all in group same behavior
### Expected results
# hb_i1, vgr_o7, vgr_st, hb_i4, hbw_m1
# hb_i4, vgr_o7, vgr_st, hb_i1, hbw_m1
# hb_m1, vgr_o7, hbw_i1, hb_i4
# vgr_o7, hbw_i1, hbw_i4, oven_i5, vgr_st
# vgr_st, hbw_i1, hbw_i4, oven_i5, vgr_o7
# oven_i5, vgr_o7, vgr_st
# qc_i6, vgr_o7, vgr_st

groups = EvDed::align_timestamps(groups)

groups = EvDed::sax(groups)

puts "Groups, sensors, number of data points and classification:"
groups.each do |k,sensors|
  puts "  #{k}"
  sensors.each do |k,series|
    puts "    #{k}: #{series.length} (#{series.classification})"
  end
end

puts "\nStep 5: ..."
###
# groesste Gruppe, mit der hoechsten class innerhalb

stime = '2022-07-19 10:02:57.22 +0200'
print "\nSearching for '#{stime}' in vgr/current_state: "
puts groups['vgr']['current_state'].find(stime)

# pp data
