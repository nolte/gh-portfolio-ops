---
title: Konfiguration
audience: [operator]
content_mode: reference
track: developer-docs
last_updated: 2026-06-29
---

# Konfiguration

Die Merge-Queue-Automatisierung braucht wenige Eingaben. Die meisten werden als
Code in [`terraform-github-bootstrap`](https://github.com/nolte/terraform-github-bootstrap)
verwaltet; einige sind systembedingt manuell, weil GitHub dafür keine API oder
Terraform-Ressource anbietet.

## Per Terraform verwaltet (IaC)

Diese werden von `terraform-github-bootstrap` bereitgestellt und **dürfen nicht**
von Hand am Repository gesetzt werden:

| Konfiguration | Terraform-Ressource | Modul |
|---|---|---|
| `PROJECT_NUMBER` (Actions-**Variable**) | `github_actions_variable` | `terraform/portfolio-ops/merge-queue.tf` |
| `MERGE_QUEUE_TOKEN` (Actions-**Secret**) | `github_actions_secret` | `terraform/portfolio-ops/merge-queue.tf` |
| Repository (`description`, `visibility`, `has_*`) | `github_repository` | `terraform/repos` |
| `develop`-Branch-Protection-Ruleset (PR-Pflicht, `check`-Status-Check verlangt, linear history, Force-Pushes und Löschungen blocken) | `github_repository_ruleset` | `terraform/repos` |
| `PORTFOLIO_APP_ID` (Actions-**Variable**) | `github_actions_variable` (portfolio-app-Modul) | `terraform/portfolio-app` |
| `PORTFOLIO_APP_PRIVATE_KEY` (Actions-**Secret**) | `github_actions_secret` (portfolio-app-Modul) | `terraform/portfolio-app` |

Lokale, gitignored Werte:

- `terraform/portfolio-ops/terraform.tfvars` → `project_number = 1`
  (das Board unter `https://github.com/orgs/noltarium/projects/1`). Das Board liegt
  unter der **noltarium**-Organisation; die Workflows setzen `PROJECT_OWNER=noltarium`,
  während die Quell-Repositories unter `nolte/*` bleiben (`REPO_OWNER=nolte`). Derselbe
  klassische PAT funktioniert, weil `nolte` Org-Admin ist.
- `terraform/repos/terraform.tfvars` → der `gh-portfolio-ops`-Repository-Block
  (Visibility `public`, Default-Branch `develop`, das obige Ruleset).
- `terraform/portfolio-app/terraform.tfvars` → `gh-portfolio-ops` in
  `consumer_repositories` gelistet, damit es Variable und Secret der Portfolio-App
  erhält.

### Portfolio-GitHub-App-Credentials

`PORTFOLIO_APP_ID` und `PORTFOLIO_APP_PRIVATE_KEY` tragen die
`nolte-portfolio-app`-Credentials, mit denen die Workflows `automerge` und
`release-publish` einen kurzlebigen Installation-Token minten. Das
`terraform/portfolio-app`-Modul provisioniert sie auf jedes Repository in seiner
`consumer_repositories`-Liste; App-ID, Slug und Private Key selbst kommen aus
gopass (`internet/github.com/nolte/apps/nolte-portfolio-app/{appid,slug,private_key}`)
via `source scripts/portfolio-app-env.sh && task tf:apply:portfolio-app`.

!!! warning "App-Installation ist eine separate Voraussetzung"
    Das Provisionieren legt nur die Credentials ab. Das Minten des Tokens setzt
    zusätzlich voraus, dass die **GitHub App `nolte-portfolio-app` auf diesem
    Repository installiert** ist (Repo-Zugriff gewährt). Ohne Installation
    scheitern `automerge` und `release-publish` zur Laufzeit, selbst wenn Variable
    und Secret vorhanden sind. Prüfen unter
    *Settings → Installations → nolte-portfolio-app → Repository access*.

## Das PAT (von Hand gementet, dann an Terraform übergeben)

Das `MERGE_QUEUE_TOKEN`-Secret hält einen Personal Access Token. Terraform
speichert ihn, kann ihn aber nicht erzeugen:

- **Typ:** klassisches PAT — ein fein granulares PAT erreicht
  User-Account-Projects-V2 nicht.
- **Benötigte Scopes** — genau diese zwei Top-Level-Checkboxen anhaken unter
  *Settings → Developer settings → Personal access tokens → Tokens (classic)*:

  | Scope | Wofür der Sync ihn braucht |
  |---|---|
  | `repo` (voll) | Das `automerge`-Label an Pull Requests über jedes `nolte/*`-Repository — private eingeschlossen — vergeben via `POST /repos/{owner}/{repo}/issues/{n}/labels`, und die offenen Pull Requests zum Board-Abgleich lesen. |
  | `project` | Das User-Level-Projects-V2-Board lesen und schreiben: Items hinzufügen, den `Status` jedes Items lesen und Items aus archivierten Repositories löschen. Das Anhaken von `project` schließt `read:project` ein. |

  Keine weiteren Scopes nötig — `admin:*`, `workflow` oder `delete_repo` nicht
  vergeben.
- **Gementet** nur im GitHub-UI.
- **Gespeichert** in gopass:
  `gopass insert internet/github.com/nolte/tokens/gh-portfolio-ops/merge-queue-pat`.
- **Übergeben** an Terraform als `TF_VAR_merge_queue_token` via
  `source scripts/portfolio-ops-env.sh` (das auch `GITHUB_TOKEN` aus
  `gh auth token` exportiert), und landet als `MERGE_QUEUE_TOKEN`-Secret am
  Repository.

## Manuell / nur im UI (nicht als Code verwaltbar)

GitHub bietet dafür keine Terraform-Ressource oder API — das sind einmalige
UI-Schritte:

- **Projects-V2-Board anlegen** — `gh project create --owner noltarium --title "PR Merge Queue"` (der `integrations/github`-Provider hat keine Ressource für Projects-V2). Das Board ist org-owned; ein Org-Projekt kann trotzdem Pull Requests aus den persönlichen `nolte/*`-Repositories tracken.
- **Board-Views** — die Tabelle gruppiert nach `Repository` und das Kanban gruppiert nach `Status` werden im Board-UI konfiguriert.
- **Der Built-in-Workflow *Auto-archive items*** — im Board-UI aktiviert, damit gemergte und geschlossene Pull Requests automatisch vom Board fallen.

## Aktivierungs-Reihenfolge

1. PAT minten und in gopass ablegen (siehe oben).
2. In `terraform-github-bootstrap` `project_number = 1` (das noltarium-Board) in
   `terraform/portfolio-ops/terraform.tfvars` setzen (lokal, gitignored).
3. Das bestehende Repository vor dem ersten Apply in den Terraform-State
   adoptieren:
   `terraform -chdir=terraform/repos import 'github_repository.managed["gh-portfolio-ops"]' gh-portfolio-ops`
4. Repository + Ruleset anwenden, dann Variable + Secret aus portfolio-ops:
   `task tf:apply` und `source scripts/portfolio-ops-env.sh && task tf:apply:portfolio-ops`.
5. Im Board-UI den **Auto-archive items**-Workflow aktivieren.
6. Smoke-Test: `gh workflow run "Merge Queue Sync" --repo nolte/gh-portfolio-ops`.
   Danach übernimmt der `*/10`-Cron.

Der Kontrakt hinter jeder Eingabe ist unter `spec/` spezifiziert — siehe
`merge-queue-automation` (Token-Scopes, Board-Hygiene) und `portfolio-board`
(das Board-Modell).
