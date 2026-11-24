terraform {
  required_version = ">= 1.8"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.25"
    }
  }

  # State lives in the R2 bucket created by ../bootstrap. Credentials come from
  # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (see ../bootstrap/README.md).
  backend "s3" {
    bucket = "parcel-data-api-tfstate"
    key    = "cloud-sql-grants/terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://b2a7b4d3a2d2a130919b11524e7564b2.r2.cloudflarestorage.com"
    }

    use_lockfile                = true
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

# Talks to the database through the Cloud SQL Auth Proxy on localhost (the proxy
# encrypts the connection, so sslmode is disable here). The password is NOT in
# this repo or in state: pass it in the environment, e.g.
#   PGPASSWORD="$(gcloud secrets versions access latest --secret cloud-sql-postgres-password --project parcel-data-api)" tofu plan
provider "postgresql" {
  host      = "127.0.0.1"
  port      = var.proxy_port
  database  = var.database
  username  = "postgres"
  sslmode   = "disable"
  superuser = false # Cloud SQL's postgres is not a real superuser
}
