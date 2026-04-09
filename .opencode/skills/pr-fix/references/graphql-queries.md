# GraphQL Mutations for PR Review Threads

Reference for the `pr-fix` skill. Contains GraphQL mutations for resolving threads and REST commands for replying.

**Fetching threads** is handled by `get-pr-comments.sh` (see Step 2 in SKILL.md). The script returns structured JSON with `thread_id` (GraphQL node ID) and `first_comment_id` (REST API ID) ready for the mutations below.

## Resolve a Thread

Marks a review thread as resolved. Requires the GraphQL node `id` from the fetch query.

```bash
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {
    threadId: "{threadId}"
  }) {
    thread {
      id
      isResolved
    }
  }
}
'
```

Replace `{threadId}` with the `thread_id` field from the script output.

**Permissions required:** Repository Contents: Read and Write.

## Unresolve a Thread

Reverses a thread resolution (rarely needed, included for completeness).

```bash
gh api graphql -f query='
mutation {
  unresolveReviewThread(input: {
    threadId: "{threadId}"
  }) {
    thread {
      id
      isResolved
    }
  }
}
'
```

## Reply to a Review Comment

Uses the REST API to reply directly to a review comment thread. This creates a threaded reply, not a standalone PR comment.

```bash
gh api repos/{owner}/{repo}/pulls/comments/{databaseId}/replies \
  -X POST \
  -f body='{response text}'
```

Replace:
- `{owner}/{repo}` — the repository (e.g., `DataDog/dd-source`)
- `{databaseId}` — the `first_comment_id` from the script output
- `{response text}` — the reply body (supports GitHub-flavored markdown)

## Fallback: PR Comment When Threaded Reply Unavailable

When `first_comment_id` is `0`/missing or the threaded reply endpoint returns an error,
fall back to a top-level PR comment.
This is not threaded but clearly references the original review comment.

```bash
gh pr comment {number} --body "$(cat <<'EOF'
Re: [{path}:{line}]({html_url}) (@{author})

{response text}
EOF
)"
```

Replace:
- `{number}` — the PR number
- `{path}` — file path from the thread
- `{line}` — line number from the thread
- `{html_url}` — `comments[0].html_url` (direct link to the original review comment)
- `{author}` — `comments[0].author` (mentions the reviewer for notification)
- `{response text}` — the reply body (same content as would have been posted as a threaded reply)

## Request Re-Review

After all threads are addressed, request re-review from specific reviewers:

```bash
gh pr edit {number} --add-reviewer {reviewer1},{reviewer2}
```

## Batch Processing Pattern

For PRs with many threads, process in batches to avoid API rate limits:

1. Fetch all threads in one GraphQL call (up to 100 threads, 50 comments each).
2. Apply all code changes locally (no API calls).
3. Reply to threads in sequence (REST API, one call per thread).
4. Resolve threads in sequence (GraphQL mutation, one call per thread).
5. Commit and push once.

This minimizes API calls: 1 fetch + N replies + N resolves + 1 push.
