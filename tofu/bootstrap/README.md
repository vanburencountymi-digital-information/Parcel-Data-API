# bootstrap

Creates what every other root depends on, in Cloudflare R2:

- `parcel-data-api-tfstate`: OpenTofu state for this project.
- `parcel-data-api-dumps`: parcel database dumps and archives, with lifecycle rules, an object lock and two scoped tokens (`parcel-data-api-dump-write`, `parcel-data-api-dump-read`). Prefixes: `daily/` (30 days), `loads/` (12 months), `archive/` (kept until deleted by hand).

Template: `did-vaultwarden/tofu/bootstrap` (same account, same token pattern). GCP resources are not here yet; they come in their own roots once the GCP project exists (migration checklist, Phase 1).

## Cloudflare bootstrap token

One human-held token does the work. Create it right before a run, give it a 24-hour expiry, and delete it afterwards.

| Scope | Permission | Access |
|---|---|---|
| Account | API Tokens | Edit |
| Account | Workers R2 Storage | Edit |

No zone permission is needed here (no DNS in this root).

Set the start date to now.

Put it in `.env` (gitignored) as `CLOUDFLARE_API_TOKEN`, plus the R2 keys derived from it: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Load with `set -a; . ../../.env; set +a`.

## First apply

The state bucket does not exist yet, so the first run uses local state and then moves it. `tofu init -backend=false` does not work for this: `tofu plan` refuses to run while a `backend` block is configured but not initialized. Take the block out for the first run instead.

1. Comment out the whole `backend "s3" { ... }` block in `versions.tf` (leave `required_providers`).
2. `tofu init`, then `tofu plan` and read it. It should create two buckets, one lifecycle and one lock on the dump bucket, and two tokens, and nothing else.
3. `tofu apply`.
4. Uncomment the `backend` block, then `tofu init -migrate-state` (answer yes). This needs `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` set. State now lives in `s3://parcel-data-api-tfstate/bootstrap/`.
5. Delete the local `terraform.tfstate*` files. They are stale after the move and hold the token values in plain text.

Later runs: export the three variables above, `tofu init`, `tofu plan`.

## Credentials

`tofu output -json dump_write_credentials` and `dump_read_credentials` hold the S3 keys for the two tokens. They are also in state. Store them in Secret Manager (the new GCP project, once it exists) and do not print them into logs or commit them.

## Things to know

- R2 "Item Write" can also list, read and delete. The bucket lock, not the token scope, is what protects recent dumps. `daily/` is locked for 14 days, `loads/` and `archive/` for 30.
- The buckets have `prevent_destroy`. Destroying one is a deliberate, two-step act (remove the lifecycle block in a reviewed change, then apply).
- R2 has no object versioning, so a bad write or an account problem can lose state. Keep a copy of the state outside Cloudflare (for example in the new GCP project's storage) once it exists.
- The state bucket holds database credentials in plain text (the token outputs), so keep the bucket private and the bootstrap token short-lived.
