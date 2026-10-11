# shellcheck shell=bash
# Shared helpers for git-scripts. This file is sourced, not executed.
# Must stay compatible with bash 3.2 (macOS): no mapfile, no ${var,,}, no assoc arrays.

# shellcheck disable=SC2034 # the colors are used by the scripts that source this file
# Colors only when stdout is a terminal and NO_COLOR is unset (https://no-color.org).
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
	red=$'\033[31m'
	green=$'\033[32m'
	yellow=$'\033[33m'
	nc=$'\033[0m'
else
	red=''
	green=''
	yellow=''
	nc=''
fi

ASSUME_YES=${ASSUME_YES:-0}
DRY_RUN=${DRY_RUN:-0}

info() {
	printf '%s\n' "$*"
}

warn() {
	printf '%s\n' "${yellow}warning:${nc} $*" >&2
}

die() {
	printf '%s\n' "${red}error:${nc} $*" >&2
	exit 1
}

# Print the usage block: the leading comment of the calling script, minus the shebang.
usage() {
	awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

# Run a command, or only print it when --dry-run is active.
run() {
	if [[ $DRY_RUN == 1 ]]; then
		printf '+'
		printf ' %q' "$@"
		printf '\n'
	else
		"$@"
	fi
}

# Ask for confirmation; --yes (ASSUME_YES=1) skips the prompt.
confirm() {
	local reply
	[[ $ASSUME_YES == 1 ]] && return 0
	[[ -t 0 ]] || die "no terminal to confirm on; pass --yes to continue non-interactively"
	read -r -p "${1:-Are you sure?} [y/N] " reply
	[[ $reply =~ ^[Yy]([Ee][Ss])?$ ]] || die "aborted"
}

require_repo() {
	git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"
}

# True when $1 equals one of the remaining arguments. Prefer this over
# `printf ... | grep -q`, which can fail with SIGPIPE under pipefail.
contains() {
	local needle=$1 e
	shift
	for e in "$@"; do
		[[ $e == "$needle" ]] && return 0
	done
	return 1
}

is_branch() {
	git show-ref --verify --quiet "refs/heads/$1"
}

has_remote() {
	git remote get-url "$1" >/dev/null 2>&1
}

# Print the default branch: <remote>/HEAD if set, otherwise local main or master.
default_branch() {
	local remote=${1:-origin} ref b
	if ref=$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null); then
		printf '%s\n' "${ref#"$remote"/}"
		return 0
	fi
	for b in main master; do
		if is_branch "$b"; then
			printf '%s\n' "$b"
			return 0
		fi
	done
	die "cannot determine the default branch; pass it explicitly or run: git remote set-head $remote --auto"
}

# Print local branches whose names start with any of the given prefixes
# (all local branches when none are given), one per line, sorted and de-duplicated.
list_branches() {
	local ref p
	(($# > 0)) || set -- ''
	# Match prefixes here: for-each-ref globs stop at '/', so refs/heads/* would skip feat/x.
	git for-each-ref --format='%(refname:short)' refs/heads/ | while IFS= read -r ref; do
		for p in "$@"; do
			if [[ $ref == "$p"* ]]; then
				printf '%s\n' "$ref"
				break
			fi
		done
	done | sort -u
}

# Print the path of the worktree that has branch $1 checked out (nothing if none).
branch_worktree() {
	# No early exit in awk: closing the pipe early could SIGPIPE git under pipefail.
	git worktree list --porcelain | awk -v ref="refs/heads/$1" '
		/^worktree / { path = substr($0, 10) }
		$0 == "branch " ref && !found { print path; found = 1 }'
}

current_branch() {
	git symbolic-ref --quiet --short HEAD || true
}

# Remember the checked-out branch (or detached commit) and switch back to it on exit.
save_branch() {
	_saved_branch=$(current_branch)
	_saved_commit=$(git rev-parse --verify --quiet HEAD || true)
	trap restore_branch EXIT
}

restore_branch() {
	local git_dir
	git_dir=$(git rev-parse --git-dir)
	if [[ -d $git_dir/rebase-merge || -d $git_dir/rebase-apply ]]; then
		warn "a rebase is still in progress; not switching back"
		return
	fi
	if [[ -n ${_saved_branch:-} ]]; then
		[[ $(current_branch) == "$_saved_branch" ]] ||
			git switch --quiet "$_saved_branch" || warn "could not switch back to $_saved_branch"
	elif [[ -n ${_saved_commit:-} ]]; then
		git switch --quiet --detach "$_saved_commit" || warn "could not switch back to $_saved_commit"
	fi
}
