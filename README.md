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
| `-p`/`--prefix DIR` | Install somewhere else |
| `-c`/`--copy` | Copy instead of symlinking (the helper library goes to `DIR/../lib/git-scripts/`) |
| `-f`/`--force` | Replace existing files that this repo did not install |
| `-u`/`--uninstall` | Remove only what this repo installed |
| `-n`/`--dry-run` | Show what would happen |

If the install directory isn't on your `PATH`, the installer prints the line
to add to your shell rc file.

## Commands

Run any command with `-h` for its full usage. (`git <name> --help` opens Git's
man-page lookup instead, so use `-h`, or `git-<name> --help`.)

| Command | What it does |
|---|---|
| `git rebase-branches <base> [<prefix>...]` | Push `<base>` (unless `--no-push`), then rebase the matching local branches onto it, including branches checked out in other worktrees |
| `git remove-merged-branches [<base> [<prefix>...]]` | Delete local branches merged into `<base>`, removing their linked worktrees (a worktree with uncommitted changes, and its branch, is kept); `-s`/`--squash-aware` also catches squash and rebase merges, and `-p`/`--push` also deletes them on the remote |
| `git setup-tracking-branches [<prefix>...]` | Set the upstream of each local branch that has none to the same-named branch on the remote (`-f`/`--fetch` fetches first) |

A `<prefix>` matches branch names that start with it (`feat` matches
`feat/x` and `feature`). With no prefixes, every local branch matches.

Common options:

- `-n`/`--dry-run`: show what would be done without changing anything
- `-y`/`--yes`: skip the confirmation prompt. Commands that ask for confirmation refuse to run without a terminal unless you pass `--yes`.
- `-r`/`--remote`: use a remote other than `origin`

When you leave out the base branch of `git remove-merged-branches`, it uses
`origin/HEAD` (or the `--remote` you chose), falling back to a local `main` or
`master`. If `origin/HEAD` is not set, run `git remote set-head origin --auto`.
`git rebase-branches` always needs the base branch.

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
- Optional: the [GitHub CLI](https://cli.github.com/) (`gh`), so
  `git remove-merged-branches` can show the merged pull request for each branch

## Development

```sh
shellcheck -x bin/* lib/git-scripts/*.sh install test/*.bash
shfmt -d bin/* lib/git-scripts/*.sh install test/*.bash
bats test/
```

CI runs these on Ubuntu and on macOS with the system bash 3.2.
