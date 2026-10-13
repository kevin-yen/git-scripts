#!/usr/bin/env bats

load test_helper

@test "every command prints usage for --help" {
	for cmd in "$REPO_ROOT"/bin/git-*; do
		run "$cmd" --help
		[ "$status" -eq 0 ]
		[[ $output == Usage:* ]]
	done
}

@test "remove-merged-branches deletes only merged branches" {
	git branch merged
	git switch --quiet -c unmerged
	commit unmerged-file
	git switch --quiet main

	run git remove-merged-branches --yes main
	[ "$status" -eq 0 ]
	branch_missing merged
	branch_exists unmerged
	branch_exists main
}

@test "remove-merged-branches --dry-run deletes nothing" {
	git branch merged
	run git remove-merged-branches --dry-run main
	[ "$status" -eq 0 ]
	[[ $output == *merged* ]]
	branch_exists merged
}

@test "remove-merged-branches defaults to the default branch and honours prefixes" {
	git branch feature/a
	git branch other
	run git remove-merged-branches --yes main feature/
	[ "$status" -eq 0 ]
	branch_missing feature/a
	branch_exists other

	run git remove-merged-branches --yes
	[ "$status" -eq 0 ]
	branch_missing other
}

@test "remove-merged-branches without a prefix includes nested branches" {
	git branch feature/a
	git branch feature/deep/b
	run git remove-merged-branches --yes main
	[ "$status" -eq 0 ]
	branch_missing feature/a
	branch_missing feature/deep/b
}

@test "remove-merged-branches --squash-aware detects squash merges" {
	git switch --quiet -c squashed
	commit a
	commit b
	git switch --quiet main
	git merge --quiet --squash squashed
	git commit --quiet -m squash

	git remove-merged-branches --yes main
	branch_exists squashed

	git remove-merged-branches --yes --squash-aware main
	branch_missing squashed
}

@test "remove-merged-branches removes the worktree a merged branch is checked out in" {
	git worktree add --quiet "$TMP/wt-clean" -b clean
	git worktree add --quiet "$TMP/wt-dirty" -b dirty
	echo change >"$TMP/wt-dirty/README"

	run git remove-merged-branches --dry-run main
	[ "$status" -eq 0 ]
	[[ $output == *"clean  (worktree $TMP/wt-clean will be removed)"* ]]
	[ -d "$TMP/wt-clean" ]

	run git remove-merged-branches --yes main
	[ "$status" -ne 0 ]
	[ ! -e "$TMP/wt-clean" ]
	branch_missing clean
	[ -d "$TMP/wt-dirty" ]
	branch_exists dirty
}

@test "remove-merged-branches keeps the branch of the main worktree" {
	git branch merged
	git switch --quiet -c in-main
	git worktree add --quiet "$TMP/linked" -b linked
	cd "$TMP/linked"
	run git remove-merged-branches --yes main
	[ "$status" -eq 0 ]
	branch_missing merged
	branch_exists in-main
	branch_exists linked
}

@test "remove-merged-branches --push also deletes the remote branch" {
	git branch merged
	git push --quiet origin merged
	git remove-merged-branches --yes main
	remote_branch_exists merged

	git branch merged origin/merged
	git remove-merged-branches --yes --push main
	remote_branch_missing merged
}


@test "remove-merged-branches shows the merged pull request when gh is available" {
	git branch with-pr
	git branch without-pr
	mkdir -p "$TMP/stub"
	cat >"$TMP/stub/gh" <<-'EOF'
		#!/bin/sh
		printf 'with-pr\thttps://github.com/o/r/pull/42\nwith-pr\thttps://github.com/o/r/pull/7\n'
	EOF
	chmod +x "$TMP/stub/gh"

	PATH="$TMP/stub:$PATH" run git remove-merged-branches --dry-run main
	[ "$status" -eq 0 ]
	[[ $output == *"with-pr  https://github.com/o/r/pull/42"* ]]
	[[ $output != *"pull/7"* ]]
	[[ $output == *"  without-pr"* ]]
}

