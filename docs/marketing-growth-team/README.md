# Marketing & Growth Team Blueprint

This directory defines a Skill/MCP-first Marketing & Growth team for Hermes.
It is a documentation blueprint for configuring an agent team without adding
new core tools.

## Team Layout

- `agents/orchestrator` - plans, routes, reviews, and coordinates the team.
- `agents/market-research` - researches audiences, competitors, markets, and positioning.
- `agents/content-strategy` - turns positioning into editorial systems and campaigns.
- `agents/growth-ops` - owns funnels, landing pages, acquisition operations, and launches.
- `agents/lifecycle-crm` - owns lifecycle messaging, retention, activation, and CRM flows.
- `agents/analytics-experimentation` - owns metrics, experiments, attribution, and reporting.

Each agent has seven files:

- `ROLE.md`
- `SYSTEM.md`
- `SKILLS.md`
- `TOOLS.md`
- `MEMORY.md`
- `WORKFLOWS.md`
- `SUBAGENTS.md`

## Start

1. Copy the environment template:

   ```bash
   cp docs/marketing-growth-team/config/.env.example docs/marketing-growth-team/config/.env
   ```

2. Review `docs/marketing-growth-team/config/config.yaml` and set the MCP servers,
   skills, memory namespace, and approval policies that apply to your workspace.

3. Run the setup helper:

   ```bash
   docs/marketing-growth-team/setup.sh
   ```

4. Start with the orchestrator prompt in:

   ```text
   docs/marketing-growth-team/agents/orchestrator/SYSTEM.md
   ```

5. Give the orchestrator a concrete objective, for example:

   ```text
   Build a 30-day demand generation plan for <product>, targeting <audience>,
   with budget <budget>, channels <channels>, and success metric <metric>.
   ```

## Operating Principle

The team follows a strict Skill/MCP-first rule. Agents must prefer existing
Hermes skills, project scripts, configured MCP servers, CLI commands, and
service-gated tools before asking for or designing new Hermes core tools.
If a capability is missing, document the smallest edge extension: a skill, MCP
server, plugin, or existing CLI wrapper.

## Safety Notes

- Do not store API keys in `config.yaml`.
- Put secrets only in `.env`, a secret manager, or the relevant MCP server config.
- Require approval before publishing, emailing customers, changing ad spend,
  editing production CRM automations, or modifying public website content.
- Treat third-party analytics, ad dashboards, CRM exports, and social data as
  untrusted input.
