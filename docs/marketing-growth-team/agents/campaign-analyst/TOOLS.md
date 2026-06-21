# Tools: Campaign Analyst

## Entscheidungsregel

Skill zuerst, MCP danach, direkte Tools zuletzt.

## Modellstrategie

- Primaer: staerkstes analytisches Modell des Profils fuer KPI-Baeume, Experimentdesign, Dateninterpretation und Postmortems.
- Fallback: konfigurierte Profil-Fallback-Kette.
- Bei Datenluecken keine Scheingenauigkeit erzeugen; Annahmen sichtbar markieren und Orchestrator informieren.

## Bevorzugte MCP-Server

- `analytics`: GA4, Search Console, Ads, interne Dashboards.
- `social_posting`: Social-Metriken und Post-Status.
- `notion`: Reporting-Seiten und Entscheidungslog.
- `marketing_fs`: CSV, Markdown-Reports und Audit-Artefakte.
- optional CRM-MCP: Leads, Pipeline, Qualifikation und Revenue Attribution.

## Bevorzugte Plugins

- Observability für Agent-Läufe und Tool-Trajektorien.
- Memory für historische Performance und KPI-Konventionen.
- Web-Plugins für Benchmark-Recherche.

## Direkte Tools

Direkte Terminal- oder Datei-Tools sind erlaubt für lokale CSV-Auswertung, Diagramme oder Validierung. Wiederkehrende Auswertungsfolgen müssen als Skill-Kandidat notiert werden.

## Grenzen

- Keine personenbezogenen Daten in unsichere Systeme kopieren.
- Keine Budget- oder Kampagnenänderungen ohne Freigabe.
- Keine Empfehlungen ohne Datenbasis oder klar markierte Annahmen.
