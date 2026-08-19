---
name: pr-fix
description: Address issues raised in pull request comments and code reviews. Use when the user wants to fix or resolve feedback from PR reviewers, including inline code review comments and general PR comments.
allowed-tools: Bash(gh pr *), Bash(gh api *), Bash(git *), Bash(xargs -I NUM gh api *), Read, Edit, Write, Grep, Glob, Agent
---

## Pull request context

- PR metadata: !`gh pr view --json number,title,body,headRefName,baseRefName`
- PR review comments: !`gh pr view --json number -q .number | xargs -I NUM gh api "repos/{owner}/{repo}/pulls/NUM/comments" --paginate --template '{{range .}}---{{"\n"}}File: {{.path}}:{{if .line}}{{.line}}{{else}}{{.original_line}}{{end}}{{"\n"}}Author: {{.user.login}}{{"\n"}}Status: {{if .subject_type}}{{.subject_type}}{{else}}comment{{end}}{{"\n"}}Comment: {{.body}}{{"\n"}}{{end}}'`
- Unresolved review threads: !`gh pr view --json number -q .number | xargs -I NUM gh api graphql -F owner='{owner}' -F repo='{repo}' -F num=NUM -f query='query($owner:String!,$repo:String!,$num:Int!){ repository(owner:$owner,name:$repo){ pullRequest(number:$num){ reviewThreads(first:100){ nodes{ isResolved isOutdated path line comments(first:20){ nodes{ author{login} body createdAt } } } } } } }' --template '{{range .data.repository.pullRequest.reviewThreads.nodes}}{{if not .isResolved}}---{{"\n"}}File: {{.path}}:{{.line}}{{"\n"}}Outdated: {{.isOutdated}}{{"\n"}}Comments:{{"\n"}}{{range .comments.nodes}}  {{.author.login}}: {{.body}}{{"\n"}}{{end}}{{end}}{{end}}'`
- PR issue comments: !`gh pr view --comments --json comments --template '{{range .comments}}---{{"\n"}}Author: {{.author.login}}{{"\n"}}Body: {{.body}}{{"\n"}}{{end}}'`
- PR reviews: !`gh pr view --json number -q .number | xargs -I NUM gh api "repos/{owner}/{repo}/pulls/NUM/reviews" --paginate --template '{{range .}}{{if .body}}---{{"\n"}}Author: {{.user.login}}{{"\n"}}State: {{.state}}{{"\n"}}Body: {{.body}}{{"\n"}}{{end}}{{end}}'`
- Changed files: !`gh pr diff --name-only`

## Your task

Address the issues raised in the PR comments and reviews above.

### Workflow

1. Analyze all review comments, inline code comments, and issue comments to identify actionable feedback items.
2. Categorize each item:
   - **Code changes requested**: Specific changes to code (bugs, style, logic, etc.)
   - **Questions**: Reviewer asking for clarification (may not require code changes)
   - **Suggestions**: Optional improvements the reviewer is proposing
   - **Approvals/Acknowledgements**: No action needed
3. For each actionable item, read the relevant file and surrounding context before making changes.
4. Make the requested changes. When a review comment is ambiguous, prefer the most conservative interpretation that still addresses the reviewer's concern.
5. After making all changes, provide a summary of what was addressed and what was skipped (with reasoning for anything skipped).

### Guidelines

- Prioritize unresolved review threads — these are confirmed to still need attention. For PR review comments without resolution status, use judgment based on whether the current code already addresses the feedback.
- Do not make changes beyond what reviewers requested. Avoid scope creep.
- If a reviewer's suggestion conflicts with another reviewer's feedback, flag it in the summary rather than picking a side.
- If a comment requires architectural changes or is unclear, include it in the summary as needing human decision.
