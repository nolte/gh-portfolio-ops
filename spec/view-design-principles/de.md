# Sicht-Design-Prinzipien — Zielgruppe, Detailgrad und Darstellungsform

Status: draft

## Kontext
Ein Software-Portfolio wird über viele Darstellungen sichtbar: ein Kanban-Board,
eine dichte Tabelle, eine Roadmap, Charts, Activity-Feeds, Release Notes, eine
Dokumentations-Website. Jede Darstellung bedient eine andere Zielgruppe mit einem
anderen Informationsbedarf und auf einem anderen Detailgrad. Ohne ein gemeinsames
Modell wachsen Sichten ad hoc: Detailgrade vermischen sich, eine Darstellung wird
aus Gewohnheit statt nach Eignung gewählt, und einer Zielgruppe wird das Rauschen
einer anderen gezeigt.

Diese Spec definiert das wiederverwendbare Design-Modell, auf dem jede konkrete
Sicht aufbaut: die Zielgruppen und ihren Informationsbedarf, eine
Detailgrad-Taxonomie, das Eignungsprofil jeder Darstellungsform und die
Heuristiken, die entscheiden, welchen Detailgrad und welche Form eine Sicht
nutzen muss. Sie ist in etablierter Literatur des Informationsdesigns fundiert
(siehe Referenzen) und ist die Grundlage, auf der der konkrete Sicht-Katalog
[`portfolio-views`](../portfolio-views/de.md) sowie jede zielgruppengerichtete
Dokumentation ruhen. Sie nutzt — und wiederholt nicht — die allgemeine
Audience-Identification-Methodik (Spec `audience-identification`).

## Ziele
- Jede Sicht deklariert, wen sie bedient, sodass die Zielgruppe ein expliziter
  Design-Input ist und kein nachträglicher Gedanke
- Eine einzige Detailgrad-Taxonomie (aggregiert / item-level / feld-level) wird
  über alle Darstellungen konsistent angewandt
- Form folgt Zweck: Jede Darstellungsform hat ein dokumentiertes Eignungsprofil,
  sodass die Darstellung einer Sicht nach Eignung statt Gewohnheit gewählt wird
- Ein kleiner Satz von Design-Heuristiken hält jede Sicht auf-einen-Blick-erfassbar,
  zielgruppenscharf und frei vom Rauschen der anderen Zielgruppen

## Nicht-Ziele
- Die konkreten benannten Sichten dieses Portfolios — gehört zu
  [`portfolio-views`](../portfolio-views/de.md)
- Board-Felder, Sync und die `Done` → `automerge`-Automatisierung — gehört zu
  [`portfolio-board`](../portfolio-board/de.md) und
  [`merge-queue-automation`](../merge-queue-automation/de.md)
- Die allgemeine Methodik zur Identifikation von Zielgruppen — gehört zur Spec
  `audience-identification`; diese Spec wendet sie auf die Sicht-Design-Domäne an

## Anforderungen

### Zielgruppen-Modell
- **MUSS** die Zielgruppen definieren, die eine Sicht bedienen kann; jede
  Zielgruppe **MUSS** durch ihre Leitfrage, die für sie *signalhafte* Information
  und die Information charakterisiert sein, die *Rauschen* ist und daher
  ausgeschlossen wird
- **MUSS** mindestens diese Zielgruppen abdecken:
  - **Maintainer — operativ (tägliche Entwicklung):** „Woran arbeite ich, und was
    ist blockiert?" Signal: laufende Arbeit (WIP), blockierte Items, untriagierte
    neue Issues. Rauschen: Roadmap-Termine, ausgelieferte Releases,
    Portfolio-Aggregate
  - **Maintainer — Release-Management:** „Was ist auslieferungsbereit — Go oder
    No-Go?" Signal: auslieferungsbereite Pull Requests, offene Defekte,
    Check-Status und Trend. Rauschen: Backlog-Triage, einzelne laufende Arbeit,
    die Dependency-Queue
  - **Maintainer — Portfolio-Überblick / Steuerung:** „Wie steht das Portfolio
    insgesamt?" Signal: aggregierte Zahlen, Trends und Gesundheit über
    Repositories. Rauschen: Einzel-Item-Detail
  - **Reviewer von Dependency-Updates:** „Welche Updates sind sicher, welche
    brauchen Sorgfalt?" Signal: Dependency-Pull-Requests gruppiert nach Update-Typ
    und Risiko, Changelogs, Breaking-Change-Markierungen. Rauschen:
    Feature-Backlog, Roadmap
  - **Externer Contributor:** „Was kann ich übernehmen, und wie ist der Status
    meines Pull Requests?" Signal: nicht zugewiesene `good first issue` /
    `help wanted`-Issues, Projektaktivität und Reaktionsfreude, der Status des
    eigenen Pull Requests. Rauschen: interne Priorisierung, die Release-Pipeline,
    die Dependency-Queue
  - **Endnutzer / Stakeholder:** „Was ist geplant, und was wurde ausgeliefert?"
    Signal: Roadmap-Themen auf grobem Horizont, Release Notes. Rauschen: laufende
    Arbeit, Triage, interne Metriken
