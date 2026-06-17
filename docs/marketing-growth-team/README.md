# Hermes Marketing & Growth Team

Dieses Blueprint startet klein: ein zentraler Marketing & Growth Orchestrator koordiniert fünf spezialisierte Hermes-Agenten. Das Design nutzt Hermes-Stärken bewusst am Rand: autonome Skills, Memory, MCP-Server, Plugins und Subagents. Der Core bleibt unverändert.

## Struktur

```text
docs/marketing-growth-team/
├── agents/
│   ├── orchestrator/
│   ├── content-writer/
│   ├── social-media-specialist/
│   ├── seo-web/
│   ├── creative-design/
│   └── campaign-analyst/
├── config/
│   ├── config.yaml
│   └── .env.example
├── workflows/
│   └── step2job-linkedin-campaign.md
└── setup.sh
```

Jeder Agent-Ordner enthält:

- `ROLE.md`: Rolle, Verantwortlichkeiten, Ziele und Metriken
- `SYSTEM.md`: System Prompt mit Prioritäten, Skill-/MCP-/Tool-Strategie
- `SKILLS.md`: vorhandene und autonom zu erstellende Skills
- `TOOLS.md`: erlaubte Werkzeuge, MCP-Server und Eskalationsregeln
- `MEMORY.md`: Kurz- und Langzeitmemory für Marke, Kampagnen und Learnings
- `WORKFLOWS.md`: typische Workflows und konkrete Arbeitsbeispiele
- `SUBAGENTS.md`: Regeln für Delegation und Subagents

## Setup

```bash
cd docs/marketing-growth-team
cp config/.env.example ~/.hermes/.env
cp config/config.yaml ~/.hermes/config.yaml
./setup.sh
```

Danach API Keys in `~/.hermes/.env` ergänzen und die gewünschte Provider-/Plugin-Auswahl mit `hermes setup`, `hermes plugins`, `hermes mcp` und `hermes skills` prüfen.

## Start

Orchestrator im CLI starten:

```bash
hermes chat --profile marketing-growth --skills hermes-agent -q "Du bist der Marketing & Growth Orchestrator. Lade docs/marketing-growth-team/agents/orchestrator/SYSTEM.md als Arbeitsanweisung und plane eine LinkedIn-Kampagne für Step2Job."
```

Web Dashboard starten:

```bash
hermes dashboard --profile marketing-growth
```

Spezialagenten direkt testen:

```bash
hermes chat --profile marketing-growth -q "Lade docs/marketing-growth-team/agents/content-writer/SYSTEM.md und schreibe 5 LinkedIn-Hooks für Step2Job."
hermes chat --profile marketing-growth -q "Lade docs/marketing-growth-team/agents/social-media-specialist/SYSTEM.md und plane einen 14-Tage-LinkedIn-Kalender für Step2Job."
hermes chat --profile marketing-growth -q "Lade docs/marketing-growth-team/agents/seo-web/SYSTEM.md und erstelle eine Landingpage-Prelaunch-Checkliste."
hermes chat --profile marketing-growth -q "Lade docs/marketing-growth-team/agents/creative-design/SYSTEM.md und erstelle ein Carousel-Creative-Briefing."
hermes chat --profile marketing-growth -q "Lade docs/marketing-growth-team/agents/campaign-analyst/SYSTEM.md und erstelle einen KPI- und UTM-Plan."
```

## Extensions in der Web UI aktivieren

Starte `hermes dashboard --profile marketing-growth` und öffne danach:

1. `Settings` öffnen und Provider/API Keys prüfen.
2. `Plugins` öffnen und Browser, Image Generation, Memory, Web Search und Observability aktivieren.
3. `MCP` öffnen und konfigurierte Server testen.
4. Neue Chat-Session mit dem Orchestrator starten.

CLI-Äquivalente für reproduzierbares Setup:

```bash
hermes plugins list
hermes plugins enable image_gen/fal
hermes plugins enable browser/firecrawl
hermes plugins enable web/exa
hermes plugins enable memory/honcho
hermes plugins enable observability/langfuse
hermes mcp test marketing_fs
hermes mcp test browser
hermes mcp test notion
```

## Empfohlene Plugins und MCP-Server

Plugins:

- `plugins/image_gen/fal`: Flux-ähnliche Bildgenerierung über FAL.
- `plugins/image_gen/openai`: schnelle Asset- und Mockup-Generierung.
- `plugins/browser/browser_use` oder `plugins/browser/firecrawl`: Browser-Automation und Website-Extraktion.
- `plugins/web/exa` oder `plugins/web/tavily`: Recherche, SERP- und Quellenarbeit.
- `plugins/memory/honcho`, `plugins/memory/mem0` oder `plugins/memory/supermemory`: persistente Kampagnen- und Brand-Memory.
- `plugins/observability/langfuse`: Traces und Auswertung komplexer Agent-Läufe.

MCP-Server:

- `filesystem`: Zugriff auf Kampagnenordner, Brand Assets und Reports.
- `browser` oder `chrome-devtools`: echte Website-/Dashboard-Interaktion.
- `notion`: Content-Kalender, Briefings und Freigaben.
- `google-drive` oder `docs`: Dokumente, Präsentationen und Asset-Ablage.
- `github`: Website- und Landingpage-Änderungen als PR.
- `analytics`: GA4, Search Console, Ads oder internes BI über einen kleinen firmeneigenen MCP-Adapter.
- `social-posting`: LinkedIn, X, Buffer, Hootsuite oder Make/Zapier über einen stark gefilterten MCP-Adapter.

## Grundregel für jeden Agenten

Vor einem direkten Tool-Aufruf prüft der Agent:

1. Gibt es eine passende Hermes Skill?
2. Kann oder soll eine neue Hermes Skill erstellt bzw. verbessert werden?
3. Gibt es einen MCP-Server, der die Aufgabe sauberer, sicherer oder strukturierter löst?
4. Erst danach werden klassische Tools genutzt.

Nach komplexen oder wiederkehrenden Aufgaben dokumentiert der Agent, ob ein neuer Skill sinnvoll ist, und erzeugt bei klarer Wiederverwendbarkeit einen Skill-Entwurf.
