#!/bin/bash

git diff --no-index --diff-algorithm=patience --ignore-space-at-eol $1 $2 > diffs/$3.md 
sed -i '1s/^/```/' diffs/$3.md