# Event-getriebener Merge-Queue-Trigger

Status: draft

## Kontext
Die Merge-Queue-Automatisierung ([`merge-queue-automation`](../merge-queue-automation/de.md))
gleicht das Board ab und vergibt das `automerge`-Label über einen geplanten
(Cron-)Poll, weil auf einem persönlichen GitHub-Account die Geste „Karte nach
`Done` gezogen" kein natives Event hat. Alles *nach* dem Label ist bereits
eventgetrieben: Der Automerge-Workflow des Ziel-Repositories triggert auf
`pull_request`- / `label`-Events. Genau ein Hop ist also poll-basiert — „Board
`Status` = `Done` → `automerge`-Label" — und diese Spec katalogisiert die
Optionen, diesen einen Hop eventgetrieben zu machen, wägt ihre Trade-offs ab und
hält die empfohlene Richtung fest, damit eine künftige Umsetzung einen
sanktionierten Weg wählt, statt ihn neu herzuleiten.

Diese Spec ist ein Entscheidungs-Record und Options-Katalog. Sie ersetzt nicht die
poll-basierte Abgleichung; sie definiert, wie ein eventgetriebener Trigger
aussähe und wann er den Aufwand wert ist.

## Ziele
- Den Übergang „auslieferungsbereit → `automerge`-Label" eventgetrieben
  (nahezu Echtzeit) statt poll-basiert machen, wo der Aufwand gerechtfertigt ist
- Den Options-Satz explizit und entschieden halten, sodass eine Umsetzung einen
  sanktionierten Weg wählt, statt die Plattform-Grenzen neu zu verhandeln
- Das eine Board als Fläche des Maintainers in jedem Fall bewahren

## Nicht-Ziele
- Die poll-basierte Abgleichung, Board-Befüllung und der Archiv-Repo-Prune —
  gehören zu [`merge-queue-automation`](../merge-queue-automation/de.md)
- Was nach der Label-Vergabe geschieht — der gh-plumbing-Automerge-Workflow und
  die Specs `release-automation` / `branching-model`
- Die Views und Felder des Boards — [`portfolio-board`](../portfolio-board/de.md)
  und [`portfolio-views`](../portfolio-views/de.md)

## Anforderungen

### Plattform-Grenzen (die Fakten, auf denen die Entscheidung ruht)
- **MUSS** anerkennen, dass es auf **User-Account**-Projekten **keine**
  `projects_v2_item`-Webhooks gibt (das Event ist organisationsweit-only) und
  **keinen** `on: projects_v2_item`-GitHub-Actions-Trigger; das Verschieben eines
  Board-Items kann auf einem persönlichen Account also keinen Workflow nativ
  treiben
- **MUSS** anerkennen, dass alles nach dem `automerge`-Label bereits
  eventgetrieben ist, der Umfang dieser Spec also genau der eine Hop
  „Board `Done` → Label" ist

### Option A — Label als Trigger-Geste (empfohlen; ohne Org, ohne Infra)
- Die menschliche „ready"-Geste ist das **Anbringen eines Labels** am Pull Request
  (direkt das `automerge`-Label oder ein Zwischen-Label `ready` / `ship`, das ein
  Workflow in `automerge` übersetzt) statt eine Karte nach `Done` zu ziehen. Das
  `pull_request: [labeled]`-Event feuert **nativ** → eventgetrieben, null Polling
- Die `Done`-Spalte des Boards wird eine **nach diesem Label gefilterte View**,
  nicht der Auslöser; das Label ist die Source of Truth, das Board spiegelt es
- **Trade-off:** Ein Label anzubringen ist eine etwas weniger reiche Geste als
  Drag-and-drop; beide **DÜRFEN** gekoppelt werden (Board für Überblick, Label für
  den Trigger). Netto-Aufwand niedrig

### Option B — Org-Migration + GitHub App / Webhook-Receiver
- Die Projekte unter eine GitHub-**Organisation** ziehen, wo
  `projects_v2_item`-Webhooks feuern. Eine GitHub App oder ein Webhook-Receiver
  reagiert auf „item edited, `Status` → `Done`" und vergibt das Label nahezu in
  Echtzeit
