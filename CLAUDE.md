# CLAUDE.md

AI-assisted development conventions for `gh-portfolio-ops`.

## What this repository is

Operational automation over the `nolte/*` GitHub portfolio. Sibling to
[`gh-plumbing`](https://github.com/nolte/gh-plumbing) (per-repo Probot config):
this repo hosts scheduled / dispatch **jobs** that act across the whole
portfolio. Each concern is one workflow under `.github/workflows/` plus its
script under `scripts/`.

## Architecture

- **One concern = one workflow + one script.** A workflow under
  `.github/workflows/<concern>.yml` invokes `scripts/<concern>.sh`. Keep logic
  in the script (testable, shellcheck-clean); keep the workflow thin (triggers,
  permissions, env wiring).
- **Secrets and variables are Terraform-owned.** Repo-level Actions variables
  and secrets are managed by
  [`terraform-github-bootstrap`](https://github.com/nolte/terraform-github-bootstrap)
  (`terraform/portfolio-ops/`), never set by hand here.
- **Repository settings are code.** `.github/settings.yml` (Probot Settings app)
  is the source of truth — never edit settings through the GitHub UI.

## Command entry points

All reproducible commands run through the Taskfile:

| Command | Purpose |
|---|---|
| `task setup` | Install pre-commit hooks and docs dependencies |
| `task lint`  | Run pre-commit across all files (shellcheck, shfmt, actionlint, …) |
| `task test`  | Validate the scripts under `scripts/` |
| `task docs`  | Build the MkDocs site |
| `task check` | Aggregate quality gate (lint + test) |

## Adding a concern

1. Add `.github/workflows/<concern>.yml` + `scripts/<concern>.sh`.
2. If it needs a variable/secret, add it in `terraform-github-bootstrap`
   (`terraform/portfolio-ops/`), never inline here.
3. Document the concern in `README.md` and `docs/`.
