# Portfolio-Board — Einheitliche repo-übergreifende Sicht

Status: draft

## Kontext
Ein einzelner Maintainer betreibt viele Repositories unter einem persönlichen
GitHub-Account (`nolte/*`). Ohne einheitliche Sicht sind offene Issues und Pull
Requests über Dutzende Repositories verstreut, und es gibt keinen einzigen Ort,
an dem sichtbar wird, was Aufmerksamkeit braucht, was in Arbeit ist und was
auslieferungsbereit ist. Diese Spec definiert ein einzelnes GitHub-Projects-V2-Board,
das offene Issues und Pull Requests über das Portfolio hinweg aggregiert und sie
über zweckgebundene Views darstellt — eine für die tägliche Weiterentwicklung,
eine für das Release-Management — mit einer klaren, filterbaren Trennung zwischen
echten Anforderungen (Features, Fixes, Issues) und Abhängigkeits-Updates, die von
Renovate und Dependabot erzeugt werden.

GitHub Projects V2 ist das Fundament: Ein Projekt existiert auf User-Ebene, hält
Items aus mehreren Repositories und stellt sie als Table-, Board- oder
Roadmap-Layout über beliebig viele gespeicherte Views dar. Die Mechanik des
*Befüllens* des Boards und des *Reagierens* auf Board-Zustände regelt die
Schwester-Spec [`merge-queue-automation`](../merge-queue-automation/de.md); diese
Spec definiert ausschließlich Form, Felder und Views des Boards.

## Ziele
- Ein einheitliches Projects-V2-Board gibt dem Maintainer einen direkten
  Überblick über offene Issues und Pull Requests über alle `nolte/*`-Repositories
- Tägliche Entwicklungsarbeit und Release-Management haben je eine eigene
  gespeicherte View im selben Projekt, sodass Alltagsfläche und Auslieferungsfläche
  nicht ineinanderlaufen
- Echte Anforderungen sind durch einen einheitlichen, filterbaren Marker von
  Abhängigkeits-Updates getrennt, sodass der Maintainer sich auf jeweils eine
  Klasse konzentrieren kann
- Das Board-Modell ist ein stabiles Fundament, auf dem nachgelagerte
  Automatisierungen (repo-übergreifender Sync, `Done` → `automerge`) aufbauen,
  ohne die Struktur neu herzuleiten

## Nicht-Ziele
- Die Automatisierung, die das Board befüllt und auf die `Done`-Spalte reagiert —
  gehört zu [`merge-queue-automation`](../merge-queue-automation/de.md)
- Branching- und Release-Mechanik pro Repository — gehört zu den Specs
  `branching-model` und `release-automation`
- Projects-Features auf Organisations-Ebene (dieses Portfolio ist ein
  persönlicher Account)
- Die interne Form der Planungs-Artefakte unter `project/` — gehört zu den Specs
  `roadmap`, `sprint` und `feature`

## Anforderungen

### Projekt-Fundament
- **MUSS** ein einzelnes GitHub-Projects-V2-Projekt im Besitz des User-Accounts
  als einheitliches Portfolio-Board verwenden
- **MUSS** offene Issues und offene Pull Requests über die `nolte/*`-Repositories
  hinweg in diesem einen Projekt aggregieren
- **DARF NICHT** den eingebauten Auto-Add-Workflow als alleinigen
  Befüll-Mechanismus nutzen: In den Free- und Pro-Plänen ist die Zahl der
  Auto-Add-Workflows gedeckelt (Free erlaubt einen, also ein einziges
  Quell-Repository pro Projekt), was für ein Multi-Repository-Portfolio nicht
  reicht. Die repo-übergreifende Befüllung wird daher an die Sync-Automatisierung
  aus [`merge-queue-automation`](../merge-queue-automation/de.md) delegiert

### Status-Feld und Board-Layout
- **MUSS** ein Single-Select-Feld `Status` definieren, dessen Optionen mindestens
  `Todo`, `In Progress` und `Done` umfassen; die Spalten des Board-Layouts bilden
  dieses Feld ab, und das Ziehen einer Karte zwischen Spalten aktualisiert den
  `Status` des Items
- **MUSS** die Option `Done` als semantischen Auslöser für die Release-Übergabe
  behandeln; ihr Beschriftungstext ist konfigurierbar, **MUSS** aber deklariert
  und stabil gehalten werden, weil die Automatisierung ihn namentlich liest

### Trennung Anforderung vs. Abhängigkeit
- **MUSS** *Anforderungs*-Items (Features, Fixes, Dokumentation, Issues) von
  *Abhängigkeits-Update*-Pull-Requests unterscheiden, die von Renovate oder
  Dependabot geöffnet wurden
