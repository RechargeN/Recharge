# Env, Flavors, And Secrets Policy

This document defines how environments, build flavors, and secrets are managed.

## 1) Environments And Flavors

Supported runtime environments:

- `dev`
- `stage`
- `prod`

Required build flavors must map 1:1 to environments:

- `dev` flavor -> `dev` environment
- `stage` flavor -> `stage` environment
- `prod` flavor -> `prod` environment

## 2) Configuration Matrix (Minimum)

| Key | Type | Required In | Secret | Example |
|---|---|---|---|---|
| `APP_ENV` | string | all | no | `dev` |
| `API_BASE_URL` | string | all | no | `https://api.dev.example.com` |
| `SENTRY_DSN` | string | dev/stage/prod | yes | `<redacted>` |
| `ANALYTICS_API_KEY` | string | dev/stage/prod | yes | `<redacted>` |
| `MAPS_API_KEY` | string | dev/stage/prod | yes | `<redacted>` |
| `FEATURE_FLAGS_SOURCE` | string | all | no | `remote` |

## 3) Secret Storage Rules

- Secrets are stored only in secret managers or CI protected secrets.
- Local development secrets are stored in untracked local files or OS keychain.
- Secrets must never be hardcoded in source files, tests, scripts, or docs.
- Production secrets are never shared in chat, PR comments, or issue descriptions.

## 4) Never Commit To Git

- `.env`, `.env.*`, `*.env`
- API keys, tokens, private keys, service account credentials
- signing material and keystore passwords
- local override config files containing credentials

## 5) Access Control

- Principle of least privilege.
- Separate credentials per environment.
- Production credentials restricted to approved maintainers/CI contexts.

## 6) Rotation Policy

- Rotate high-risk secrets every 90 days or immediately after personnel change.
- Rotate immediately on suspected leak.
- Rotation must include: revoke old -> issue new -> deploy -> verify -> remove fallback.

Detailed runbook: [secrets-rotation.md](../runbooks/secrets-rotation.md)

## 7) Secret Leak Response

On suspected leak:

1. Contain and revoke immediately.
2. Rotate affected credentials.
3. Audit accesses and deployment logs.
4. Notify stakeholders and document impact.
5. Create remediation tasks and post-incident summary.

Detailed runbook: [secret-leak-response.md](../runbooks/secret-leak-response.md)