@test "remove-merged-branches ignores a failing gh" {
	git branch merged
	mkdir -p "$TMP/stub"
	printf '#!/bin/sh\necho "not logged in" >&2\nexit 1\n' >"$TMP/stub/gh"
	chmod +x "$TMP/stub/gh"

	PATH="$TMP/stub:$PATH" run git remove-merged-branches --yes main
	[ "$status" -eq 0 ]
	[[ $output != *"not logged in"* ]]
	branch_missing merged
}

@test "confirmation refuses to proceed without a terminal" {
	git branch merged
	run git remove-merged-branches main </dev/null
	[ "$status" -ne 0 ]
	[[ $output == *--yes* ]]
	branch_exists merged
}

@test "colors are suppressed when output is piped" {
	git branch feature
	run git rebase-branches --dry-run main
	[ "$status" -eq 0 ]
	[[ $output == *feature* ]]
	[[ $output != *$'\033'* ]]
}

@test "rebase-branches does not push without --push" {
	git switch --quiet -c feature
	commit feature
	git push --quiet origin feature
	git switch --quiet main
	commit base
	git rebase-branches --yes main feature
	git merge-base --is-ancestor main feature
	[ "$(git rev-parse origin/main)" != "$(git rev-parse main)" ]
	[ "$(git ls-remote origin refs/heads/feature | cut -f1)" != "$(git rev-parse feature)" ]
}

@test "rebase-branches --push force-pushes only the rebased remote branches" {
	git switch --quiet -c feature
	commit feature
	git push --quiet origin feature
	git switch --quiet -c local-only main
	commit local
	git switch --quiet main
	commit base
	old_main=$(git rev-parse origin/main)
	git rebase-branches --yes --push main
	[ "$(git ls-remote origin refs/heads/main | cut -f1)" = "$old_main" ]
	[ "$(git ls-remote origin refs/heads/feature | cut -f1)" = "$(git rev-parse feature)" ]
	git merge-base --is-ancestor main feature
	remote_branch_missing local-only
}

@test "rebase-branches --push does not overwrite commits pushed from elsewhere" {
	git switch --quiet -c feature
	commit feature
	git push --quiet origin feature
	git switch --quiet main
	git clone --quiet "$TMP/origin.git" "$TMP/other" 2>/dev/null
	git -C "$TMP/other" switch --quiet feature
	(cd "$TMP/other" && commit elsewhere && git push --quiet origin feature)
	commit base
	run git rebase-branches --yes --push main
	[ "$status" -ne 0 ]
	[[ $output == *"not pushed"* ]]
	[ "$(git ls-remote origin refs/heads/feature | cut -f1)" = "$(git -C "$TMP/other" rev-parse feature)" ]
}

@test "setup-tracking-branches tracks only untracked branches with a remote match" {
	git branch pushed
	git push --quiet origin pushed
	git branch local-only
	git branch other-name
	git push --quiet origin other-name:different
	git branch already
	git push --quiet origin already:elsewhere
	git branch --quiet --set-upstream-to=origin/elsewhere already
	git push --quiet origin main:already

	run git setup-tracking-branches
	[ "$status" -eq 0 ]
	[ "$(upstream_of pushed)" = origin/pushed ]
	[ "$(upstream_of already)" = origin/elsewhere ]
	no_upstream local-only
	no_upstream other-name
}

@test "setup-tracking-branches --dry-run changes nothing and honours prefixes" {
	git branch feature/a
	git branch other
	git push --quiet origin feature/a other
	git branch --quiet --unset-upstream main

	run git setup-tracking-branches --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"--set-upstream-to=origin/feature/a"* ]]
	no_upstream feature/a

	run git setup-tracking-branches feature/
	[ "$status" -eq 0 ]
	[ "$(upstream_of feature/a)" = origin/feature/a ]
	no_upstream other
	no_upstream main
}

@test "setup-tracking-branches --fetch sees branches pushed from elsewhere" {
	git clone --quiet "$TMP/origin.git" "$TMP/other" 2>/dev/null
	git -C "$TMP/other" push --quiet origin main:remote-only
	git branch remote-only

	run git setup-tracking-branches
	[ "$status" -eq 0 ]
	no_upstream remote-only

	run git setup-tracking-branches --fetch
	[ "$status" -eq 0 ]
	[ "$(upstream_of remote-only)" = origin/remote-only ]
}
