#!/bin/bash

# Simple thing to watch your project and run tests on change
# Takes one optional argument, which will grep tests and run the ones that match

while inotifywait -r -e modify ./test ./lib ./config; do
  mix test
done