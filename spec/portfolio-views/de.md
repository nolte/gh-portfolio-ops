# Portfolio-Sichten — Zielgruppenorientierter Sicht-Katalog

Status: draft

## Kontext
Diese Spec ist die konkrete Instanziierung von
[`view-design-principles`](../view-design-principles/de.md) für das
`nolte/*`-Portfolio. Sie bindet die Zielgruppen und Design-Heuristiken an
spezifische, benannte Sichten über das Portfolio-Board (siehe
[`portfolio-board`](../portfolio-board/de.md)) und die GitHub-nativen Oberflächen
(Projects-Views, Insights, Releases, Milestones, Labels, Docs-Site). Jede Sicht
deklariert, wen sie bedient, welche Frage sie beantwortet, ihren Detailgrad, ihre
Darstellungsform, die GitHub-Oberfläche, auf der sie lebt, ihren Filter bzw. ihre
Konfiguration und die Information, die sie bewusst als Rauschen ausschließt. Der
Katalog ist die Grundlage, auf die nachgelagerte Automatisierungen zielen — welche
Sicht ein gespiegeltes Feld speist, was eine generierte Roadmap zeigt, wo die
`Done` → `automerge`-Übergabe sichtbar wird.

## Ziele
- Ein einziger Überblick gibt dem Maintainer eine direkte Sicht auf offene Issues
  und Pull Requests über alle `nolte/*`-Repositories, aufgeteilt in
  zweckgebundene Sichten
- Jede Zielgruppe erreicht eine auf ihren Informationsbedarf abgestimmte Sicht,
  im richtigen Detailgrad und in einer passenden Darstellungsform, ohne das
  Rauschen einer anderen Zielgruppe
- Die internen Arbeitsflächen und die externen Kommunikationsflächen bleiben
  konsistent, wobei die externen eine kuratierte Projektion des internen Zustands
  sind
- Der Katalog ist stabil genug, dass Automatisierungen auf benannte Sichten
  zielen können, ohne ihre Form neu herzuleiten

## Nicht-Ziele
- Das wiederverwendbare Zielgruppen-, Detailgrad- und Form-Modell — gehört zu
  [`view-design-principles`](../view-design-principles/de.md)
- Board-Felder, repo-übergreifender Sync und die
  `Done` → `automerge`-Automatisierung — gehört zu
  [`portfolio-board`](../portfolio-board/de.md) und
  [`merge-queue-automation`](../merge-queue-automation/de.md)
- Release-Versionierung und Publikationsmechanik — gehört zu den Specs
  `release-automation` und `branching-model`
- Die interne Form der Planungs-Artefakte unter `project/`

## Anforderungen

### Deklarations-Kontrakt einer Sicht
- Jede Sicht im Katalog **MUSS** deklarieren: ihre **Zielgruppe**, ihre
  **Leitfrage**, ihren **primären Detailgrad** (gemäß der Taxonomie in
  [`view-design-principles`](../view-design-principles/de.md)), ihre
  **Darstellungsform**, die **GitHub-Oberfläche**, auf der sie lebt, ihren
  **Filter bzw. ihre Konfiguration** und das **ausgeschlossene Rauschen**
- Jede Sicht **MUSS** den Design-Prinzipien aus
  [`view-design-principles`](../view-design-principles/de.md) entsprechen: Ihre
  Form **MUSS** zu Zielgruppe und Detailgrad passen, und sie **MUSS** die
  Information ausschließen, die für ihre Zielgruppe Rauschen ist

### Sicht-Katalog
Das Portfolio **MUSS** mindestens die folgenden Sichten bereitstellen. Die Spalte
Oberfläche benennt, wo die Sicht lebt; mehrere Sichten sind gespeicherte Views auf
dem einen Projects-V2-Board, andere sind eigene GitHub-Oberflächen.

