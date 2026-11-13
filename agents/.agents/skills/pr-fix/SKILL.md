---
name: pr-fix
description: "Address issues on a pull request: review feedback, failing CI checks, and merge conflicts with the base branch. Use when the user wants to fix or resolve feedback from PR reviewers (inline code review comments and general PR comments), fix a PR's failing checks, or resolve its conflicts with the base branch."
argument-hint: "Extra instructions, e.g. which comments or issues to address or skip, or only CI/conflicts"
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(gh run *), Bash(git *), Bash(xargs -I NUM gh api *), Read, Edit, Write, Grep, Glob, Agent
---

## Pull request context

- PR metadata: !`gh pr view --json number,title,body,headRefName,baseRefName`
- PR review comments: !`gh pr view --json number -q .number | xargs -I NUM gh api "repos/{owner}/{repo}/pulls/NUM/comments" --paginate --template '{{range .}}---{{"\n"}}File: {{.path}}:{{if .line}}{{.line}}{{else}}{{.original_line}}{{end}}{{"\n"}}Author: {{.user.login}}{{"\n"}}Status: {{if .subject_type}}{{.subject_type}}{{else}}comment{{end}}{{"\n"}}Comment: {{.body}}{{"\n"}}{{end}}'`
- Unresolved review threads: !`gh pr view --json number -q .number | xargs -I NUM gh api graphql -F owner='{owner}' -F repo='{repo}' -F num=NUM -f query='query($owner:String!,$repo:String!,$num:Int!){ repository(owner:$owner,name:$repo){ pullRequest(number:$num){ reviewThreads(first:100){ nodes{ isResolved isOutdated path line comments(first:20){ nodes{ author{login} body createdAt } } } } } } }' --template '{{range .data.repository.pullRequest.reviewThreads.nodes}}{{if not .isResolved}}---{{"\n"}}File: {{.path}}:{{.line}}{{"\n"}}Outdated: {{.isOutdated}}{{"\n"}}Comments:{{"\n"}}{{range .comments.nodes}}  {{.author.login}}: {{.body}}{{"\n"}}{{end}}{{end}}{{end}}'`
- PR issue comments: !`gh pr view --json comments --template '{{range .comments}}---{{"\n"}}Author: {{.author.login}}{{"\n"}}Body: {{.body}}{{"\n"}}{{end}}'`
- PR reviews: !`gh pr view --json number -q .number | xargs -I NUM gh api "repos/{owner}/{repo}/pulls/NUM/reviews" --paginate --template '{{range .}}{{if .body}}---{{"\n"}}Author: {{.user.login}}{{"\n"}}State: {{.state}}{{"\n"}}Body: {{.body}}{{"\n"}}{{end}}{{end}}'`
- Changed files: !`gh pr diff --name-only`
- Mergeability and checks: !`gh pr view --json mergeable,mergeStateStatus,statusCheckRollup --template '{{"Mergeable: "}}{{.mergeable}} ({{.mergeStateStatus}}){{"\n"}}{{range .statusCheckRollup}}{{if eq .__typename "CheckRun"}}{{.name}}: {{.status}} {{.conclusion}} {{.detailsUrl}}{{else}}{{.context}}: {{.state}} {{.targetUrl}}{{end}}{{"\n"}}{{end}}'`

## Your task

Address the issues on the PR above: review feedback, failing CI checks, and merge conflicts with the base branch.

If the user passed arguments, treat them as extra instructions for this run (which comments to address or skip, how to resolve a specific item, added context). They take precedence over the workflow and guidelines below.

### GitHub is read-only

Use `gh` only to read the PR and its CI runs. All output goes to the user in this conversation. Do not post, edit, or react to comments, submit reviews, or resolve threads on GitHub unless the user explicitly asks for that in this conversation or in the skill arguments. When a reply seems warranted, draft it in the summary for the user to post.

### Workflow

1. Analyze all review comments, inline code comments, and issue comments to identify actionable feedback items.
2. Categorize each item:
   - **Code changes requested**: Specific changes to code (bugs, style, logic, etc.)
   - **Questions**: Reviewer asking for clarification (may not require code changes)
   - **Suggestions**: Optional improvements the reviewer is proposing
   - **Approvals/Acknowledgements**: No action needed
3. For each actionable item, read the relevant file and surrounding context before making changes.
4. Make the requested changes. When a review comment is ambiguous, prefer the most conservative interpretation that still addresses the reviewer's concern.
5. For failing checks, read the failure before changing code: `gh run view <run-id> --log-failed`, using the run ID from the check's URL. Fix failures caused by the PR. Report flaky or unrelated failures instead of working around them.
6. If the PR conflicts with the base branch (`CONFLICTING` / `DIRTY`), `git fetch` the remote and rebase onto `<remote>/<baseRefName>`. Resolve each conflict by keeping the intent of both sides. Build and run tests after the rebase. Do not push.
7. After making all changes, provide a summary of what was addressed and what was skipped (with reasoning for anything skipped). Include draft answers to reviewer questions.

### Guidelines

- Prioritize unresolved review threads — these are confirmed to still need attention. For PR review comments without resolution status, use judgment based on whether the current code already addresses the feedback.
- Do not make changes beyond what reviewers requested or what is needed to fix CI and conflicts. Avoid scope creep.
- If a reviewer's suggestion conflicts with another reviewer's feedback, flag it in the summary rather than picking a side.
- If a comment requires architectural changes or is unclear, include it in the summary as needing human decision.
