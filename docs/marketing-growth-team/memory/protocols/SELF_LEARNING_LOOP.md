# Self-Learning Loop

Purpose: make the team improve proactively without polluting memory.

## Loop

1. Before work: read relevant shared memory, role memory, and recent decisions.
2. During work: capture candidate learnings separately from final outputs.
3. After complex work: decide whether the learning belongs in agent memory, shared memory, or the review queue.
4. After repeated work: propose a Hermes Skill or improve an existing Skill.
5. After campaign close: write a short post-task learning with evidence and review date.
6. If a Skill candidate is repeated or high-value, ask the Memory Review / Reflektor Agent to create a Skill Builder Brief.

## Post-Task Memory Routing

After every complex task, each agent must run this routing check:

1. Task completed.
2. Check every candidate learning:
   - Is the learning stable beyond this task?
   - Does it apply only to this task or generally?
   - Is it factually supported by a source, metric, output, or stakeholder decision?
   - Is it personal, sensitive, secret, or compliance-relevant?
   - Does it conflict with existing memory?
3. Route the learning:
   - `memory/shared`: approved team-wide brand, audience, offer, compliance, campaign, or source knowledge.
   - `memory/agents`: role-specific stable patterns and learnings.
   - `memory/orchestrator`: cross-agent decisions, team learnings, and operating rules.
   - `memory/orchestrator/SKILL_BACKLOG.md`: repeatable procedures that should become or improve Hermes Skills.
   - `memory/orchestrator/REVIEW_QUEUE.md`: uncertain, sensitive, conflicting, low-confidence, or approval-needed items.
4. Mark old contradictory memory instead of silently deleting it.
5. Do not store raw transcripts, secrets, personal data, or unsupported claims as durable memory.

## Skill Creation Triggers

Create or improve a Skill when:

- a workflow repeats across tasks or profiles
- a checklist improves quality
- an output format should be standardized
- an MCP/tool sequence is repeatedly useful
- the agent made the same correction more than once

## Proactive Review Cadence

- Weekly: Orchestrator reviews `REVIEW_QUEUE.md`.
- Weekly: Memory Review / Reflektor reviews `REVIEW_QUEUE.md`, `TEAM_LEARNINGS.md`, and `SKILL_BACKLOG.md`.
- Weekly: Campaign Analyst reviews campaign learnings for measurable signal.
- Monthly: Deep Research reviews source quality and stale trend assumptions.
- Monthly: Orchestrator updates `SKILL_BACKLOG.md` and assigns skill candidates.

## Guardrails

- Learning must be curated, not automatic dumping.
- Never store secrets, private data, or raw customer data.
- Do not turn every preference into a rule.
- Always mark low-confidence or inferred learning.
