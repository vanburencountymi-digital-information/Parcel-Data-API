# cloud-sql-grants

SQL grants on the restored `geo` and `assessing` schemas (DIC-3161, follow-up to checklist 2.2). State: `s3://parcel-data-api-tfstate/cloud-sql-grants/`.

`martin_ro` and `steward_app` get read-only access: `USAGE` on both schemas, `SELECT` on every table and view, `EXECUTE` on the functions, plus default privileges so tables `postgres` creates later follow the same rule. Nothing for `walter`, `parcel_studio_app` or `bsa_featureserv_ro` (not recreated).

This is a separate root from `../cloud-sql` on purpose: the `postgresql` provider connects to the database, so plan and apply need the database open. Keeping it apart means `../cloud-sql` still plans cleanly while the instance is stopped.

## Run (database must be open)

1. In `../cloud-sql`: `tofu apply -var public_ip_enabled=true -var activation_policy=ALWAYS`.
2. Start the proxy: `cloud-sql-proxy parcel-data-api:us-central1:parcel-data-api-pg --port 5433`.
3. Here, with the R2 token loaded (`set -a; . ../../.env; set +a`):
   `PGPASSWORD="$(gcloud secrets versions access latest --secret cloud-sql-postgres-password --project parcel-data-api)" tofu plan` (then `apply`).
4. Close the database as described in `../cloud-sql/README.md`.

The password comes from the environment only; it is not in the code or in state.
