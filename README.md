### Classification:
### prioritizing of sensors inside groups
### Rules
# binary > discrete > continuous
# more sem anno than less (current_pos_x is the worst)
# binary with 2 partitions or no partitions is best
# binary with more than 2 partitions is worse
# discrete with no ranges in partitions with better than discrete with ranges
# discrete with same dimensions is better than discrete with dimension reduction
### Expected results
# hb
#   i1_light_barrier_interrupted: 2
#   i4_light_barrier_interrupted: 2
#   m3_speed: 3
#   m1_speed: 3
#   current_state: 1
# qc
#   i6_light_barrier_interrupted: 1
# vgr
#   o7_compressor_power_level: 2
#   o8_valve_open: 2
#   current_state: 1
#   current_pos_x: 3
#   current_pos_y: 3
#   current_pos_z: 3
# oven
#   i5_light_barrier_interrupted: 2
#   current_state: 1

Step 5:
* Create superset of timestamps
* Fill missing values for each sensor with linearly interpolated values
* Symbolic Aggregate approXimation (SAX) for both pairs
* If not same dimension (num of discrete values) reduce number of dimensions by kmeans(dimension) of the y axis for the series with the higher dimension
* check for same patterns at same position

Compression Based Similarity/Dissimilarity?!

Alternatives? Mape? Pearson correlation coefficient? Dtw?

Multivariant Timeseries Clustering:
