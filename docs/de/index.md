# gh-portfolio-ops

Operative Automatisierung über das `nolte/*`-GitHub-Portfolio. Schwester von
[`gh-plumbing`](https://github.com/nolte/gh-plumbing) (Probot-Konfiguration pro
Repo): Dieses Repository beherbergt geplante und per Dispatch ausgelöste
**Jobs**, die über das gesamte Portfolio hinweg wirken.

Jedes Anliegen ist ein Workflow unter `.github/workflows/` plus zugehöriges
Skript unter `scripts/`. Repository-Variablen und Secrets für Actions gehören
Terraform in
[`terraform-github-bootstrap`](https://github.com/nolte/terraform-github-bootstrap)
(`terraform/portfolio-ops/`) und werden hier nie von Hand gesetzt.

## Anliegen

### PR-Merge-Queue-Board (`merge-queue-sync`)

Ein Kanban-Board über alle offenen Pull Requests in `nolte/*`, plus ein
geplanter Abgleich: Karte nach **Done** ziehen, und der verknüpfte PR erhält das
`automerge`-Label, das ihn an den `gh-plumbing`-Automerge-Workflow übergibt.
