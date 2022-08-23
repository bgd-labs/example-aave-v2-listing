#!/bin/bash
# $1 contract downloaded
# $2 modified contract to compare
# $3 name of diff md

MY_DATE=$(date)

# generate diff
git diff --no-index --ignore-space-at-eol $1 $2 > diffs/$3-diff.md
sed -i "1s/^/diff generated with contract downloaded from etherscan at: $MY_DATE\n\n\`\`\`/" diffs/$3-diff.md

# add dates to downloaded contracts
sed -i "1s/^/\/\/ downloaded from etherscan at: $MY_DATE\n/" $1
