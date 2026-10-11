# git-scripts

Small Bash helpers for everyday branch housekeeping. Each `git-<name>` script
on your `PATH` runs as a Git subcommand: `git <name>`.

## Install

```sh
git clone https://github.com/kevin-yen/git-scripts.git
git-scripts/install
```

This symlinks every `bin/git-*` into `${XDG_BIN_HOME:-~/.local/bin}`, so a
`git pull` in the clone updates the installed commands. You can run `install`
from any directory, and running it again is safe.

| Option | Effect |
|---|---|
| `--prefix DIR` | Install somewhere else |
| `--copy` | Copy instead of symlinking (the helper library goes to `DIR/../lib/git-scripts/`) |
| `--force` | Replace existing files that this repo did not install |
| `--uninstall` | Remove only what this repo installed |
| `--dry-run` | Show what would happen |

If the install directory isn't on your `PATH`, the installer prints the line
to add to your shell rc file.

## Commands

Run any command with `-h` for its full usage. (`git <name> --help` opens Git's
man-page lookup instead, so use `-h`, or `git-<name> --help`.)

| Command | What it does |
|---|---|
| `git rebase-branches <base> [<prefix>...]` | Push `<base>`, then rebase the matching local branches onto it |
| `git remove-merged-branches [<base> [<prefix>...]]` | Delete local branches merged into `<base>`; `--squash-aware` also catches squash and rebase merges, and `--push` also deletes them on the remote |

Common options:

- `-n`/`--dry-run`: show the commands without running them
- `-y`/`--yes`: skip the confirmation prompt. Commands that ask for confirmation refuse to run without a terminal unless you pass `--yes`.
- `-r`/`--remote`: use a remote other than `origin`

When you leave out the base branch, the scripts use `origin/HEAD`, falling back
to a local `main` or `master`. If `origin/HEAD` is not set, run
`git remote set-head origin --auto`.

Colors are turned off when output is not a terminal or when `NO_COLOR` is set.

### Built into Git or `gh` instead

- `git config --global fetch.prune true`: prune stale remote-tracking branches on every fetch. This replaces the old `git cleanup`.
- `git branch --merged main`: list merged branches
- `git rebase --update-refs`: rebase a stack of branches in one go
- `gh pr create`: open a pull request. This replaces the old `git pull-request`.

## Requirements

- Bash 3.2 or later (the stock macOS bash works)
- Git 2.23 or later (for `git switch`)
- `readlink -f` (GNU coreutils, or macOS 12.3 or later)

## Development

```sh
shellcheck -x bin/* lib/git-scripts/*.sh install test/*.bash
shfmt -d bin/* lib/git-scripts/*.sh install test/*.bash
bats test/
```

CI runs these on Ubuntu and on macOS with the system bash 3.2.
