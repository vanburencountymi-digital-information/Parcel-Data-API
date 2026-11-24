# R2 dump credentials, moved here from tofu/bootstrap (migration checklist 1.1, DIC-3114).
# Values are read from the bootstrap state, so nobody copies them by hand or prints them.
# They end up in this root's state too (same private R2 bucket, same exposure as bootstrap).

data "terraform_remote_state" "bootstrap" {
  backend = "s3"

  config = {
    bucket = "parcel-data-api-tfstate"
    key    = "bootstrap/terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://b2a7b4d3a2d2a130919b11524e7564b2.r2.cloudflarestorage.com"
    }

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

locals {
  # Secret id => credentials object from bootstrap (sensitive).
  r2_dump_secrets = {
    "r2-dump-write-credentials" = data.terraform_remote_state.bootstrap.outputs.dump_write_credentials
    "r2-dump-read-credentials"  = data.terraform_remote_state.bootstrap.outputs.dump_read_credentials
  }
}

resource "google_secret_manager_secret" "r2_dump" {
  for_each = nonsensitive(toset(keys(local.r2_dump_secrets)))

  project   = google_project.this.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# JSON: {"access_key_id": "...", "secret_access_key": "..."}
resource "google_secret_manager_secret_version" "r2_dump" {
  for_each = google_secret_manager_secret.r2_dump

  secret      = each.value.id
  secret_data = jsonencode(local.r2_dump_secrets[each.key])
}
