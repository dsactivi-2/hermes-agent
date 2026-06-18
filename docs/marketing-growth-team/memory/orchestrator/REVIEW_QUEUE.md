# Orchestrator Memory: Review Queue

Purpose: staging area for proposed memory updates before they become durable shared memory.

## Pending Items

Use this format:

```text
Date:
Proposed by:
Target memory file:
Proposed update:
Source/evidence:
Reason this should be remembered:
Risk if wrong:
Confidence:
Decision needed:
Status: pending/approved/rejected/needs-source
```

## Review Rules

- Agents propose durable updates here when the information affects future work.
- Orchestrator promotes approved items into `memory/shared`, `memory/orchestrator`, or `memory/agents`.
- Reject raw notes, private data, unsupported claims, stale platform assumptions, and one-off details.

