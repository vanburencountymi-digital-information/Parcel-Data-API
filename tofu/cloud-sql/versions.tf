terraform {
  required_version = ">= 1.8"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # State lives in the R2 bucket created by ../bootstrap. Credentials come from
  # AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (see ../bootstrap/README.md).
  backend "s3" {
    bucket = "parcel-data-api-tfstate"
    key    = "cloud-sql/terraform.tfstate"
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

# Uses Application Default Credentials (`gcloud auth application-default login`).
provider "google" {}
