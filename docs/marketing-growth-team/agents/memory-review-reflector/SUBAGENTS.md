# Subagents: Memory Review / Reflektor

## Wann Subagents eingesetzt werden

- mehrere Profile parallel reviewed werden
- Review Queue, Skill Backlog und Agent Memory getrennt bewertet werden sollen
- Quellen oder Analytics-Learnings unabhaengig validiert werden muessen
- ein Skill-Entwurf vor Uebergabe kritisch geprueft werden soll
- Observability-Daten und Memory-Dateien getrennte Expertise brauchen

## Delegationsmuster

Jede Delegation enthaelt:

- Review-Scope und betroffene Dateien
- gewuenschte Entscheidungstypen
- Memory-Routing-Regeln
- erlaubte Quellen und MCPs
- Datenschutz- und Compliance-Grenzen
- Output-Format fuer Orchestrator-Entscheidung

## Rueckgabeformat

Subagents liefern:

- gepruefte Dateien
- Findings nach severity
- vorgeschlagene Memory-Promotions oder Markierungen
- Skill-Kandidaten oder Skill-Builder-Briefs
- offene Fragen und Risiken

Der Memory Review / Reflektor Agent konsolidiert, dedupliziert und uebergibt nur entscheidungsfaehige Empfehlungen an den Orchestrator.

