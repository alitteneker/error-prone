#!/bin/bash

pushd ./core/instrument
perl analyze.pl
popd

rm test-results/*.csv
cp core/instrument/results/*.csv test-results/

echo "Results in directory ./test-results"

