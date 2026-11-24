# cloud-sql

Private-only Cloud SQL Postgres 17 for parcel data (migration checklist 1.2, DIC-3115). State: `s3://parcel-data-api-tfstate/cloud-sql/`.

Contains the VPC (no auto subnets), the private services access range and peering, and the instance: no public IP, `ENCRYPTED_ONLY`, no authorized networks, backups with point-in-time recovery, deletion protection. Zonal; smallest sensible tier.

## Run

Same as `../gcp-project`: ADC login, `set -a; . ../../.env; set +a`, then `tofu init`, `plan`, `apply`.

## Things to know

- **The instance is created stopped** (`activation_policy = "NEVER"`) to save the CPU/memory cost until the data copy (Phase 2). **Set `activation_policy = "ALWAYS"` and apply before checklist 1.3** (extensions) and 1.4 (roles), or connections will fail.
- Cloud SQL rejects creating an instance that is already stopped (`invalidOperation`). A fresh create needs `-var activation_policy=ALWAYS` first, then a second apply with the default (`NEVER`) to stop it.
- Resize `tier` after checklist 2.1 measures `geo` + `assessing`. Switch `availability_type` to `REGIONAL` when production consumers depend on the API.
- Connect by instance connection name (output), not the private IP, which changes if the instance is replaced.
- Anything here is defined in OpenTofu; no console-created resources.
