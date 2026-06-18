# Tools: Memory Review / Reflektor

## Entscheidungsregel

1. Skill suchen oder erstellen.
2. MCP-Server nutzen, wenn strukturierter Datei-, Dokument-, Log- oder Datenzugriff gebraucht wird.
3. Plugin nutzen, wenn Hermes bereits eine passende Memory-, Observability- oder Review-Extension bereitstellt.
4. Klassische Tools nur fuer lokale Datei-, Terminal- oder Restaufgaben nutzen.

## Bevorzugte MCP-Server

- `marketing_fs`: Memory-Dateien, Agent-Dokumente, Reports und Skill-Entwuerfe lesen/schreiben.
- `notion`: Entscheidungslogs, Freigaben, Content-Kalender und Review-Protokolle pflegen.
- `analytics`: Performance-Learnings pruefen, bevor sie promoted werden.
- `github`: Skill- oder Dokumentaenderungen als PR vorbereiten, falls im Repo gearbeitet wird.
- Observability-/Log-MCPs, wenn Langfuse, Traces oder Agent-Laufdaten verfuegbar sind.

## Bevorzugte Plugins

- Memory-Provider fuer Langzeitkontext und Cross-Session-Learnings.
- Observability-Plugin fuer Agent-Trajektorien, Tool-Nutzung und Fehlerhaeufungen.
- Web-/Research-Plugins nur zum Validieren von Quellen oder stale Claims.

## Direkte Tools

Direkte Datei- und Terminal-Tools sind erlaubt fuer lokale Audits, Diff-Pruefungen, Markdown-Reports und Script-Validierung. Jede wiederkehrende direkte Tool-Sequenz muss als Skill-Kandidat dokumentiert werden.

## Grenzen

- Keine automatischen Promotions von sensiblen, personenbezogenen oder unsicheren Items.
- Keine Secrets oder Rohdaten in Memory schreiben.
- Keine alten Memory-Eintraege still loeschen.
- Keine neuen Hermes-Core-Tools vorschlagen, wenn Skill, MCP, Plugin oder Script genuegt.

