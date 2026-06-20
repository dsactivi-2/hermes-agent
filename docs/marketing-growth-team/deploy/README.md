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

## 1b. Remote Gateway Preflight

Run this on the server when Hermes Desktop or another remote client cannot reach a profile gateway:

```bash
cd ~/hermes-agent
bash docs/marketing-growth-team/deploy/remote-gateway-preflight.sh --profile arman --public-host 46.225.222.164
```

It prints:

- profile `.env` and `config.yaml` paths
- API server host/port/CORS values
- masked API key fingerprint, never the full key
- Docker and Hermes gateway status
- listener status for the API port
- local `/health` and `/v1/models` checks
- public `/health` check from the server to the public IP/domain
- `ufw` status and network reminders

If local checks pass but the public check fails, the issue is usually `ufw`, provider firewall, wrong public IP/domain, or a closed TCP port.

## 1c. Stack Status Read-Only

Run this on the server when you are unsure which phases have already been applied:

```bash
cd ~/hermes-agent
bash docs/marketing-growth-team/deploy/stack-status-readonly.sh --public-host 46.225.222.164
```

For a deeper read-only check, include profile audits:

```bash
bash docs/marketing-growth-team/deploy/stack-status-readonly.sh --public-host 46.225.222.164 --audit
```

It reports:

- git branch/head and docs dirty state
- Docker containers
- blueprint template completeness in `docs/marketing-growth-team`
- profile, workspace, agent and memory completeness
- dashboard/API local and public health
- gateway state per profile
- model summary per profile
- missing install phases and recommended next commands

It does not change files, containers, profiles, gateways, firewall, or configs.

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
- copies the marketing-growth template into `/opt/data/profile-workspaces/<profile>` inside the profile dashboard container
- copies skills into the profile
- migrates/checks config with `doctor --fix`
- starts an isolated dashboard container named `hermes-dashboard-<profile>` with only that profile directory mounted as `/opt/data`

## 2b. Harden Existing Dashboard Containers

Run this after older isolated dashboards were already created with the full
Hermes data root mounted:

```bash
cd ~/hermes-agent
bash docs/marketing-growth-team/deploy/harden-dashboard-containers.sh
```

The default mode is read-only. It shows:

- current dashboard mounts
- local dashboard health
- which profiles the dashboard API can see

If any profile dashboard can see sibling profiles, recreate the dashboard
containers with narrow per-profile mounts:

```bash
bash docs/marketing-growth-team/deploy/harden-dashboard-containers.sh --apply
```

Cloudflare Access controls who can reach a hostname. Narrow dashboard mounts
control what that hostname's dashboard can see after login.

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

## 7. Add Memory Review / Reflektor Agent

Run this on the server to add the Memory Review / Reflektor agent to all default isolated profiles:

```bash
bash docs/marketing-growth-team/deploy/add-memory-review-reflector-agent.sh
```

By default it updates `arnela`, `denis`, `arman`, and `testing`.

To update selected profiles:

```bash
bash docs/marketing-growth-team/deploy/add-memory-review-reflector-agent.sh arnela testing
```

The script copies `agents/memory-review-reflector/` into each profile workspace, ensures the Reflektor memory and Skill Builder protocol exist, and updates the profile's orchestrator `SUBAGENTS.md`, `WORKFLOWS.md`, and `SKILLS.md` with idempotent marked blocks.

## 8. Upgrade Existing Profile Memory Routing

Run this after pulling newer blueprint changes into an already deployed server:

```bash
bash docs/marketing-growth-team/deploy/upgrade-profile-memory-routing.sh
```

By default it updates `arnela`, `denis`, `arman`, and `testing`.

The script is idempotent. It appends only missing upgrade blocks and copies only new required files:

- post-task memory routing blocks in existing agent `MEMORY.md` files
- `memory/agents/memory-review-reflector.md`
- `memory/protocols/SKILL_BUILDER_WORKFLOW.md`
- Memory Review / Reflektor agent files
- Orchestrator links to the Reflektor workflow and Skill Builder candidates
- Campaign Analyst `dashboard-brief` Skill candidate if missing

## 9. Bind Orchestrator Persona

Run this after the profile workspaces exist and agent docs are installed:

```bash
bash docs/marketing-growth-team/deploy/bind-orchestrator-persona.sh
```

By default it updates `arnela`, `denis`, `arman`, and `testing`.

This writes each profile's `SOUL.md` so the chat entrypoint behaves as the
Marketing & Growth Orchestrator and knows its specialist roster. Without this
binding, the profile may have all agent files on disk but still answer like a
generic Hermes profile.

Verify:

```bash
grep -n "marketing-growth-orchestrator-persona" ~/.hermes/profiles/denis/SOUL.md
```

