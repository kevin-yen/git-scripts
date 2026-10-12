# shellcheck shell=bash
# Shared setup: a bare "origin" and a clone of it with one commit on main.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
	TMP="$BATS_TEST_TMPDIR"
	export HOME="$TMP/home"
	export GIT_CONFIG_NOSYSTEM=1
	export ORIG_PATH="$PATH"
	export PATH="$REPO_ROOT/bin:$PATH"
	unset NO_COLOR XDG_BIN_HOME
	mkdir -p "$HOME"
	git config --global user.name Test
	git config --global user.email test@example.com
	git config --global init.defaultBranch main
	git config --global advice.detachedHead false

	git init --quiet --bare "$TMP/origin.git"
	git clone --quiet "$TMP/origin.git" "$TMP/work" 2>/dev/null
	cd "$TMP/work" || return 1
	commit README
	git push --quiet -u origin main
	git remote set-head origin --auto >/dev/null
}

# commit <file> [<content>]: write a file and commit it.
commit() {
	printf '%s\n' "${2:-$1 $RANDOM}" >>"$1"
	git add "$1"
	git commit --quiet -m "change $1"
}

branch_exists() {
	git show-ref --verify --quiet "refs/heads/$1"
}

remote_branch_exists() {
	git ls-remote --exit-code --heads origin "refs/heads/$1" >/dev/null
}

# Wrappers so a negated check fails the test (bats ignores a bare `! cmd`).
branch_missing() {
	! branch_exists "$1"
}

remote_branch_missing() {
	! remote_branch_exists "$1"
}

# upstream_of <branch>: print the branch's upstream, e.g. origin/main.
upstream_of() {
	git rev-parse --abbrev-ref "$1@{upstream}"
}

no_upstream() {
	! git rev-parse --verify --quiet "$1@{upstream}" >/dev/null
}
