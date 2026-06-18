# Memory: Deep Research

## Kurzfristiges Memory

Pro Research-Task haelt der Agent fest:

- Forschungsfrage und Entscheidungskontext
- Scope: Markt, Region, Zeitraum, Zielgruppe
- Quellenplan und Suchstrategie
- gefundene Kernquellen
- Widersprueche, Unsicherheiten und offene Fragen
- geplante Uebergabe an andere Agents

## Langfristiges Memory

Persistiere nur stabile, wiederverwendbare Erkenntnisse:

- Markt- und Wettbewerbslandschaften
- Zielgruppen-Personas, Jobs-to-be-done, Einwaende und Trigger
- wiederkehrende Quellen mit Qualitaetseinschaetzung
- Branchentrends und Signalstaerke
- erfolgreiche Research-Methoden und Skill-Learnings
- bekannte Datenluecken oder unzuverlaessige Quellen

## Nutzung

Vor jedem Research-Task pruefst du vorhandenes Memory auf Markt-, Persona-, Wettbewerbs- und Kampagnenwissen. Nach Abschluss speicherst du verdichtete Learnings, nicht komplette Rohdaten. Wenn neue Quellen altes Memory widersprechen, markierst du den Konflikt und gibst eine Aktualitaetseinschaetzung.

## Curated Memory System

Vor komplexen Aufgaben pruefst du `memory/shared/BRAND.md`, `memory/shared/AUDIENCES.md`, `memory/shared/OFFERS.md`, `memory/shared/COMPLIANCE.md`, `memory/shared/CAMPAIGNS.md`, `memory/shared/SOURCES.md`, `memory/agents/deep-research.md`, `memory/protocols/MEMORY_POLICY.md` und `memory/protocols/SELF_LEARNING_LOOP.md`.

Nach komplexen oder wiederkehrenden Aufgaben speicherst du stabile Research-, Quellen-, Wettbewerbs-, Persona- und Trend-Learnings in `memory/agents/deep-research.md`. Teamweite oder unsichere Learnings schlaegst du in `memory/orchestrator/REVIEW_QUEUE.md` vor. Wiederholbare Research- und Quellenbewertungsablaeufe kommen als Skill-Kandidat in `memory/orchestrator/SKILL_BACKLOG.md`.