- **MUSS** das Label `dependencies` als kanonischen Marker für einen
  Abhängigkeits-Update-Pull-Request behandeln
- **MUSS** sicherstellen, dass der Marker portfolioweit einheitlich ist:
  Dependabot vergibt `dependencies` automatisch, Renovate hingegen nur, wenn
  konfiguriert; daher **MUSS** die Renovate-Konfiguration jedes Repositories ein
  `dependencies`-Label vergeben (über `labels`/`addLabels` des Portfolio-Presets,
  siehe das Renovate-Preset aus `project-structure`), damit die label-basierte
  Trennung zuverlässig ist
- **MUSS** die Bot-Autorschaft (`renovate[bot]`, `dependabot[bot]`) als
  Fallback-Signal zur Klassifizierung eines Pull Requests bereithalten, wenn das
  Label fehlt
- **MUSS**, wenn eine Board-Gruppierung nach Klasse benötigt wird, ein
  Single-Select-Projektfeld bereitstellen (zum Beispiel `Class` mit den Optionen
  `requirement` und `dependency`), das den Abhängigkeits-Marker auf das
  Projekt-Item spiegelt, weil Projects V2 ein Board nicht nach einem
  Repository-Label gruppieren kann; der Spiegel-Schreibvorgang erfolgt durch die
  Sync-Automatisierung

### Views
- **MUSS** eine View **Daily development** bereitstellen: Board-Layout, gruppiert
  nach `Status`, gefiltert auf offene Items und unter Ausschluss von
  Abhängigkeits-Updates (`-label:dependencies`, oder `Class` ≠ `dependency`, wo
  das Spiegelfeld genutzt wird)
- **MUSS** eine View **Release management** bereitstellen: gefiltert auf
  `is:pr is:open`, die Pull Requests im Zustand `Done` / auslieferungsbereit
  hervorhebt
- **SOLLTE** eine View **Dependency updates** bereitstellen, gefiltert auf
  `label:dependencies` (oder `Class` = `dependency`), damit das Abhängigkeits-Rauschen
  getrennt von der Feature-Arbeit triagiert wird
- **SOLLTE** ein Insights-Chart für eine aggregierte repo-übergreifende
  Gesundheits-Sicht nutzen (offen vs. geschlossen über Zeit, Items pro Repository)

### Filter-Semantik
- View-Filter **MÜSSEN** innerhalb der von Projects V2 unterstützten Semantik
  bleiben: Jeder Qualifier kann mit vorangestelltem `-` negiert werden; mehrere
  Werte desselben Feldes werden mit logischem OR verknüpft; es gibt **kein**
  logisches OR über verschiedene Felder hinweg. Views **DÜRFEN NICHT** unter der
  Annahme eines feldübergreifenden OR entworfen werden

## Akzeptanzkriterien
- [ ] Ein einzelnes Projects-V2-Projekt auf User-Ebene aggregiert offene Issues und Pull Requests über `nolte/*`-Repositories
- [ ] Ein Single-Select-Feld `Status` existiert mit `Todo`, `In Progress` und einer stabilen `Done`-Option
- [ ] Abhängigkeits-Update-Pull-Requests tragen einheitlich das Label `dependencies` (Dependabot-Default plus das Renovate-Preset, das es vergibt)
- [ ] Eine View **Daily development** schließt Abhängigkeits-Updates aus; eine View **Release management** hebt auslieferungsbereite Pull Requests hervor
- [ ] Wird die Board-Gruppierung nach Klasse genutzt, spiegelt ein Single-Select-Projektfeld die Anforderung/Abhängigkeit-Klasse auf jedes Item
- [ ] Jeder View-Filter stützt sich nur auf unterstützte Semantik (Negation und Same-Field-OR; kein feldübergreifendes OR)

## Offene Fragen
- Welcher Plan-Tarif genau gilt für den `nolte`-Account? Er entscheidet, ob das
  eingebaute Auto-Add überhaupt nutzbar ist und wie viele Quell-Repositories es
  abdecken könnte, bevor der API-basierte Sync zwingend wird.
- Ist mit wachsender Repository-Zahl ein gemeinsames Projekt weiterhin die
  richtige Einheit, oder sollten Anliegen über mehrere Projekte aufgeteilt werden?
  Native projektübergreifende Aggregation (eine Roadmap oder Abfrage über mehrere
  Projekte) wird nicht unterstützt, eine Aufteilung würde das Single Pane of Glass
  also fragmentieren.
