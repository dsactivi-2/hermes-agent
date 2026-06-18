# Marketing Growth Server Deployment Helpers

## Important SSH Tunnel Limitation

A local SSH tunnel must be opened on the machine where the browser runs. A script that runs only on the remote server cannot create `http://127.0.0.1:9119` on your laptop.

Use one of these options:

- Termius Local Port Forwarding.
- A local shell alias/function that runs `ssh -L`.
- A reverse proxy with real authentication.

## 1. Server Preflight

Run this on the server:

```bash
cd ~/hermes-agent
bash docs/marketing-growth-team/deploy/server-preflight.sh
```

It prints:

- Docker/container status.
- Dashboard listener status.
- Local dashboard HTTP status.
- Hermes profile status.
- SSH hints needed for the local tunnel.

It does not change server state.

## 2. Create Isolated Profiles

Run this on the server to create the default isolated workspaces:

```bash
cd ~/hermes-agent
bash docs/marketing-growth-team/deploy/create-default-isolated-profiles.sh
```

This creates:

| Name | Profile | Isolated dashboard port |
|---|---|---:|
| Arnela | `arnela` | `9120` |
| Denis | `denis` | `9121` |
| Arman | `arman` | `9122` |
| Testing | `testing` | `9123` |

To create another profile with the wizard:

```bash
bash docs/marketing-growth-team/deploy/create-isolated-profile.sh
```

Or non-interactively:

```bash
bash docs/marketing-growth-team/deploy/create-isolated-profile.sh --name Sales --port 9124
```

The script:

- creates or updates the Hermes profile
- copies the marketing-growth template into `/opt/data/profile-workspaces/<profile>` via the host volume
- copies skills into the profile
- migrates/checks config with `doctor --fix`
- starts an isolated dashboard container named `hermes-dashboard-<profile>`

## 3. Install Server Command Helper

Run this on the server:

```bash
bash docs/marketing-growth-team/deploy/install-server-aliases.sh
source ~/.bashrc
```

Then these commands work on the server:

```bash
Hermes Arnela
Hermes Denis model
Hermes Arman doctor
Hermes Testing dashboard
```

`Hermes <Name>` opens chat for that profile. `Hermes <Name> dashboard` prints the local tunnel values for that isolated dashboard.

## 4. Set Model Defaults For Profiles

Run this on the server after API keys are configured:

```bash
bash docs/marketing-growth-team/deploy/set-profile-models.sh \
  --provider openrouter \
  --model x-ai/grok-4.3 \
  --restart-gateway
```

By default it updates `arnela`, `denis`, `arman`, and `testing`.

To update selected profiles:

```bash
bash docs/marketing-growth-team/deploy/set-profile-models.sh \
  --provider openrouter \
  --model x-ai/grok-4.3 \
  arnela denis
```

The script does not write API keys. It only updates `model.provider` and `model.model` in each profile config.

## 5. Add Deep Research Agent

Run this on the server to add the Deep Research agent to all default isolated profiles:

```bash
bash docs/marketing-growth-team/deploy/add-deep-research-agent.sh
```

By default it updates `arnela`, `denis`, `arman`, and `testing`.

To update selected profiles:

```bash
bash docs/marketing-growth-team/deploy/add-deep-research-agent.sh arnela testing
```

The script copies `agents/deep-research/` into each profile workspace and updates the profile's orchestrator `SUBAGENTS.md`, `WORKFLOWS.md`, and `SKILLS.md` with idempotent marked blocks.

## 6. Install Curated Memory System

Run this on the server after the profile workspaces exist:

```bash
bash docs/marketing-growth-team/deploy/install-memory-system.sh
```

By default it updates `arnela`, `denis`, `arman`, and `testing`.

To update selected profiles:

```bash
bash docs/marketing-growth-team/deploy/install-memory-system.sh arnela testing
```

The script:

- creates `memory/shared`, `memory/orchestrator`, `memory/agents`, and `memory/protocols`
- copies only missing memory files, so existing profile memory is not overwritten
- adds idempotent memory instructions to the Orchestrator and specialist agent `MEMORY.md` files
- defines a self-learning loop where agents propose durable learnings and the Orchestrator curates shared memory and Skill candidates

Verify:

```bash
find ~/.hermes/profile-workspaces/arnela/memory -maxdepth 2 -type f | sort
grep -n "Curated Memory System" ~/.hermes/profile-workspaces/arnela/agents/orchestrator/MEMORY.md
```

## 7. Audit Agent Docs, Skills And Tools

Run this on the server or in the repo to audit the blueprint:

```bash
bash docs/marketing-growth-team/deploy/audit-agent-docs.sh
```

Audit a deployed profile workspace:

```bash
bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --profile arnela --report /tmp/arnela-agent-audit.md
```

The audit checks:

- required agent files: `ROLE.md`, `SYSTEM.md`, `SKILLS.md`, `TOOLS.md`, `MEMORY.md`, `WORKFLOWS.md`, `SUBAGENTS.md`
- explicit Skill-first, MCP-second, direct-tools-last rules in `SYSTEM.md`
- role-specific Skill and MCP coverage
- warnings when `SKILLS.md` or `TOOLS.md` are identical across agents
- warnings for broad "all tools" or "all skills" language
- curated memory-system bindings and shared memory template files

Use the report as the input for the next optimization pass instead of letting an automation blindly rewrite prompts.

## 8. Termius Port Forwarding Values

In Termius create a Local Port Forwarding tunnel:

- Local host: `127.0.0.1`
- Local port: the profile's dashboard port, e.g. `9120`
- Destination host: `127.0.0.1`
- Destination port: the same profile dashboard port, e.g. `9120`
- SSH host: your saved server

Then open:

```text
http://127.0.0.1:9120/?profile=arnela
```

## 9. Local Alias Instead Of Typing The Tunnel Command

Run this on your local machine, not on the server:

```bash
cd /path/to/hermes-agent
bash docs/marketing-growth-team/deploy/tunnel-alias-template.sh YOUR_SERVER_HOST root 22
```

Copy the printed function into `~/.bashrc` or `~/.zshrc`, then:

```bash
source ~/.bashrc
hermesdash
```

Open:

```text
http://127.0.0.1:9119/?profile=marketing-growth
```
