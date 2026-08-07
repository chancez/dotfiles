# Personal Preferences

## Prose

- NEVER use unicode characters that aren't easily typed on a standard US keyboard. This includes but is not limited to:
  - Em dashes (—). Use a comma or separate sentence.
  - En dashes (–) use a single hyphen instead.
  - Arrows (→). Use `->` or just avoid needing arrows in the first place.
  - Fancy quotes (curly/smart quotes) -- use straight quotes `"` and `'`
  - Ellipsis character -- use three periods `...` instead
  - Any other decorative or typographic unicode (bullet symbols, etc.)
- Stick to plain ASCII in all output: prose, code comments, commit messages, PR descriptions, and documentation.
- When possible, just try to write plain sentences instead of using arrows, dashes, or other similar things.

## Testing

- When writing tests, prefer asserting the entire value returned from a function instead of checking individual fields.

## Go/Golang

- As of Go 1.26 `new("string")`, `new(5)` are valid, and preferred over generic `ptr(..)` functions, or creating a temporary variable and taking the address of it.

## Branching

When creating branches adhere to the form of `pr/chancez/<CHANGE_NAME>`.

## Committing

Break up your changes into logical commits.

Commits should be relatively small in scope, and should not do multiple things in a single commit.

When fixing changes, you can squash/fixup new commits into the correct commits after we're done iterating.

Commit periodically to save progress, even if the changes are not complete.

This let's us see the history of the changes and makes it easier to review.
The end goal is that every commit builds and passes tests, so that we can bisect to find regressions.

## Pushing

My remote is named `isovalent`, not `origin`.
Use `git push isovalent <branch>` to push your changes.

## Writing PRs

When asked to write PR titles and summaries, try to keep the PR summary relatively short/concise, or scaled to the size of the change.

You don't need to list every change. The commits and commit messages already provide this.

The commits can be reviewed independently and their commit messages should contain the necessary context for the change.
The PR summary should provide a high-level overview of the changes made, while the commit messages should provide more detailed information about each individual change.

## Reviewing PRs

Never post comments on a PR without first confirming, this includes re-reviews.

If your going to make local changes, or checkout the PR during review, create a new git worktree for your review and do your changes in the worktree to isolate them.

Try to minimize how much time you spend running code locally. PRs already run tests in CI, and you should focus on the changes themselves.
Limit running code locally to testing if they've got gaps in tests, or if you suspect there's a bug in their logic.

When reviewing PRs, try to keep each review comment short.
Be sort of informal or casual. I generally do not talk like a robot, so try not to sound like one.
When writing an overall review summary, do not repeat what is already in the individual review comments.
Focus on concrete issues, and do not guess if something might be incorrect, either verify it, or ask me to check.

When possible, if an existing design pattern or concept already exists in the project that someone can reuse, suggest reusing the same approach, or create helpers when necessary to share the logic.

If the PR is fixing a bug, there should always be a corresponding test added that would have caught the bug.
Confirm that without their fixes, their new test fails and would correctly catch the bug, and passes with their changes, confirming they've fixed the bug.
