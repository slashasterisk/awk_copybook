#!/bin/awk -f

# docubest.awk  -- field column positions based on cobol cobybook
# 2023.12.14
# Delamater

#	if len of input > 72, then cut -c7-72 copybookwork.txt | head (bash script idea)
# 	clean up copybook so that values do not exist on a single line like 10 THRU 15 etc
# 	This will ALWAYS assume that the first field after col7 is the level
# 	ASSUMPTIONS: 
# 		COLS 1-6 is populated and will be known as $1 - if no line numbers, FILL IT MANUALLY
# 		$2 will be levels only, 01, 02 - 65
# 		$3 will be group name (not always field name)
# 		PIC/PICTURE & definition will immeditately following,, ie PIC X(10).
#   		 PIC can occur in fields $2 - $7
# 		Ignore VALUE, INDEXED BY, SYNC, DEPENDING, ON, IS, TIMES

function doPIC() {
	$0 = input
	for( i=1; i<=NF; i++ ) {
		if (($i == "PIC") || ($i == "PICTURE")) {
			definition = i + 1
			elemLength = getFieldLength(definition)
			doPrint()
			startPos = startPos + elemLength
			break
		}
	}
}
function doPrint() {
	if (!occursFlag) 
		printf("%04d %04d   %-s\n", startPos, elemLength, input)
	else 
		printf("%04d %04d   %-s %02d\n", startPos, elemLength, input, occursFlag)
}

function getFieldLength(definition) {

	gsub(/S|V|\.$/, "", $definition)
	fieldLen=count=maxCount=0
	
	if (!match($definition, /\(/)) {
		fieldLen = length($definition)
	} else {
		parensValue()
		if ($definition > "") {
			ninesValues()
			fieldLen = fieldLen + maxCount
		}
	}
	return compFields(fieldLen)
}
function parensValue(   number) {
	while (match($definition, /\(([0-9]+)\)/, arr)) {          # sums numbers inside parens
		number = arr[1]
		fieldLen += number
		$definition = substr($definition, RSTART + RLENGTH)    # consume the field as it iterates
	}
}
function ninesValues(   j) {
	for ( j=1; j<=length($definition); j++ ) {                 # get count of consecutive 9's (leftover of consume)
		if (substr($definition, j, 1) == "9") {
			count++
			if (count > maxCount) {
				maxCount=count
			}
		} else {
			count = 0
		}
	}
}
function compFields(fieldLen,    finalLength) {
	finalLength = fieldLen
	if ((comp3) || (grp_comp3)) {
		finalLength =  int(finalLength / 2 + 1)
	}	
	if ((comp) || (grp_comp)) {
		if (finalLength <= 4) {
			finalLength =  2
		} 
		if (finalLength <= 8) {
			finalLength =  4
		} else  {
			finalLength =  8
		}
	}	
	return finalLength
}
function setOccursGroup(    i) {
	occursLevel = $2
	if ( occursGrp ) {
		for ( i = 1; i <= NF; i++ ) {   # this finds the field # that the occurs is in, and sets the times
			if ($i == "OCCURS") {
				occTimes = $(i+1)
				printf("%4s %4s   %-s\n", "OCCR", "GRP*", input)
				next
			}
		}
	} 
}
function resetOccursGroup(    i,elem) {
	i = 1
	while (i < occTimes) {
		i++
		for (elem in occurs_table) {
			input = occurs_table[elem]
			occursFlag = i 
			doPIC()
		}
	}
	delarray(occurs_table)
	occursFlag=occursLevel=0
}
function delarray(a,    i) {
	for (i in a)
		delete a[i]
}

# THIS IS THE START OF THE PROGRAM  (BEGIN executes only once)

BEGIN {
	grpLevel = hgLevel = 99
	redeFlag = 0
	startPos=1
	elemLength=0
	occursLevel = 0
	printf("%4s %4s   %-s\n", "POS ", "LEN ", "|<-- ORIGINAL ELEMENT ------>...|")
}

# BODY starts here with general housekeeping for each record (next will read the next record)
	substr($1,7,1) == "*" {next}
	$2 == "88" || $2 == "77" || $2 == "66" {next}                  #77 & 66 should never be part of copybook but...
	$2 == "VALUE" || $2 == "THRU" || $2 == "THROUGH" {next}
	$3 == "THRU" || $3 == "THROUGH" {next}
	$2 == "REFEFINES" || $3 == "REDEFINES" || $4 == "REDEFINES" {redeFlag = 1}
	$3 == "OCCURS" || $4 == "OCCURS" {occursFlag = 1}
{
	input = hold_input = $0
	
	picFlag = match($0, / PIC | PICTURE /)
	grpFlag = match($2, /[0-9][0-9]/)
	redefines = match($0, / REDEF | REDEFINES /)
	occursGrp = match($0, / OCCURS /)
	comp3 = match($0, / COMP-3\.| COMP-3 /)
	comp = match($0, / COMP\.| COMP /)

# set elementary data fields 
	eLevel=oeLevel=$2

#set first group level, a field of just 2 digits (special case when testing)
	if ((match($2,/[0-9][0-9]/)) && (grpLevel=="")) {			
		grpLevel = hgName = $2
		grpName = $3
		print "group level once"
	}
	
# occurs processing
	if ( occursFlag ) {
		if (occursLevel == 0) {
			setOccursGroup()
		} else if (oeLevel > occursLevel) {
			if (picFlag) {
				occurs_table[NR] = $0          #store input in table to unload when next group encountered
			}
		  } else {
				resetOccursGroup()
				$0=input=hold_input
		}
	}

# skip calcuations for redefines fields, just print it and get out (did not come across this when adding occurs)
	if ( ((redeFlag) && (eLevel > grpLevel)) || ((redefines) && (eLevel == grpLevel))) {
 	    printf("%4s %4s   %-s\n", "REDF", "****", input)
		next
	}

# reset the redefines flag when current line is not redefined, leaves it set if $2 is not a level value
	if ((eLevel <= grpLevel) && (!redefines)) {
		redeFlag=0
		grpLevel=eLevel
	}

# which field is pic (next one is definition) and get the field length, CHECK COPYBOOK IF FUNKY OUTPUT
	definition = elemLength = 0
    if (picFlag) {
	    doPIC()
	}

# When the USAGE is found at the group level, we need to save the USAGE until next group
	if ((!picFlag) && ($4 != "") && ((comp3) || (comp))) {
		printf("%04d %4s   %-s\n", startPos, "GRP$", input)
		grp_comp3 = comp3
		grp_comp = comp
	}

# once elevel is == grpLevel, reset 
	if ($4 == "") {         			# only two fields, the level and the level name (group) on a line
		printf("%04d %4s   %-s\n", startPos, "GRP*", input)
		if ((eLevel == grpLevel) && (occursFlag)) {
			occursLevel=occursFlag = 0
		}
		grpLevel = $2
		grp_comp3=grp_comp = 0
		if ($2 <= hgLevel) {
			grpLevel=hgLevel = $2
		}
	} 
	
}

END {
	if (occursFlag) {
		resetOccursGroup()
	}
	print "COPYBOOK:" FILENAME
}
