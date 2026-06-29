# Unveröffentlichte Änderungen — Erkennen gemergter, aber nicht veröffentlichter Pull Requests

Status: draft

## Kontext
Zwischen zwei veröffentlichten Releases sammelt ein Repository Pull Requests an,
die bereits in die Entwicklungslinie gemergt sind, aber noch nicht an die Nutzer
ausgeliefert wurden. Dieses Portfolio entwirft Releases kontinuierlich —
`release-drafter` pflegt bei jedem Push auf `develop` ein *Draft*-GitHub-Release
(siehe [`portfolio-views`](../portfolio-views/de.md) §Release-Notes / Changelog) —
und veröffentlicht sie erst auf Anforderung über den `release-publish`-Workflow,
woraufhin `release-cd-refresh-master` `main` per Fast-Forward auf den
Release-Tag bringt. Die Lücke zwischen „gemergt" und „veröffentlicht" ist daher
ein reales, oft mehrtägiges Fenster, und nichts macht es heute sichtbar: Die
Board-View [`Release-Management`](../portfolio-views/de.md) zeigt, was
*auslieferungsbereit* ist, nicht, was *bereits ausgeliefert* wurde gegenüber dem,
was noch auf ein Release wartet.

Diese Spec regelt, wie der **unveröffentlichte** Status eines Pull Requests
bestimmt wird und wie die Menge der gemergten, aber unveröffentlichten Pull
Requests sichtbar gemacht wird — je Repository und aggregiert über `nolte/*`. Sie
bindet an das Audience- und Detailgrad-Modell in
[`view-design-principles`](../view-design-principles/de.md) (Maintainer —
Release-Management) und erweitert den Katalog
[`portfolio-views`](../portfolio-views/de.md) um eine `Unreleased`-View. Sie
definiert den **Erkennungs-Kontrakt und seine View**, nicht die Versionierungs-
oder Veröffentlichungsmechanik, auf der diese Releases laufen.

