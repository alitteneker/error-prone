import sys
import commands

methods = dict()

methodCounts = dict()

methodCountsForSize = dict()

lastClass = ""

#---------------

totalNumberOfLines = commands.getoutput("./lines_of_codes.sh")

output = totalNumberOfLines.split("\n")

for line in output:
	if "Size information" in line:
		classFile = line.split(" ")[-1]
		lastClass = classFile.split(".")[0]
	if "Method:" in line:
		numLines = line.split(" ")
		methodName = numLines[-2]
		numberOfLines = int(numLines[-1][1:-1])
		
		key = lastClass + "." + methodName
		
		if key in methods:
			methods[key]['numberOfLines'] = methods[key]['numberOfLines'] + numberOfLines
			
			if key in methodCountsForSize:
				methodCountsForSize[key] = methodCountsForSize[key] + 1
			else:
				methodCountsForSize[key] = 1
		else:
			methods[key] = dict()
			methods[key]['numberOfLines'] = numberOfLines
			methodCountsForSize[key] = 1

#---------------

for key in methodCountsForSize:	
	methods[key]['numberOfLines'] = methods[key]['numberOfLines'] / methodCountsForSize[key]
	
for key in methods:
	print key + " " + str(methods[key]['numberOfLines'])
	
#---------------

metrics_csv = open("metrics.csv", 'w')

metrics_csv.write("Method_Name,Total_Number_Of_Lines\n")

for key in methods:
	metrics_csv.write(str(key) + "," + str(methods[key]['numberOfLines']) + "\n")

metrics_csv.close()