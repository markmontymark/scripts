#!/bin/sh

#
# can't remember url where i copied this from...i did not originally write this
#
for i in {0..255} ; do
	printf "\x1b[38;5;${i}mcolour${i}\n"
done
