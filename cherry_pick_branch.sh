#!/bin/bash

refs=$(git for-each-ref --format='%(refname:short)' refs/heads)

for ref in $refs
do
	echo "Attempting to rebase $ref to master"

	if [[ $ref == master* ]]
	then
		git rebase master $ref
		git rebase --abort
	fi
done