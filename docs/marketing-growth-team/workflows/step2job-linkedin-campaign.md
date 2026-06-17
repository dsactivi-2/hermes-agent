# Beispiel-Workflow: LinkedIn-Kampagne für Step2Job

## Ausgangslage

Step2Job möchte über LinkedIn mehr qualifizierte Leads für ein Job-Coaching- oder Weiterbildungsangebot gewinnen. Zielgruppe sind Arbeitssuchende, Quereinsteiger und Menschen, die in den nächsten 30 Tagen konkrete Bewerbungsergebnisse brauchen.

## Orchestrator-Ablauf

1. Briefing normalisieren: Ziel, Zielgruppe, Angebot, Budget, Zeitrahmen, Freigabeprozess und Erfolgskriterien erfassen.
2. Skill-Prüfung: vorhandene Skills für LinkedIn-Kampagnen, Brand Voice, Persona-Recherche, Post-Serien, Creative-Briefing und Reporting suchen.
3. Skill-Erstellung: Falls kein belastbarer LinkedIn-Campaign-Brief-Skill existiert, erstellt der Orchestrator `marketing-growth/linkedin-campaign-brief`.
4. Delegation:
   - Content Writer: Narrative, Hook-Varianten, Post-Serie, CTA.
   - Social Media Specialist: Kalender, Posting-Frequenz, Community-Management.
   - SEO & Web: Landingpage-Checks, Tracking, Suchintention, FAQ.
   - Creative / Design: Visual-Konzept, Bildprompts, Carousel-Struktur.
   - Campaign Analyst: KPI-Plan, UTM-Konvention, Dashboard und Experimentdesign.
5. Synthese: Orchestrator führt Outputs zu einem Kampagnenplan zusammen.
6. Review: Agents prüfen, welche Skills wiederverwendbar sind und speichern Learnings im Memory.

## Beispiel-Prompt

```text
Plane eine 14-tägige LinkedIn-Kampagne für Step2Job.
Ziel: 80 qualifizierte Leads für ein Bewerbungstraining.
Zielgruppe: deutschsprachige Arbeitssuchende und Quereinsteiger zwischen 25 und 45.
Ton: direkt, empathisch, lösungsorientiert.
Assets: Website step2job.de, vorhandene Kundenstimmen, kein großes Video-Budget.
Bitte nutze autonome Skills, MCP und Subagents. Erstelle neue Skills, wenn du wiederkehrbare Kampagnenschritte erkennst.
```

## Erwartete Agent-Ausgaben

- Kampagnenbrief mit Zielgruppe, Angebot, Positionierung, Risiken und Metriken.
- 10 LinkedIn-Post-Ideen, davon 5 ausgearbeitete Posts.
- 3 Carousel-Konzepte mit Bildprompts und Slide-Struktur.
- Landingpage-Checkliste für Conversion, SEO und Tracking.
- UTM- und KPI-Plan mit wöchentlichem Reporting.
- Skill-Backlog: mindestens `linkedin-campaign-brief`, `step2job-brand-voice`, `linkedin-carousel-production`, falls noch nicht vorhanden.

## Skill-Lifecycle

Nach der Kampagne bewertet der Orchestrator:

- Welche Prompts, Checklisten oder Toolsequenzen wurden mehrfach genutzt?
- Welche Qualitätskriterien führten zu besseren Ergebnissen?
- Welche Fehler oder Freigabeschleifen traten auf?
- Welche Skills sollen neu erstellt, verbessert oder archiviert werden?

