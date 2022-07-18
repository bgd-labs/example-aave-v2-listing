#!/bin/bash

# sed is behaving differently on osx
# git diff --no-index --diff-algorithm=patience --ignore-space-at-eol $1 $2 > diffs/$3.md 
# sed -i '1s/^/```/' diffs/$3.md
# printf is part of POSIX
printf '%s\n%s\n%s\n' "\`\`\`diff" "$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol $1 $2)" "\`\`\`" > diffs/$3.md
