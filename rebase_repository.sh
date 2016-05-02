#!/bin/bash

original_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$?" -ne "0" ]
then
	original_branch=""
fi

base_branch="master"
if [ -n "${2}" ]
then
	if git rev-parse --abbrev-ref ${2}
	then
		base_branch="${2}"
	else
		echo "${2} is not a valid branch"
	fi
fi

git push origin ${base_branch}

refs=$(git for-each-ref --format='%(refname:short)' refs/heads/${1}*)

for ref in $refs
do
	printf "\nRebasing ${ref}\n\n"

	if ! git rebase ${base_branch} ${ref}
	then
		printf "Unable to rebase ${ref} ... aborting rebase\n"
		git rebase --abort
	fi
done

if [ -n "${original_branch}" ]
then
	git checkout ${original_branch}
fi