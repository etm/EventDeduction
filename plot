#!/usr/bin/ruby
require 'gr/plot'

x = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
y = [0.3, 0.5, 0.4, 0.2, 0.6, 0.7]

# show the figure
GR.plot(x, y)
gets

# GR.savefig("figure.png")