- **MUSS** den Solo-Maintainer als Träger mehrerer dieser Rollen zugleich
  behandeln: Dieselbe Person braucht je Rolle eine anders gefilterte Sicht, weil
  das, was in einer Rolle Signal ist, in einer anderen Rauschen ist

### Detailgrad-Taxonomie
- **MUSS** jede Sicht nach genau einem *primären* Detailgrad klassifizieren:
  - **aggregiert** — Zahlen, Verteilungen und Trends über viele Items (KPI-Ebene)
  - **item-level** — eine Karte oder Zeile pro Issue oder Pull Request
    (Arbeitseinheit-Ebene)
  - **feld-level** — viele Metadatenfelder pro Item gleichzeitig sichtbar
    (Attribut-Ebene)
- Eine Sicht **DARF** eine tiefere Ebene auf Anforderung erreichbar machen, aber
  ihr *primärer* Grad ist der, den sie zuerst zeigt und nach dem sie klassifiziert
  wird

### Design-Prinzipien (jede Sicht MUSS sie erfüllen)
- **Zweck bestimmt Dichte:** Die Leitfrage der Sicht wird zuerst festgelegt; der
  Detailgrad folgt aus ihr (ein Ziel-Überblick ist aggregiert/strategisch, eine
  Live-Arbeitssicht fokussiert/operativ, eine Ursachen-Sicht dicht/analytisch).
  Der Detailgrad ist keine freie Wahl — er wird aus dem Zweck abgeleitet
  (Drei-Dashboard-Typologie, Few / Eckerson)
- **Überblick zuerst, Details auf Anforderung:** Eine Sicht startet auf der
  höchsten sinnvollen Aggregation und macht tiefere Ebenen über Zoom, Filter und
  Drill-down erreichbar — nie, indem sie alle Ebenen zugleich zeigt (Shneidermans
  Information-Seeking-Mantra)
- **Progressive Disclosure, höchstens zwei Ebenen:** Die primäre Fläche zeigt das
  häufig Benötigte, eine sekundäre hält das Seltene; mehr als zwei
  Aufdeckungsebenen desorientieren, also gehört tiefere Analyse in eine eigene,
  dedizierte Sicht statt in einen dritten Drill-down (Nielsen Norman Group)
- **Signal versus Rauschen je Zielgruppe:** Eine Sicht **MUSS** die Information
  ausschließen, die für ihre Zielgruppe Rauschen ist; Filtern ist ein bewusstes
  Weglassen, das die Verständlichkeit erhöht, kein Verlust (Shneiderman)
- **Auf einen Blick für Top-Level-Sichten:** Strategische und operative Überblicke
  **MÜSSEN** mit minimaler Interaktion und kognitiver Last erfassbar sein und
  wenige präattentiv kodierte Signale (etwa fünf bis neun) der Informationsmenge
  vorziehen (Nielsen Norman Group)

