INSTRUCTIONS : First, ask the user to specify relevant files, directories, or areas of the codebase to examine for this planning task.

Then use the Task tool with subagent_type 'planner' to invoke the planner agent with the following explicit instructions:

STEP 1: CREATE TODO LIST FILE
First, create a todo list file with the following tasks enumerated in order:

1. Ask user for relevant files and context (if not already provided)
2. Use Task tool with subagent_type 'jira' to verify Jira ticket information (or ask user to create/provide ticket)
3. Perform targeted initial research on user-specified files
4. Consult relevant sub-agents with research context (run in parallel when possible)
5. Create high-level strategic implementation plan
6. Iterate with user feedback
7. Suggest user runs '/air-record' command to save the plan to Jira ticket

STEP 2: EXECUTE EACH TASK IN ORDER
Work through each task in the todo list sequentially:
- Mark each task as 'in_progress' when you start it
- Mark each task as 'completed' when finished
- Continue until all tasks are done

IMPORTANT CONTEXT-SHARING PROTOCOL:
- When consulting sub-agents, explicitly provide: files already searched, files already read, key findings, and specific focus area
- This prevents sub-agents from duplicating research work

IMPORTANT PLAN CONSTRAINTS:
- Focus on strategic, high-level implementation guidance
- NO rollout plans, effort estimates, or exhaustive code implementations
- Small code examples (5-10 lines) are OK to illustrate concepts

User specified relevant files/areas: [User will specify]

Ask the user to provide a Jira ticket or task description.
