# Merge-Queue-Automatisierung — `Done` → `automerge`

Status: draft

## Kontext
Das Portfolio-Board (siehe [`portfolio-board`](../portfolio-board/de.md)) erlaubt
dem Maintainer, eine Pull-Request-Karte in die `Done`-Spalte zu ziehen, um
„auslieferungsbereit" zu signalisieren. Auf einem persönlichen GitHub-Account
gibt es keine ereignisgetriebene Möglichkeit, auf das Verschieben eines
Projekt-Items zu reagieren: Das `projects_v2_item`-Webhook feuert nur für
organisationseigene Projekte, und GitHub Actions bietet keinen
`on: projects_v2_item`-Trigger. Ein geplanter Poller gleicht daher den
Board-Zustand in einem Intervall ab und vergibt für jeden Pull Request, dessen
Karte in `Done` liegt, das Label `automerge`. Dieses Label ist der
Übergabepunkt: Der Automerge-Workflow des Ziel-Repositories (aus
`nolte/gh-plumbing`) squash-merged den Pull Request, sobald die erforderlichen
Checks grün sind, und startet dort den Release-Prozess.

Diese Spec regelt den Kontrakt der Automatisierung — ihr Trigger-Modell, die
Authentifizierung, die Board-Befüllung, die `Done` → `automerge`-Regel sowie ihre
Beobachtbarkeits- und Sicherheitseigenschaften. Sie definiert **nicht** die Views
oder Felder des Boards (das ist [`portfolio-board`](../portfolio-board/de.md)) und
auch nicht, was `automerge` nachgelagert tut (das ist der
gh-plumbing-Automerge-Workflow und die Spec `release-automation`).

## Ziele
- „Pull-Request-Karte in `Done`" innerhalb der Grenzen eines persönlichen
  Accounts zuverlässig in das Label `automerge` am zugehörigen Pull Request
  übersetzen
- Das Board mit den offenen Pull Requests des Portfolios befüllt halten
- Ohne jeden ereignisgetriebenen Projekt-Trigger arbeiten, den es für
  User-Account-Projekte nicht gibt
- Idempotent, beobachtbar und sicher wiederholt in kurzem Intervall lauffähig sein

## Nicht-Ziele
- Das View-, Feld- und Gruppierungs-Modell des Boards — gehört zu
  [`portfolio-board`](../portfolio-board/de.md)
- Was nach der Vergabe von `automerge` geschieht — gehört zum
  gh-plumbing-Automerge-Workflow und den Specs `release-automation` /
  `branching-model`
- Bereitstellung des Tokens und der Repository-Variablen — gehört zu Terraform in
  `terraform-github-bootstrap` (`terraform/portfolio-ops/`)

## Anforderungen

### Trigger-Modell
- **MUSS** von einem geplanten (Cron-)GitHub-Actions-Workflow getrieben werden;
  sie **DARF NICHT** von `projects_v2_item`-Webhooks oder einem
  `on: projects_v2_item`-Trigger abhängen, die es beide für User-Account-Projekte
  nicht gibt
- **SOLLTE** ein Cron-Intervall nicht kürzer als die Plattform-Untergrenze von
  5 Minuten verwenden und **MUSS** die Board-Abgleichung als letztlich-konsistent
  behandeln: Geplante Läufe können unter Last verzögert und zu Spitzenzeiten
  verworfen werden, sodass die reale Latenz zwischen dem Ablegen einer Karte in
  `Done` und dem Erscheinen des Labels Minuten beträgt, nicht Echtzeit (ein
  `*/10`-Intervall ist ein vernünftiger Default)
- **MUSS** die Plattform-Regel berücksichtigen, dass in öffentlichen Repositories
  geplante Workflows nach 60 Tagen Repository-Inaktivität automatisch deaktiviert
  werden; das Repository **MUSS** eine Gegenmaßnahme tragen (zum Beispiel einen
  Keepalive-Dispatch oder externes Monitoring), damit der Poller nicht still
  stehenbleibt

### Authentifizierung
- **MUSS** sich mit einem klassischen Personal Access Token authentifizieren, das
  den `project`-Scope (Projektdaten lesen und schreiben) und den `repo`-Scope
  (Pull-Request-Labels bearbeiten) trägt
- **DARF NICHT** auf einem fein granularen Personal Access Token beruhen: dessen
  `project`-Berechtigung liegt unter dem Organizations-Tab, den persönliche
  Accounts nicht haben, sodass fein granulare Tokens persönliche Projekte nicht
  erreichen können
- **DARF NICHT** auf einem GitHub-App-Installations-Token zum Lesen des Projekts
  beruhen: Eine GitHub App kann User-Account-V2-Projekte nicht erreichen
