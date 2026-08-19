# Rules and Preferences

## Output style

- Plain ASCII only, in everything: prose, code, comments, commit messages, PR text, docs.
  Substitutions: em/en dash -> comma or separate sentence or `-`; arrow -> `->`;
  curly quotes -> `"` and `'`; ellipsis -> `...`. No decorative unicode (bullet symbols, etc).
- Prefer plain sentences over clauses joined by dashes or arrows.
- Do not refer to Chance by name in code comments, commit messages, or PR text. Use "I" instead of "Chance" or "ChanceZ".
- Avoid pronouns in commit messages and PR text. Use "I" instead of "we" or "us". Use "you" only when addressing the reader directly.
- Rephrase direct statements: Focus sentences on evidence and core arguments.

## Code

- Tests: assert the entire value returned from a function, not individual fields.
- Go: use `new("string")` / `new(5)` (valid as of Go 1.26) rather than a generic `ptr()`
  helper or a temp variable plus `&`.
- Go: when writing tests that deal with concurrency and/or require specific
  timing, use the `testing/synctest` package.

## Git

- Branch names: `pr/chancez/<CHANGE_NAME>`.
- Commit in small logical units, one concern per commit. Every commit must build and pass
  tests so history stays bisectable.
- Commit periodically to save progress even when the work is incomplete. Squash fixups into
  the right commit once we stop iterating.
- Do not push branches unless explicitly told to or only push when you've been
  asked to open a PR.
- To rebase, `git fetch` the configured remote and rebase onto `$REMOTE/$BASE_BRANCH`.
  Do not check out the base branch and `git pull` it: this avoids having to leave the current branch.
- If the local `$BASE_BRANCH` is ahead of the remote, rebase against `$BASE_BRANCH` instead.

## Writing PRs

- Summary is a high-level overview, scaled to the size of the change. The commit messages
  carry the detail and can be reviewed independently.
- Do not list every change.
- Do not open a PR unless explicitly told to.

## Reviewing PRs

- Never post a comment or review, including a re-review, without confirming with me first.
- Check out the PR in a new git worktree if you need to run it or make local changes.
- Do not run code unless you suspect a logic bug or a gap in their tests. CI already runs the
  tests, focus on the changes themselves.
- Keep each comment short and casual, not robotic.
- Raise concrete issues only. Verify a suspicion or ask me to check, do not speculate.
- The overall summary should not repeat the individual comments.
- Point at existing patterns or helpers in the project they could reuse, or suggest a helper
  when logic should be shared.
- A bug fix needs a regression test. Confirm the test fails without their fix and passes with it.
