# Memory Policy

Purpose: define how the Marketing & Growth team writes, reviews, and uses memory.

## Memory Layers

- `memory/shared`: approved team-wide facts used by all agents.
- `memory/orchestrator`: decisions, cross-agent learnings, review queue, and skill backlog.
- `memory/agents`: role-specific durable learnings.
- Hermes runtime memory: short operational memory created by Hermes during active work.

## Write Policy

Before writing long-term memory, ask:

1. Will this improve future tasks?
2. Is it stable beyond the current task?
3. Is there a source, metric, or stakeholder approval?
4. Does it avoid private data and raw transcripts?
5. Does it have an owner and review date?

If the answer is unclear, write a proposal to `memory/orchestrator/REVIEW_QUEUE.md`.

## Post-Task Routing Rule

After complex tasks, every agent must classify each candidate learning before writing it:

- Stable, approved, team-wide knowledge goes to `memory/shared`.
- Stable role-specific knowledge goes to `memory/agents/<agent>.md`.
- Cross-agent decisions and operating rules go to `memory/orchestrator`.
- Repeatable procedures go to `memory/orchestrator/SKILL_BACKLOG.md`.
- Uncertain, sensitive, conflicting, low-confidence, or approval-needed items go to `memory/orchestrator/REVIEW_QUEUE.md`.

If new information contradicts existing memory, mark the older item as conflicting, superseded, or needs-review. Do not silently overwrite it.

## Required Metadata

Durable memory should include:

- date
- source or evidence
- scope
- confidence
- owner
- review date
- status when relevant

## Conflict Handling

- Prefer approved memory over drafts.
- Prefer newer approved memory over older approved memory.
- Preserve superseded decisions with status `superseded`.
- Escalate conflicts to the Orchestrator review queue.