## Ziele
- Robust und je Pull Request bestimmen, ob ein gemergter Pull Request Teil eines
  veröffentlichten Releases ist oder noch auf eines wartet („unveröffentlicht")
- Die gemergt-aber-unveröffentlichte Menge je Repository und als Portfolio-Roll-up
  sichtbar machen, damit die Release-Entscheidung weiß, was auf Auslieferung wartet
- Die Bestimmung auf Daten stützen, die die Merge-Strategie des Repositories
  (Squash, Merge-Commit oder Rebase) und den develop→main-Release-Fluss überleben
- Die Oberflächen wiederverwenden, die dieses Portfolio bereits betreibt — das
  `release-drafter`-Draft-Release, die GitHub-Compare-API, Release-Tags — statt
  eine neue Quelle der Wahrheit einzuführen

## Nicht-Ziele
- Release-Versionierung, Tag-Erzeugung und Veröffentlichungsmechanik — gehören zu
  den Specs `release-automation` und `branching-model` sowie den bestehenden
  Workflows `release-drafter` / `release-publish` / `release-cd-*`
- Das wiederverwendbare Audience-, Detailgrad- und Form-Modell — gehört zu
  [`view-design-principles`](../view-design-principles/de.md)
- Die Felder des Boards und die `Done` → `automerge`-Übergabe — gehören zu
  [`portfolio-board`](../portfolio-board/de.md) und
  [`merge-queue-automation`](../merge-queue-automation/de.md); ein Pull Request ist
  *unveröffentlicht* strikt nachdem er gemergt wurde, was dieser Übergabe
  nachgelagert ist
- Bereitstellung von Tokens oder Repository-Variablen — gehört zu Terraform in
  `terraform-github-bootstrap` (`terraform/portfolio-ops/`)
- Mehrere unabhängige Versionslinien innerhalb eines Repositories
  (Komponenten-/Monorepo-Tags) — dieses Portfolio betreibt eine Versionslinie je
  Repository (siehe Offene Fragen)

## Anforderungen

### Definitionen
- Die **veröffentlichte Baseline** eines Repositories **MUSS** das jüngste
  *veröffentlichte* GitHub-Release sein — `draft: false` — und der Git-Tag, auf
  den es zeigt. Draft-Releases (einschließlich des kontinuierlich aktualisierten
  Drafts von `release-drafter`) **DÜRFEN NICHT** als Baseline zählen. Die
  Behandlung von Pre-Releases (`prerelease: true`) **MUSS** eine explizite,
  dokumentierte Richtlinienentscheidung sein, kein Zufall der Standard-Sortierung
  der API
- Die **Entwicklungsspitze** **MUSS** der Head der Entwicklungslinie des
  Repositories sein (`develop` im Branching-Modell dieses Portfolios), also dort,
  wo Merges landen
- Ein gemergter Pull Request ist genau dann **unveröffentlicht**, wenn sein
  Merge-Commit von der Entwicklungsspitze erreichbar ist **und nicht** vom
  veröffentlichten Baseline-Tag. Äquivalent: Er erscheint im Commit-Bereich
  `<veröffentlichter-Baseline-Tag>..<Entwicklungsspitze>` und nicht davor

### Erkennungsmethode
- Die Erkennung **MUSS** auf der `merge_commit_sha` des Pull Requests verankern
  (und dem Vorhandensein von `merged_at`), **nicht** auf den Commits des
  Head-Branches des Pull Requests. GitHub vermerkt einen Pull Request unter allen
  drei Merge-Strategien als gemergt und stempelt `merge_commit_sha`, aber Squash
  und Rebase **schreiben** die ursprünglichen Branch-SHAs **um**, sodass ein
  Abgleich über Head-Branch-Commits squash- und rebase-gemergte Pull Requests
  stillschweigend verfehlt. `merge_commit_sha` ist der eine Bezeichner, der
  unabhängig von der Strategie vom Base-Branch erreichbar ist
- Die Erreichbarkeit **MUSS** gegen die veröffentlichte Baseline berechnet werden,
  entweder durch:
  - die GitHub-Compare-API,
    `GET /repos/{owner}/{repo}/compare/{baseline_tag}...{entwicklungsspitze}`,
    deren zurückgegebene Commits genau die unveröffentlichten Commits sind; oder
  - git-native Erreichbarkeit des Merge-Commits in Release-Tags
    (`git tag --contains <merge_commit_sha>` / `git describe --contains`), wobei
    *kein veröffentlichter Release-Tag enthält ihn* als unveröffentlicht gilt
- Jeder unveröffentlichte Commit **MUSS** über den Endpunkt „List pull requests
  associated with a commit" (`GET /repos/{owner}/{repo}/commits/{sha}/pulls`) oder
  die GraphQL-Connection `Commit.associatedPullRequests` auf seinen
  ursprünglichen Pull Request abgebildet werden. Die deduplizierte Menge der
  zugeordneten, gemergten Pull Requests ist die gemergt-aber-unveröffentlichte
  Menge
- Die Erkennung **SOLLTE** das bestehende `release-drafter`-**Draft-Release** als
  ökonomische primäre Quelle bevorzugen: Dieser Draft listet bereits jeden seit
  dem letzten veröffentlichten Release gemergten Pull Request auf, kategorisiert
  nach Conventional-Commits-Label, und wird bei jedem Push auf `develop`
  aktualisiert. Wird der Draft verwendet, **MUSS** er als *per Definition
  unveröffentlicht* behandelt werden (ein Draft ist nicht veröffentlicht), und die
  obige Compare-/`associatedPullRequests`-Methode **MUSS** als maßgebliche
  Gegenprüfung verfügbar bleiben, wenn kein Draft existiert oder der Draft veraltet
  ist
- Die Erkennung **KANN** den schreibfreien Endpunkt
  `POST /repos/{owner}/{repo}/releases/generate-notes` (`previous_tag_name` =
  Baseline) verwenden, um dieselbe Pull-Request-Auflistung ohne Pflege eines
  Drafts zu erhalten

### Randfälle
- **Merge-Strategie** — die Bestimmung **MUSS** für Squash-Merge, Merge-Commit
  und Rebase-Merge identisch gelten, indem sie gemäß der obigen Erkennungsregel auf
  `merge_commit_sha` verankert
- **Commits ohne Pull Request** — direkt auf die Entwicklungslinie gepushte
  Commits (ohne zugeordneten Pull Request) **DÜRFEN** die Erkennung **NICHT**
  brechen: Sie erscheinen im unveröffentlichten Bereich, bilden aber auf eine leere
  Pull-Request-Menge ab, und die View **SOLLTE** solche unveröffentlichten
  Änderungen auf Commit-Ebene berücksichtigen, statt sie stillschweigend
  fallenzulassen
- **Umgeschriebene Historie** — Release-Tags **MÜSSEN** als unveränderliche
  Bezugspunkte behandelt werden; die Baseline **MUSS** auf den Commit des
  veröffentlichten Tags fixiert sein, damit ein Force-Push auf die
  Entwicklungslinie die Erreichbarkeit nicht falsch meldet
- **Zurückgerollte Merges** — ein Pull Request, der gemergt und vor dem nächsten
  Release wieder zurückgerollt wurde, wird von der Bereichsmethode weiterhin
  gemeldet (sowohl sein Merge als auch der Revert sind unveröffentlicht); die View
  **KANN** netto-wirkungslose Paare vermerken, **MUSS** sie aber nicht abgleichen
- **Kein vorheriges Release** — ein Repository ohne bislang veröffentlichtes
  Release **MUSS** jeden gemergten Pull Request auf der Entwicklungslinie als
  unveröffentlicht behandeln (die Baseline ist die leere/Wurzel-Referenz)

### View und Darstellung
- Der Katalog **MUSS** eine **Unreleased**-View bereitstellen. Audience:
  Maintainer — Release-Management (gemäß
  [`view-design-principles`](../view-design-principles/de.md)). Leitfrage: *Was
  ist seit dem letzten Release gemergt und wartet auf Auslieferung?* Primärer
  Detailgrad: Item-Ebene (eine Zeile je Pull Request), zusammenfassend zu einer
  aggregierten Zahl je Repository
- Die View **MUSS** je Pull Request mindestens Titel, Nummer, Autor, Merge-Datum
  und Conventional-Commits-Kategorie zeigen und **SOLLTE** die vom
  `release-drafter`-Version-Resolver vorhergesagte nächste Version sichtbar machen
- Die View **MUSS** ein **Portfolio-Roll-up** über `nolte/*` anbieten — mindestens
  die Anzahl unveröffentlichter Pull Requests je Repository und das Alter des
  ältesten unveröffentlichten Merges — damit ein Repository mit einem lange
  ausstehenden Release auf einen Blick sichtbar ist, im Sinne der
  Overview-First-Heuristik in
  [`view-design-principles`](../view-design-principles/de.md)
- Die View **MUSS** bereits veröffentlichte Pull Requests und in Arbeit
  befindliche (nicht gemergte) Arbeit ausschließen; sie ist das Gegenstück zur
  View [`Release-Management`](../portfolio-views/de.md) (auslieferungsbereit, vor
  dem Merge), getrennt durch die Merge-Grenze

### Implementierungs-Bindung
- Der Concern **MUSS** dem Ein-Concern-Modell des Repositories folgen: Seine Logik
  liegt in einem Skript unter `scripts/` (testbar, shellcheck-sauber), aufgerufen
  von einem dünnen Workflow unter `.github/workflows/`, gemäß `CLAUDE.md`
- Jedes Token oder jede Repository-Variable, die die Erkennung braucht, **MUSS**
  von Terraform (`terraform-github-bootstrap`) bereitgestellt werden, niemals von
  Hand; schreibfreie Release-, Tag- und Compare-Daten benötigen nur Standard-Lese-
  scope auf das Repository

## Abnahmekriterien
- [ ] Der unveröffentlichte Status eines Pull Requests ist definiert als: gemergt, von der Entwicklungsspitze erreichbar und nicht vom jüngsten *veröffentlichten* Release-Tag
- [ ] Die veröffentlichte Baseline schließt Draft-Releases (einschließlich des `release-drafter`-Drafts) aus und wendet eine explizite Pre-Release-Richtlinie an
- [ ] Die Erkennung verankert auf `merge_commit_sha`, sodass squash-, merge-commit- und rebase-gemergte Pull Requests alle erkannt werden
- [ ] Die unveröffentlichte Menge wird über die Compare-API (oder Git-Tag-Erreichbarkeit) berechnet und über den Associated-Pull-Requests-Endpunkt/die -Connection auf Pull Requests abgebildet
- [ ] Das `release-drafter`-Draft-Release ist als ökonomische primäre Quelle nutzbar, mit der Compare-/Associated-Pull-Requests-Methode als maßgeblicher Gegenprüfung
- [ ] Commits ohne zugeordneten Pull Request und Repositories ohne vorheriges Release werden behandelt, ohne die Erkennung zu brechen
- [ ] Eine **Unreleased**-View existiert für die Release-Management-Audience auf Item-Ebene, zeigt Detail je Pull Request und die vorhergesagte nächste Version
- [ ] Die View bietet ein Portfolio-Roll-up (Anzahl unveröffentlichter Pull Requests je Repository und Alter des ältesten unveröffentlichten Merges) und schließt veröffentlichte und nicht gemergte Arbeit aus
- [ ] Der Concern ist als `scripts/`-Skript plus dünner Workflow realisiert, mit Terraform-bereitgestellten Anmeldedaten

## Offene Fragen
- Soll ein veröffentlichtes **Pre-Release** (`prerelease: true`, z. B. ein
  Release-Kandidat) für diese View als „veröffentlicht" zählen, oder soll die
  Baseline immer das jüngste *vollständige* Release sein, sodass nur in einem RC
  ausgelieferte Änderungen weiterhin als unveröffentlicht gelten?
- Wird dem **`release-drafter`-Draft** als alleiniger Quelle der View vertraut,
  oder muss jeder Lauf ihn gegen das Compare-/Associated-Pull-Requests-Ergebnis
  abgleichen, um Drift zu erkennen (veralteter Draft-Body, manuelle Edits, falsche
  Kategoriezuordnung)?
- Welcher Schwellenwert macht aus einem „Alter des ältesten unveröffentlichten
  Merges" für das Portfolio-Roll-up ein handlungsleitendes Signal (eine Farbe, ein
  Alert) statt bloßer Information — und gehört das hierher oder in die Spec
  `release-automation`?
