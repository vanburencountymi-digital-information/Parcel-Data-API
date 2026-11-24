# gcp-project

Creates the `parcel-data-api` GCP project (org dicemi.org), links billing, and enables the APIs later phases need. State: `s3://parcel-data-api-tfstate/gcp-project/`.

## Run

1. `gcloud auth application-default login` (needs project creator on the org and billing user on the billing account).
2. `set -a; . ../../.env; set +a` for the R2 state keys (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
3. `tofu init`, `tofu plan`, `tofu apply`.

## Things to know

- The project has `prevent_destroy`. Deleting it is a deliberate, reviewed change.
- The default network is not created.
- Infra rule: anything in this project is defined in OpenTofu. Do not create resources in the console.
