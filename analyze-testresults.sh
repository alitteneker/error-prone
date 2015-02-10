#!/bin/bash

pushd ./core/instrument
perl analyze.pl
popd

rm test-results/*
cp core/instrument/results/* test-results/

echo "Results in directory ./test-results"

