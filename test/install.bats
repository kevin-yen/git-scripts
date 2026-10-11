#!/usr/bin/env bats

load test_helper

@test "install symlinks every command from any directory" {
	cd "$TMP"
	run "$REPO_ROOT/install" --prefix "$TMP/prefix"
	[ "$status" -eq 0 ]
	for src in "$REPO_ROOT"/bin/git-*; do
		dest="$TMP/prefix/$(basename "$src")"
		[ -L "$dest" ]
		[ "$(readlink "$dest")" = "$src" ]
	done
	[[ $output == *"is not on your PATH"* ]]
}

@test "installed commands run as git subcommands through PATH" {
	"$REPO_ROOT/install" --prefix "$TMP/prefix" >/dev/null
	PATH="$TMP/prefix:$ORIG_PATH" run git rebase-branches -h
	[ "$status" -eq 0 ]
	[[ $output == *"Usage: git rebase-branches"* ]]
}

@test "install is idempotent" {
	"$REPO_ROOT/install" --prefix "$TMP/prefix" >/dev/null
	run "$REPO_ROOT/install" --prefix "$TMP/prefix"
	[ "$status" -eq 0 ]
	[[ $output != *skipping* ]]
}

@test "install leaves foreign files alone unless --force" {
	mkdir -p "$TMP/prefix"
	echo mine >"$TMP/prefix/git-rebase-branches"
	run "$REPO_ROOT/install" --prefix "$TMP/prefix"
	[[ $output == *"skipping $TMP/prefix/git-rebase-branches"* ]]
	[ "$(cat "$TMP/prefix/git-rebase-branches")" = mine ]

	"$REPO_ROOT/install" --prefix "$TMP/prefix" --force >/dev/null 2>&1
	[ -L "$TMP/prefix/git-rebase-branches" ]
}

@test "uninstall removes only links into this repo" {
	"$REPO_ROOT/install" --prefix "$TMP/prefix" >/dev/null
	echo other >"$TMP/prefix/git-other"
	run "$REPO_ROOT/install" --uninstall --prefix "$TMP/prefix"
	[ "$status" -eq 0 ]
	[ "$(ls "$TMP/prefix")" = git-other ]
}

@test "--copy installs runnable copies with the library and uninstalls them" {
	"$REPO_ROOT/install" --copy --prefix "$TMP/local/bin" >/dev/null
	[ -f "$TMP/local/bin/git-rebase-branches" ] && [ ! -L "$TMP/local/bin/git-rebase-branches" ]
	[ -f "$TMP/local/lib/git-scripts/common.sh" ]
	git branch merged
	run "$TMP/local/bin/git-remove-merged-branches" --dry-run main
	[ "$status" -eq 0 ]
	[[ $output == *merged* ]]

	"$REPO_ROOT/install" --copy --uninstall --prefix "$TMP/local/bin" >/dev/null
	[ -z "$(ls "$TMP/local/bin")" ]
	[ ! -e "$TMP/local/lib/git-scripts" ]
}

@test "--dry-run changes nothing" {
	run "$REPO_ROOT/install" --dry-run --prefix "$TMP/prefix"
	[ "$status" -eq 0 ]
	[ ! -e "$TMP/prefix" ]
}