- **Open pull requests by repository (Tabelle)** — Zielgruppe: Maintainer
  (operativ). Frage: Welche offenen Pull Requests gibt es im Portfolio, nach
  Projekt organisiert? Detailgrad: item-level (bewusst *nicht* feld-level). Form:
  Tabelle. Oberfläche: die Default-Tabellen-View des Projects-V2-Boards (zum
  Beispiel „View 1"). Konfiguration: **gruppiert nach dem Feld `Repository`**; die
  sichtbaren Spalten sind auf einen **minimalen Satz — `Repository`, `Title`,
  `Status`** — begrenzt, alle anderen Felder ausgeblendet; `Repository` ist ein
  eigenes, erstklassiges Feld, sichtbar gehalten und sowohl zum Gruppieren als
  auch zum Sortieren genutzt. Schließt aus: die dichten Metadaten-Spalten
  (Assignees, Labels, Reviewer, Daten, Milestone) standardmäßig — sie bleiben auf
  Anforderung verfügbar. Dies ist die kanonische tabellarische Master-Sicht des
  Boards. Hinweis: Gemergte und geschlossene Pull Requests werden von dieser und
  jeder Board-Sicht durch den Projects-Built-in-Workflow *Auto-archive items*
  ferngehalten (siehe [`merge-queue-automation`](../merge-queue-automation/de.md)
  §Board-Hygiene), sodass die Sicht nur aktive Arbeit zeigt
- **Daily development** — Zielgruppe: Maintainer (operativ). Frage: Was ist in
  Arbeit und was ist blockiert? Detailgrad: item-level. Form: Kanban-Board.
  Oberfläche: Projects-V2-Board-View gruppiert nach `Status`. Filter: offene Items
  unter Ausschluss von Dependency-Updates (`-label:dependencies`). **SOLLTE**
  blockierte Items sichtbar markieren. Schließt aus: Roadmap-Termine,
  ausgelieferte Releases, Portfolio-Aggregate. Hinweis: GitHub Projects hat kein
  natives WIP-Limit pro Spalte; das Fehlen ist eine akzeptierte Einschränkung
- **Triage** — Zielgruppe: Maintainer (operativ). Frage: Was ist neu und noch
  nicht eingeordnet? Detailgrad: item-level. Form: Tabelle oder eigene
  Board-Spalte. Oberfläche: Projects-V2-View. Filter: kürzlich hinzugefügte Items
  ohne gesetzten `Status` (oder ohne Triage-Marker). Schließt aus: alles bereits
  Triagierte
- **Release management** — Zielgruppe: Maintainer (Release). Frage: Was ist
  auslieferungsbereit — Go oder No-Go? Detailgrad: item-level, zum Aggregierten
  verdichtend. Form: Tabelle oder Board, gefiltert auf auslieferungsbereite Pull
  Requests. Oberfläche: Projects-V2-View. Filter: `is:pr is:open` mit `Status` =
  der `Done`-Option. Dies ist die Sicht, von der aus die
  [`merge-queue-automation`](../merge-queue-automation/de.md)-Übergabe
  `Done` → `automerge` getrieben wird. Schließt aus: Backlog-Triage, einzelne
  laufende Arbeit, die Dependency-Queue
- **Dependency updates** — Zielgruppe: Reviewer von Dependency-Updates. Frage:
  Welche Updates sind sicher und welche brauchen Sorgfalt? Detailgrad: item-level,
  gruppiert. Form: Tabelle gruppiert nach Update-Typ und Risiko. Oberfläche:
  Projects-V2-View. Filter: `label:dependencies` (oder das gespiegelte Feld
  `Class` = `dependency` gemäß [`portfolio-board`](../portfolio-board/de.md)).
  **SOLLTE** nach Major / Minor / Patch gruppieren, damit Hochrisiko-Updates
  hervortreten. Schließt aus: Feature-Arbeit, Roadmap
- **Portfolio health** — Zielgruppe: Maintainer (Portfolio / Steuerung). Frage:
  Wie steht das Portfolio insgesamt? Detailgrad: aggregiert. Form: Charts.
  Oberfläche: Projects-V2-Insights (Burn-up, Zahlen pro Repository). Schließt aus:
  Einzel-Item-Detail. Hinweis: Historical-Charts erfordern GitHub
  Team/Enterprise, und nativ existiert nur ein Burn-up-Chart — dort festhalten, wo
  die Sicht konfiguriert wird
- **Roadmap** — Zielgruppe: Endnutzer / Stakeholder (und die eigene
  Quartalsplanung des Maintainers). Frage: Was ist geplant und was kommt als
  Nächstes? Detailgrad: aggregiert über Zeit. Form: Roadmap / Timeline.
  Oberfläche: Projects-V2-Roadmap-Layout oder eine veröffentlichte Roadmap.
  Konfiguration: outcome-formulierte Themen auf grobem Horizont (eine
  Now / Next / Later-Struktur oder Quartals-Buckets). Die Sicht **DARF NICHT**
  standardmäßig harte Datums-Zusagen darstellen, um nicht jedes Datum zu einem
  Versprechen zu machen. Schließt aus: laufende Arbeit, Triage, interne Metriken
- **Contributor entry** — Zielgruppe: externer Contributor. Frage: Was kann ich
  übernehmen? Detailgrad: item-level, kuratiert. Form: gefilterte Issue-Liste.
  Oberfläche: die Labels `good first issue` / `help wanted` des Repositories und
  die GitHub-`/contribute`-Seite. Schließt aus: interne Priorisierung, die
  Release-Pipeline, die Dependency-Queue
- **Release notes / changelog** — Zielgruppe: Endnutzer (Notes) und Entwickler
  (Changelog). Frage: Was wurde ausgeliefert? Detailgrad: aggregiert auf der Ebene
  der Bedeutung. Form: kuratierte Release Notes, geschichtet über einen
  vollständigen Changelog. Oberfläche: GitHub Releases mit
  Release-Drafter-Kategorien, abgeleitet aus Conventional-Commits-Labels (siehe
  `branching-model` und `release-automation`). Schließt aus: geplante oder
  laufende Arbeit

### Tabellen-Konventionen
- Eine Tabellen-View **MUSS** auf einen minimalen Spaltensatz defaulten und **DARF
  NICHT** den vollständigen Feld-Katalog zeigen; Identität plus Zustand ist der
  Default (`Repository`, `Title`, `Status`), jedes weitere Feld ist opt-in und
  respektiert das Progressive-Disclosure-Limit aus
  [`view-design-principles`](../view-design-principles/de.md)
- Wo eine Tabelle über Repositories spannt, **MUSS** sie `Repository` als eigenes,
  sichtbares Feld behalten und **SOLLTE** danach gruppieren; `Repository` **MUSS**
  als Sortierschlüssel verfügbar sein, damit der Maintainer die Tabelle nach
  Projekt ordnen kann

### Oberflächenübergreifende Konsistenz
- Die nach außen gerichteten Sichten (Roadmap, Release Notes) **MÜSSEN** eine
  kuratierte Projektion des internen Zustands (Board, Changelog) sein: dieselben
  Themen und Outcomes, im Detail reduziert — eine geschichtete Single Source, nicht
  zwei unabhängige Dokumente, die auseinanderdriften können
- Eine Sicht **DARF NICHT** Zielgruppen vermischen: Wo der Solo-Maintainer mehrere
  Rollen trägt, bekommt jede Rolle ihre eigene gefilterte Sicht statt einer
  vermengten Fläche

## Akzeptanzkriterien
- [ ] Ein benannter Sicht-Katalog existiert; jeder Eintrag deklariert Zielgruppe, Leitfrage, primären Detailgrad, Darstellungsform, GitHub-Oberfläche, Filter/Konfiguration und ausgeschlossenes Rauschen
- [ ] Die Tabelle **Open pull requests by repository** ist nach dem Feld `Repository` gruppiert, zeigt nur die minimalen Spalten `Repository`, `Title`, `Status` und behält `Repository` als eigenen Sortierschlüssel; alle anderen Felder sind standardmäßig ausgeblendet
- [ ] Gemergte und geschlossene Pull Requests werden durch den Projects-Built-in-Workflow *Auto-archive items* von den aktiven Board-Sichten ferngehalten
- [ ] Die Sicht **Daily development** ist item-level auf einem Board und schließt Dependency-Updates aus; die Sicht **Release management** hebt auslieferungsbereite Pull Requests hervor und ist die Fläche, von der aus `Done` → `automerge` getrieben wird
- [ ] Die Sicht **Dependency updates** ist nach Update-Typ/Risiko über den `dependencies`-Marker (oder das gespiegelte `Class`-Feld) gruppiert
- [ ] Die Sicht **Portfolio health** ist über Insights aggregiert; die Sicht **Roadmap** ist zeit-aggregiert und stellt standardmäßig keine harten Datums-Zusagen dar
- [ ] Die Sicht **Contributor entry** hebt nicht zugewiesene `good first issue` / `help wanted`-Issues hervor
- [ ] Die Sicht **Release notes / changelog** ist eine geschichtete kuratierte Projektion — Notes für Nutzer über einem vollständigen Changelog für Entwickler
- [ ] Jede Sicht entspricht [`view-design-principles`](../view-design-principles/de.md): eine zum deklarierten Detailgrad passende Form, mit ausgeschlossenem Rauschen der Zielgruppe

## Offene Fragen
- Welche Sichten werden als gespeicherte Projects-V2-Views auf dem einen Board
  realisiert und welche als eigene Oberflächen (Insights, Releases, Docs-Site)?
  Die gespeicherten Views des Boards können nicht über mehrere Projekte spannen,
  also würde eine künftige Aufteilung das Single Pane of Glass fragmentieren.
- Soll die Sicht **Roadmap** eine Now / Next / Later-Struktur oder datierte
  Quartals-Buckets nutzen? Die Wahl wägt Flexibilität gegen die Präzision ab, die
  Stakeholder erwarten könnten.
- Soll der **Triage**-Zustand eine eigene `Status`-Option oder ein separates
  Projektfeld sein, da das `Status`-Feld auch die Board-Spalten und die
  `Done` → `automerge`-Übergabe treibt?

## Referenzen
- Informationsbedarf der Personas: UXPin, *Dashboard Design Principles*
  (<https://www.uxpin.com/studio/blog/dashboard-design-principles/>); GitHub Docs,
  *Finding ways to contribute*
  (<https://docs.github.com/en/get-started/exploring-projects-on-github/finding-ways-to-contribute-to-open-source-on-github>);
  GitHub Docs, *Managing pull requests for dependency updates*
  (<https://docs.github.com/en/code-security/dependabot/working-with-dependabot/managing-pull-requests-for-dependency-updates>)
- GitHub-Oberflächen: *About insights for Projects*
  (<https://docs.github.com/en/issues/planning-and-tracking-with-projects/viewing-insights-from-your-project/about-insights-for-projects>);
  *Automatically generated release notes*
  (<https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes>);
  *Encouraging helpful contributions with labels*
  (<https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/encouraging-helpful-contributions-to-your-project-with-labels>)
- Roadmap- und Release-Kommunikation: ProdPad, *Now-Next-Later Roadmap*
  (<https://www.prodpad.com/glossary/now-next-later-roadmap/>); Featurebase,
  *Changelog vs. Release Notes*
  (<https://www.featurebase.app/blog/changelog-vs-release-notes>); Keep a Changelog
  (<https://keepachangelog.com/en/1.1.0/>)
