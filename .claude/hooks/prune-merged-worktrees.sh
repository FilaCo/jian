#!/usr/bin/env bash
# Removes what a squash-merged PR leaves behind: its worktree under .claude/worktrees and its local branch.
# GitHub deletes a merged head branch (delete_branch_on_merge), so after a prune its upstream is gone;
# a branch is removed only when a MERGED PR's head is its tip, and a worktree only when it is clean and idle,
# so a session still in it, or work never pushed, is left alone. What is kept is listed on stderr;
# `--dry-run` prints the commands instead of running them.
set -u
[ "${1:-}" = --dry-run ] && run=echo || run=
here=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
root=$(git rev-parse --path-format=absolute --git-common-dir) || exit 0
root=$(dirname "$root")
cd "$root" || exit 0
command -v gh >/dev/null || exit 0
git fetch --prune --quiet 2>/dev/null || exit 0

idle_minutes=120

# A PR merged this very commit: a name merged once and reused for new work, or a fork's branch of the
# same name, has another tip and is kept.
merged() {
  gh pr list --head "$1" --state merged --limit 100 --json headRefOid --jq '.[].headRefOid' 2>/dev/null |
    grep -qx "$(git rev-parse "refs/heads/$1")"
}

git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads |
  awk '$2 == "[gone]" { print $1 }' |
  while read -r branch; do
    merged "$branch" || continue
    wt=$(git worktree list --porcelain | awk -v b="refs/heads/$branch" '/^worktree /{w=substr($0,10)} $0=="branch "b{print w}')
    if [ -n "$wt" ]; then
      case "$wt" in "$root"/.claude/worktrees/*) ;; *) continue ;; esac
      [ "$wt" = "$here" ] && continue
      if [ -n "$(git -C "$wt" status --porcelain)" ]; then echo "kept $wt: uncommitted changes" >&2; continue; fi
      if [ -n "$(find "$(git -C "$wt" rev-parse --absolute-git-dir)" -maxdepth 1 -name index -mmin -$idle_minutes)" ]; then
        continue
      fi
      $run git worktree remove --force "$wt" || continue
    fi
    $run git branch -D --quiet "$branch" && echo "removed $branch${wt:+ and $wt}" >&2
  done
exit 0
