#!/bin/bash
a=$(mktemp)
cat $1 | perl -pi -e 's/[\t ]/,/g;' > $a
ssconvert $a $1.xls
rm $a
