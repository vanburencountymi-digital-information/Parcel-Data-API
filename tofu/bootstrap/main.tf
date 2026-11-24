# Creates what everything else depends on: the R2 state bucket and the R2 dump bucket
# with its scoped tokens. GCP resources (project, Cloud SQL, Secret Manager) are added in
# their own roots once the GCP project exists (migration checklist Phase 1).

resource "cloudflare_r2_bucket" "tfstate" {
  account_id = var.cloudflare_account_id
  name       = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

module "r2_dumps" {
  source = "../modules/r2_dumps"

  account_id  = var.cloudflare_account_id
  bucket_name = var.dump_bucket_name
}
