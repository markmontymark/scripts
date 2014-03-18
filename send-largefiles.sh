#!/bin/bash

## run this on the machine with the large file
## Usage: sendlargefile mylargefile.tar.gz user@host-to-scp-the-file.com
function sendlargefile(){
	echo "Sending large file $1"
	echo "Will split in 100mb chunks first..."
	echo "split -b 100m $1"
	#split -b 100m $1
	echo "Chunks created, sending to $2..."
	echo "scp -p x?? $2"
	#scp x?? $2
}

## once file has been split and sent with above command, 
## go to other machine and run this to merge chunks back 
## into one large file again
## Usage: recvlargefile mylargefile.tar.gz
function recvlargefile(){
	echo "cat x?? > $1"
	#cat x?? > $1
}
