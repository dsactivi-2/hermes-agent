# Marketing & Growth Role Capability Matrix

This matrix is the production contract for every isolated Marketing & Growth
profile copy. The profile owns the shared skill library, while each agent owns
role-specific routing, preferred MCP servers, direct-tool boundaries, and model
preference.

## Global Rule

- Profile skills live in `profiles/<profile>/skills` and are shared library assets.
- Agent skill ownership lives in `profile-workspaces/<profile>/agents/<agent>/SKILLS.md`.
- The Orchestrator routes work and composes final decisions. It must not behave
  as the owner of every specialist skill.
- Specialists use only the skills, MCP servers, plugins, and direct tools that
  fit their role and hand off cross-domain work instead of expanding scope.

## Role Matrix

| Agent | Primary skill families | Preferred MCP servers | Preferred model | Fallback model |
| --- | --- | --- | --- | --- |
| `orchestrator` | campaign brief, delegation router, brand bootstrap, skill gap review, campaign postmortem | `marketing_fs`, `notion`, `analytics`, `social_posting`, `github` | strongest reasoning model configured for the profile | profile fallback chain |
| `content-writer` | brand voice, LinkedIn series, landing page copy, email nurture, case study, ad variants | `notion`, `marketing_fs`, `browser`, `analytics` | strongest writing model configured for the profile | profile fallback chain |
| `social-media-specialist` | LinkedIn calendar, repurposing, comment playbook, scheduling checklist, hashtag/topic map | `social_posting`, `notion`, `analytics`, `browser` | fast creative/writing model configured for the profile | profile fallback chain |
| `seo-web` | landing page audit, UTM taxonomy, search intent brief, prelaunch tracking, SEO refresh | `browser`, `analytics`, `github`, `marketing_fs`, `notion` | strong technical/research model configured for the profile | profile fallback chain |
| `creative-design` | visual campaign brief, image prompt, carousel production, brand asset QA, deck outline | `marketing_fs`, `notion`, `browser`, `google-drive`, `figma`, `slides` | multimodal/creative model configured for the profile | profile fallback chain |
| `campaign-analyst` | KPI tree, UTM validator, weekly report, dashboard brief, experiment design, analytics postmortem | `analytics`, `social_posting`, `notion`, `marketing_fs`, CRM MCP | strongest analytical model configured for the profile | profile fallback chain |
| `deep-research` | research brief, source quality rubric, competitor intel, persona research, trend scan, evidence brief | `marketing_fs`, `browser`, `notion`, `analytics`, `github` | strongest long-context research model configured for the profile | profile fallback chain |
| `memory-review-reflector` | memory triage, conflict resolution, skill backlog prioritization, skill builder brief, quality audit | `marketing_fs`, `notion`, `analytics`, `github`, observability/log MCP | careful review model configured for the profile | profile fallback chain |

## Model Assignment Contract

Hermes currently applies `model.provider`, `model.model`, and `model.fallback`
at the profile level. Per-agent model selection is therefore an orchestration
contract unless a runtime later adds native subagent model overrides.

Each agent must:

- state its preferred model class in `TOOLS.md`
- fall back to the profile fallback chain rather than inventing a model setting
- use cheaper/faster models only for low-risk drafts, never for final claims,
  compliance, analytics interpretation, or source-heavy research

