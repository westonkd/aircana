INSTRUCTIONS : Use the Task tool with subagent_type 'reviewer' to conduct an adversarial code review of the HEAD commit.

The reviewer agent will:
1. Get HEAD commit details and changes
2. Analyze changed files to identify technical domains
3. Use the sub-agent-coordinator to select relevant expert agents
4. Present changes to experts in parallel for review
5. Synthesize feedback organized by severity
6. Store review output for the apply-feedback command
7. Suggest running '/air-apply-feedback' to apply recommended changes

IMPORTANT: The review agent will automatically review the HEAD commit. No arguments needed.