## 10. Audit Agent Docs, Skills And Tools

To verify the live deployed profile instances, not just the blueprint docs:

```bash
bash docs/marketing-growth-team/deploy/verify-marketing-growth-instances.sh
```

Run this on the server or in the repo to audit the blueprint:

```bash
bash docs/marketing-growth-team/deploy/audit-agent-docs.sh
bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --report /tmp/marketing-growth-template-audit.md
```

Audit a deployed profile workspace:

```bash
bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --profile arnela --report /tmp/arnela-agent-audit.md
```

Audit the blueprint and all default deployed profile workspaces:

```bash
bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --report /tmp/marketing-growth-template-audit.md
for p in arnela denis arman testing; do
  bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --profile "$p" --report "/tmp/$p-agent-audit.md"
done
grep -n "WARN:\|FAIL:" /tmp/marketing-growth-template-audit.md /tmp/*-agent-audit.md
```

The audit checks:

- required agent files: `ROLE.md`, `SYSTEM.md`, `SKILLS.md`, `TOOLS.md`, `MEMORY.md`, `WORKFLOWS.md`, `SUBAGENTS.md`
- explicit Skill-first, MCP-second, direct-tools-last rules in `SYSTEM.md`
- role-specific Skill and MCP coverage
- warnings when `SKILLS.md` or `TOOLS.md` are identical across agents
- warnings for broad "all tools" or "all skills" language
- curated memory-system bindings and shared memory template files
- post-task memory routing: stability, generality, evidence, sensitivity, conflicts, and routing to shared memory, agent memory, orchestrator memory, skill backlog, or review queue

Use the report as the input for the next optimization pass instead of letting an automation blindly rewrite prompts.

## 10. Cloudflare Access For Browser Dashboards

Recommended mode:

```text
Browser -> Cloudflare Access -> Cloudflare Tunnel -> 127.0.0.1:9120-9123
```

This keeps the Hermes dashboard ports local-only on the server and exposes
HTTPS hostnames through Cloudflare Access login.

The generated tunnel config sets `originRequest.httpHostHeader: 127.0.0.1`
for each dashboard. Keep that setting. Hermes dashboards are bound to
loopback and reject public `Host` headers such as `denis.example.com` to
protect against DNS rebinding.

Run the read-only planner first:

```bash
cd ~/hermes-agent
bash docs/marketing-growth-team/deploy/cloudflare-access-tunnel.sh --domain example.com
```

Replace `example.com` with the domain that is in your Cloudflare account.
The planned hostnames are:

| Profile | Public hostname | Local origin |
|---|---|---|
| arnela | `https://arnela.example.com` | `http://127.0.0.1:9120` |
| denis | `https://denis.example.com` | `http://127.0.0.1:9121` |
| arman | `https://arman.example.com` | `http://127.0.0.1:9122` |
| testing | `https://testing.example.com` | `http://127.0.0.1:9123` |

Install and authenticate `cloudflared` on the server:

```bash
cloudflared tunnel login
cloudflared tunnel create hermes-marketing-growth
cloudflared tunnel list
```

Then write the tunnel config with the tunnel UUID:

```bash
sudo bash docs/marketing-growth-team/deploy/cloudflare-access-tunnel.sh \
  --domain example.com \
  --tunnel-name hermes-marketing-growth \
  --tunnel-id TUNNEL_UUID \
  --credentials-file /root/.cloudflared/TUNNEL_UUID.json \
  --write-config
```

Create Cloudflare DNS routes:

```bash
sudo bash docs/marketing-growth-team/deploy/cloudflare-access-tunnel.sh \
  --domain example.com \
  --tunnel-name hermes-marketing-growth \
  --route-dns
```

Install/start the tunnel service:

```bash
sudo bash docs/marketing-growth-team/deploy/cloudflare-access-tunnel.sh \
  --domain example.com \
  --install-service
```

In Cloudflare Zero Trust, create Access applications:

- Type: Self-hosted.
- Hostnames: `arnela.example.com`, `denis.example.com`, `arman.example.com`, `testing.example.com`.
- Policy action: Allow.
- Include: allowed emails, email domain, Google group, GitHub org, or another team rule.
- Require 2FA at the identity provider if possible.

Do not put `API_SERVER_KEY` into Cloudflare Access. That key belongs to the
Hermes API profile `.env`. Cloudflare Access protects the dashboard login path.

Hermes Desktop may not complete the Cloudflare Access browser login flow. If
Desktop cannot connect through Access, keep the SSH tunnel for Desktop and use
Cloudflare Access for browser dashboards.

## 11. Termius Port Forwarding Values

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

## 12. Local Alias Instead Of Typing The Tunnel Command

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
