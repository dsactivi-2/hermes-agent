# Workflows: Memory Review / Reflektor

## Weekly Memory Review

1. Scope klaeren: Profil, Kampagne, Zeitraum oder gesamtes Team.
2. Passende Skills und MCP-Server pruefen.
3. `REVIEW_QUEUE.md`, `TEAM_LEARNINGS.md`, `SKILL_BACKLOG.md` und relevante Agent-Memory-Dateien lesen.
4. Items nach Stabilitaet, Allgemeingueltigkeit, Faktenbasis, Sensibilitaet und Konflikten bewerten.
5. Entscheidungen vorbereiten: approve, reject, needs-source, conflicting, superseded.
6. Promotions und Markierungen als konkrete Patch-/Edit-Vorschlaege formulieren.
7. Wiederholte Muster in Skill-Builder-Briefs ueberfuehren.
8. Review-Report an Orchestrator uebergeben.

## Skill Builder Workflow

1. Skill-Kandidat aus `SKILL_BACKLOG.md` auswaehlen.
2. Wiederholungsnachweis pruefen: Aufgaben, Profile, Fehler oder Outputs.
3. Skill-Brief erstellen:
   - Skill-Name
   - Ziel
   - Trigger
   - benoetigte Inputs
   - Schrittfolge
   - genutzte Skills/MCPs/Tools
   - Output-Format
   - Tests oder Akzeptanzkriterien
   - Risiken und Grenzen
4. Skill-Entwurf durch Orchestrator freigeben lassen.
5. Nach Nutzung des Skills Review-Ergebnis und Verbesserungen dokumentieren.

## Memory Conflict Review

1. Konfliktquelle identifizieren: Datei, Claim, Datum, Quelle, Agent.
2. Quellenqualitaet und Aktualitaet bewerten.
3. Entscheidungsvorschlag formulieren: keep, supersede, split by scope, needs-source.
4. Alte Memory sichtbar markieren.
5. Konfliktentscheidung in `DECISIONS.md` oder `REVIEW_QUEUE.md` dokumentieren.

## Observability Review

1. Verfuegbare Logs, Traces oder Reports identifizieren.
2. Wiederholte Fehler, lange Tool-Ketten, haeufige Korrekturen und Skill-Gaps extrahieren.
3. Nur stabile Muster in Team Learnings oder Skill Backlog uebernehmen.
4. Unsichere Interpretationen als Review-Queue-Item markieren.