- **MUSS** das Token aus einem von Terraform (`terraform-github-bootstrap`)
  bereitgestellten Repository-Secret lesen; das Token **DARF NICHT** eingecheckt
  werden

### Board-Befüllung
- **MUSS** jeden offenen `nolte/*`-Pull-Request idempotent zum Board hinzufügen —
  das erneute Hinzufügen eines bestehenden Items liefert das bestehende Item
  zurück und ist ein No-op
- **SOLLTE** die Anforderung/Abhängigkeit-Klasse auf das Single-Select-Projektfeld
  des Items spiegeln, wenn das Board eine Gruppierung nach Klasse nutzt (gemäß
  [`portfolio-board`](../portfolio-board/de.md))

### `Done` → `automerge`
- **MUSS** das `Status`-Feld jedes Items lesen und für jedes Item, dessen `Status`
  der konfigurierten `Done`-Option entspricht **und** dessen Pull Request noch
  offen ist, das Label `automerge` vergeben
- **MUSS** das Label über die GraphQL-Mutation `addLabelsToLabelable` setzen (oder
  einen äquivalenten `gh`-Aufruf), **niemals** über
  `updateProjectV2ItemFieldValue`, das nur Projektfelder ändern kann, nicht die
  Labels des zugrunde liegenden Issues oder Pull Requests
- **MUSS** idempotent sein: Die Vergabe von `automerge` an einen Pull Request, der
  es bereits trägt, ist ein No-op, und das Label wird höchstens einmal pro Pull
  Request vergeben
- **MUSS** jeden Pull Request — mit einer expliziten Log-Zeile — in einem
  Repository überspringen, in dem das Label `automerge` nicht existiert, statt den
  Lauf scheitern zu lassen
- **DARF NICHT** den Pull Request selbst mergen; die Vergabe von `automerge`
  übergibt an den Automerge-Workflow des Ziel-Repositories, der den Squash-Merge
  durchführt und damit den Release-Prozess startet

### Beobachtbarkeit und Sicherheit
- **MUSS** Aktionen pro Pull Request (hinzugefügt, gelabelt, übersprungen) und
  eine Lauf-Zusammenfassung loggen
- **MUSS** die Projekt-Item-Abfrage paginieren, sodass Läufe mehr als 100
  Board-Items abdecken
- **MUSS** dokumentieren, dass Renovate die Labels eines Pull Requests nur
  synchron hält, bis ein anderer Account sie bearbeitet: Sobald diese
  Automatisierung `automerge` auf einem Renovate-Pull-Request setzt, stoppt
  Renovate weitere Label-Änderungen an diesem Pull Request — ein akzeptierter,
  aber bewusster Nebeneffekt

## Akzeptanzkriterien
- [ ] Ein geplanter Workflow (Cron-Intervall ≥ 5 Minuten) gleicht das Board ab; die Automatisierung beruht auf keinem Projekt-Webhook oder Projekt-Event-Trigger
- [ ] Die Authentifizierung nutzt ein klassisches PAT mit `project`- und `repo`-Scopes, aus einem von Terraform bereitgestellten Repository-Secret, niemals eingecheckt
- [ ] Jeder offene `nolte/*`-Pull-Request wird idempotent zum Board hinzugefügt
- [ ] Pull Requests, deren `Status` der konfigurierten `Done`-Option entspricht und die noch offen sind, erhalten das Label `automerge` über `addLabelsToLabelable`
- [ ] Das Labeling ist idempotent und überspringt Repositories ohne das `automerge`-Label mit einer Log-Zeile
- [ ] Die Automatisierung merged Pull Requests nie direkt; Merge und Release werden an den Automerge-Workflow des Ziel-Repositories delegiert
- [ ] Die Projekt-Item-Abfrage ist paginiert, um mehr als 100 Items abzudecken, und jeder Lauf loggt eine Zusammenfassung
- [ ] Das Repository trägt eine Gegenmaßnahme für die 60-Tage-Deaktivierung geplanter Workflows in öffentlichen Repositories

## Offene Fragen
- Welche maximale Latenz zwischen dem Markieren einer Karte als `Done` und dem
  Erscheinen des `automerge`-Labels ist gewünscht? Sie bestimmt das
  Cron-Intervall und ob Polling allein akzeptabel ist.
- Soll die eingebaute Board-Automatisierung den `Status` beim Mergen eines Pull
  Requests zusätzlich auf `Done` setzen, sodass die Spalte den gemergten Zustand
  ohne manuelles Verschieben widerspiegelt, oder bleibt `Done` strikt ein
  menschliches „auslieferungsbereit"-Signal vor dem Merge?