- Sollen unveröffentlichte Änderungen auf Commit-Ebene ohne Pull Request als
  erstklassige Zeilen in die View aufgenommen oder nur gezählt werden, da direkte
  Pushes auf `develop` vom Branching-Modell entmutigt werden?

## Referenzen
- GitHub REST, *Commits* — zwei Commits vergleichen
  (`GET /repos/{owner}/{repo}/compare/{basehead}`) und *List pull requests
  associated with a commit* (`GET /repos/{owner}/{repo}/commits/{commit_sha}/pulls`).
  <https://docs.github.com/en/rest/commits/commits>
- GitHub Docs, *About pull request merges* — Merge-Commit vs. Squash vs. Rebase
  und wie jede die Commit-SHAs umschreibt oder erhält.
  <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-pull-request-merges>
- GitHub Docs, *Automatically generated release notes* — die `generate-notes`-API
  und das `previous_tag_name`-Compare-Verhalten.
  <https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes>
- `release-drafter/release-drafter` — kontinuierlich gepflegtes Draft-Release der
  seit dem letzten veröffentlichten Release gemergten Pull Requests.
  <https://github.com/release-drafter/release-drafter>
- `int128/list-associated-pull-requests-action` — listet die einem Commit-Bereich
  zwischen zwei Refs zugeordneten Pull Requests; der kanonische Baustein für „was
  ist seit dem letzten Release gemergt".
  <https://github.com/int128/list-associated-pull-requests-action>
- `mikepenz/release-changelog-builder-action` — baut einen kategorisierten
  Changelog zwischen zwei Tags über zugeordnete Pull Requests.
  <https://github.com/mikepenz/release-changelog-builder-action>
- `Songmu/tagpr` — das „Release-Pull-Request"-Muster: ein offener Pull Request
  sammelt die unveröffentlichten Änderungen und wird beim Merge zu einem Tag.
  <https://github.com/Songmu/tagpr>
- Git-native Erreichbarkeit: `git tag --contains <sha>` / `git describe --contains`
  (<https://adamj.eu/tech/2024/04/22/git-show-first-containing-tag/>);
  `mhagger/git-when-merged` (<https://github.com/mhagger/git-when-merged>);
  *Finding changes since the last release*
  (<https://www.semicomplete.com/blog/geekery/finding-changes-since-last-release/>)
