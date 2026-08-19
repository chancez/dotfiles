---
name: pr-summary
description: Summarize the changes in a pull request. Use when the user wants an overview of what a PR does, asks "what's in this PR", "summarize this PR", "what changed on this branch", or wants to understand a PR before reviewing or merging it. Works with a specific PR number or the PR for the current branch.
argument-hint: "[pr-number]"
context: fork
agent: Explore
allowed-tools: Bash(gh pr diff:*), Bash(gh pr view:*)
---

## Pull request context

- PR metadata: !`gh pr view $ARGUMENTS --json number,title,body,author,headRefName,baseRefName,additions,deletions,changedFiles`
- Changed files: !`gh pr diff --name-only $ARGUMENTS`
- PR diff: !`gh pr diff $ARGUMENTS`
- PR comments: !`gh pr view --comments $ARGUMENTS`

## Your task

Summarize this pull request so a reader can understand what it does and why without reading the full diff. If a PR number was provided as input it is used above; otherwise the PR for the current branch is used.

The goal is a summary that's genuinely more useful than the raw diff: lead with intent and impact, group related changes so the reader sees the shape of the work, and surface anything a reviewer or merger would want to know before approving.

### Output format

# [PR title] (#[number])

## Overview
One or two sentences on what this PR does and why. Draw on the PR description for stated intent, but verify it against the actual diff -- if the description and the code disagree, summarize what the code does and note the discrepancy.

## Changes
Group related changes by area, feature, or concern rather than listing files one by one. For each group, explain what changed and the reasoning where it's evident from the code. A reader should come away understanding the structure of the work, not just a file inventory.

## Notable details
Call out anything a reviewer would want flagged, when present:
- Behavioral or API changes, especially breaking ones
- New dependencies, config, or migrations
- Tests added, changed, or notably missing
- Open questions or concerns raised in the PR comments
- Anything the code does that the PR description doesn't mention

Omit this section if there's nothing worth flagging rather than padding it.

### Guidelines

- Match the summary's length to the size of the change. A one-line typo fix gets a one-line summary; a large feature gets proportionally more. Don't inflate a small PR into a lengthy report.
- Describe what the code actually does, not just what the PR description claims. The description is a starting point, not ground truth.
- Be concrete. Prefer "adds retry with exponential backoff to the S3 upload client" over "improves error handling."
