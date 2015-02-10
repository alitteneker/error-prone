#!/bin/bash

FILES=$( find ../core/src/main/java -name *.java )

for f in $FILES;
do

filename=$( basename $f )
echo $filename

# Special cases that cause javaparser to throw parse exceptions
cat $f | sed 's/<>//' | sed 's/| IllegalAccessException e) {/e) {/' > $filename.tmp

java -cp loc/target/loc-1.0-SNAPSHOT.jar:loc/lib/javaparser-1.0.8.jar methodlevel.MethodPrinter $filename.tmp >> loc-metrics.csv.tmp

rm $filename.tmp

done

cat loc-metrics.csv.tmp | sed 's/.tmp:/:/' > loc-metrics.csv
rm loc-metrics.csv.tmp

echo -e "\nDone. CSV format (loc-metrics.csv): Filename:MethodName(),LOC"