### Eignungsprofil der Darstellungsformen
- **MUSS** ein Eignungsprofil pflegen, das jede Darstellungsform ihrem Zweck,
  ihrem typischen Detailgrad, ihrer Zielgruppen-Eignung und ihren Grenzen
  zuordnet. Mindestens:

  | Form | Primärer Detailgrad | Leitfrage | Zielgruppen-Eignung | Hauptgrenze |
  |---|---|---|---|---|
  | Kanban-Board | item-level (Status) | Was ist in Arbeit / blockiert? | Maintainer, operativ | Schwach bei Feldvergleich und Zeit; braucht WIP-Disziplin |
  | Tabelle | feld-level (dicht) | Vergleichen, filtern, bulk-handeln | Maintainer, Planung/Triage | Keine Flow-/Zeit-Semantik; Dichte braucht sauberes Design |
  | Roadmap / Timeline | aggregiert (Zeit) | Wann kommt was? | Stakeholder; eigene Quartalsplanung | Braucht gepflegte Datums-/Iterations-Felder; rigide gegen Umpriorisierung |
  | Charts / Insights | aggregiert (KPI) | Wie steht es insgesamt? | Steuerung/Überblick; teilbar | Historie braucht Team/Enterprise; nativ nur Burn-up |
  | Listen / Feeds | item-level (chronologisch) | Was ist zuletzt passiert? | Mitlesende Person | Keine Aggregation/Priorität; Firehose bei Menge |
  | Release Notes / Changelog | aggregiert (Bedeutung) | Was wurde ausgeliefert? | Externe Nutzer / Entwickler | Dokumentiert nur Ausgeliefertes, keine Pläne |

- Eine Sicht **MUSS** eine Form wählen, deren Eignung zu ihrer Zielgruppe und
  ihrem primären Detailgrad passt. Eine Fehlpaarung — dichte Feld-Daten auf ein
  Board gezwungen oder tägliche Aufgabensteuerung auf eine Roadmap geschoben — ist
  Drift und **MUSS** markiert werden

## Akzeptanzkriterien
- [ ] Ein Zielgruppen-Modell zählt die obigen Personas auf, jede mit Leitfrage, Signal und ausgeschlossenem Rauschen
- [ ] Eine Detailgrad-Taxonomie (aggregiert / item-level / feld-level) ist definiert, und jede Sicht klassifiziert in genau einen primären Grad
- [ ] Die Design-Prinzipien (Zweck→Dichte, Überblick-zuerst, Progressive Disclosure mit höchstens zwei Ebenen, Signal-vs-Rauschen, Auf-einen-Blick) sind formuliert und für jede Sicht verpflichtend
- [ ] Ein Eignungsprofil der Darstellungsformen ordnet jede Form Zweck, Detailgrad, Zielgruppen-Eignung und Grenzen zu
- [ ] Eine Sicht, die eine zu ihrer Zielgruppe oder ihrem primären Detailgrad unpassende Form nutzt, wird als Drift erkannt
- [ ] Das Modell zitiert seine Quellen (Shneiderman; Nielsen Norman Group zu Progressive Disclosure und Dashboards; die Drei-Dashboard-Typologie nach Few / Eckerson)

## Offene Fragen
- Soll das Zielgruppen-Modell pro Repository über die
  `audience-identification`-Methodik abgeleitet werden, oder genügt ein
  Portfolio-weites Modell für die Sicht-Design-Domäne?
- Wo die Plattform eine von einem Prinzip vorausgesetzte Fähigkeit nicht bietet
  (zum Beispiel WIP-Limits auf einem Board oder native Burn-down-Charts): Soll die
  Spec die Lücke als akzeptierte Einschränkung festhalten oder einen Workaround
  vorschreiben?

## Referenzen
- Ben Shneiderman, *The Eyes Have It: A Task by Data Type Taxonomy for
  Information Visualizations* (1996) — „Overview first, zoom and filter, then
  details-on-demand". <https://www.cs.umd.edu/~ben/papers/Shneiderman1996eyes.pdf>
  (Wortlaut bestätigt über <https://infovis-wiki.net/wiki/Visual_Information-Seeking_Mantra>)
- Nielsen Norman Group, *Progressive Disclosure*.
  <https://www.nngroup.com/articles/progressive-disclosure/>
- Nielsen Norman Group, *Dashboards: Making Charts and Graphs Easier to
  Understand*. <https://www.nngroup.com/articles/dashboards-preattentive/>
- Die Drei-Dashboard-Typologie (strategisch / operativ / analytisch), nach
  Stephen Few und Wayne Eckerson.
  <https://www.idashboards.com/operational-analytical-and-strategic-the-three-types-of-dashboards/>
- GitHub Docs, *Changing the layout of a view* (Board / Table / Roadmap).
  <https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/changing-the-layout-of-a-view>