- Seit Juni 2024 trägt das `projects_v2_item.edited`-Payload den vorherigen und
  aktuellen Feldwert, sodass „`Status` wurde zu `Done`" sauber erkennbar ist
- Dies ist der **einzige** Weg, die Board-Drag-Geste **und** eventgetrieben zu sein
- **Trade-off:** Org-Migration der Projekte plus ein laufender Receiver (GitHub
  App + Serverless-Endpunkt). Höchster Aufwand

### Option C — Externer Webhook-Receiver + `repository_dispatch` (braucht die Org aus B)
- Der Org-Webhook erreicht eine kleine Serverless-Function, die ein
  `repository_dispatch` ins Ziel-Repository re-emittiert, wo ein Workflow das
  Label vergibt oder den Release startet. Latenz im Sekundenbereich; hängt am
  Org-Modell aus Option B

### Auf einem persönlichen Account nicht praktikabel (festgehalten, um Neudiskussion zu vermeiden)
- User-Account-Projekt-Webhooks; ein Actions-Trigger für Projekt-Items;
  GraphQL-Subscriptions für Projektänderungen; eine GitHub App, die User-V2-Projekte
  erreicht

### Entscheidung
- **Option A** ist der empfohlene Weg, solange das Portfolio auf einem
  persönlichen Account bleibt: eventgetrieben, kein Polling, kein zusätzlicher
  Dienst — der einzige Aufwand ist der Wechsel der Trigger-Geste von Board-Drag zu
  Label
- **Option B / C** ist nur gerechtfertigt, **wenn** die Board-Drag-Geste der
  Auslöser bleiben muss, was das Org-Modell voraussetzt
- Bis eine eventgetriebene Option umgesetzt ist, bleibt der Cron-Poll aus
  [`merge-queue-automation`](../merge-queue-automation/de.md) der Fallback, mit
  seiner akzeptierten Latenz-Untergrenze von ~5 Minuten

## Akzeptanzkriterien
- [ ] Die Spec hält die Plattform-Grenze fest (keine User-Account-Projekt-Webhooks, kein Actions-Projekt-Item-Trigger) und dass alles nach dem Label bereits eventgetrieben ist
- [ ] Jede Option (A Label-Trigger, B Org + Webhook/App, C externer Receiver + `repository_dispatch`) ist mit Mechanismus, Latenz, Abhängigkeiten und Trade-offs dokumentiert
- [ ] Eine Empfehlung ist festgehalten: Option A für das Personal-Account-Modell; Option B/C nur, um die Drag-Geste zu behalten
- [ ] Wird Option A übernommen, feuert das Anbringen des Trigger-Labels einen nativen `pull_request: [labeled]`-Workflow, und die `Done`-Spalte des Boards ist eine label-gefilterte View mit dem Label als Source of Truth
- [ ] Die poll-basierte Abgleichung in [`merge-queue-automation`](../merge-queue-automation/de.md) ist als Fallback festgehalten, bis eine eventgetriebene Option ausgeliefert ist

## Offene Fragen
- Welches Trigger-Label für Option A — direkt `automerge` wiederverwenden, oder ein
  Zwischen-Label `ready` / `ship`, das ein Workflow in `automerge` übersetzt (sodass
  `automerge` rein maschinell gesetzt bleibt)?
- Ist die Latenz des Cron-Polls für ein Solo-Portfolio überhaupt ein Problem, oder
  ist eventgetrieben hier eine verfrühte Optimierung?
- Falls das Portfolio aus anderen Gründen je auf eine Organisation umzieht, wird
  Option B dann das Standard-Trigger-Modell?

## Referenzen
- `projects_v2_item`-Webhooks sind organisationsweit-only:
  <https://github.com/orgs/community/discussions/17405>;
  GitHub Docs, *Types of webhooks*
  (<https://docs.github.com/en/webhooks/types-of-webhooks>)
- Kein `on: projects_v2_item`-Actions-Trigger:
  <https://github.com/orgs/community/discussions/40848>;
  GitHub Docs, *Events that trigger workflows*
  (<https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows>)
- `pull_request: [labeled]`- und `label`-Events sind native Actions-Trigger:
  GitHub Docs, *Events that trigger workflows* (gleiche URL)
