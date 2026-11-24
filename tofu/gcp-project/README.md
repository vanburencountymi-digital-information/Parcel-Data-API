# gcp-project

Creates the `parcel-data-api` GCP project (org dicemi.org), links billing, enables the APIs later phases need, sets the project owners, and holds the R2 dump credentials in Secret Manager. State: `s3://parcel-data-api-tfstate/gcp-project/`.

## Run

1. `gcloud auth application-default login` (needs project creator on the org and billing user on the billing account).
2. `set -a; . ../../.env; set +a` for the R2 state keys (the token needs Object Read & Write on `parcel-data-api-tfstate`; `secrets.tf` also reads the `bootstrap/` state) (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
3. `tofu init`, `tofu plan`, `tofu apply`.

## Things to know

- The project has `prevent_destroy`. Deleting it is a deliberate, reviewed change.
- The default network is not created.
- Infra rule: anything in this project is defined in OpenTofu. Do not create resources in the console.
- Owners are `var.owners`, added with additive `google_project_iam_member` bindings. Add the owners group there when it exists.
- `secrets.tf` copies `dump_write_credentials` and `dump_read_credentials` from the bootstrap state into Secret Manager (`r2-dump-write-credentials`, `r2-dump-read-credentials`, JSON `{access_key_id, secret_access_key}`). The values are also in this root's state.
