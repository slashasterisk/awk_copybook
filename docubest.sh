#!/bin/bash

function rightnow () {
   now=$(date +"%y%m%d%H%M%S")
}

# Check if a file is provided as an argument
if [ $# -eq 0 ]; then
    echo "Usage: copybook name [email name]  note use redirection to save"
    exit 1
fi

input_file="$1"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file '$input_file' not found. Check path."
    exit 1
fi
# email="${2: }"
email="$2"
email_to="${3:-XX}"

awk_script="docubest.awk"
rightnow
tempfile="tmply$now"

cut -c 1-72 "$input_file" | awk -f "$awk_script" > $tempfile
cat $tempfile

if [ ! -z "$email" ]; then
	msg="copybook "$1
	echo $msg
	echo "mailx -s "$msg" -a $PWD/$tempfile --" $email_to
fi
rm $tempfile