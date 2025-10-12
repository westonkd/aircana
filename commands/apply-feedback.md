INSTRUCTIONS : Use the Task tool with subagent_type 'apply-feedback' to apply code review feedback from the previous /air-review command.

Pass the review feedback from the conversation context to the apply-feedback agent.

The apply-feedback agent will:
1. Parse review feedback from the previous review
2. Create todo list of changes prioritized by severity
3. Present plan to user for approval
4. Apply approved changes
5. Re-run unit tests to verify changes
6. Fix any test failures
7. Amend the HEAD commit with improvements using 'git commit --amend --no-edit'
8. Summarize changes made

IMPORTANT: This command reads the review output from the conversation context, so it must be run in the same conversation as /air-review.
