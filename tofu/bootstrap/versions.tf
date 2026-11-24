terraform {
  required_version = ">= 1.8"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # State lives in R2 via the S3-compatible API, in the bucket this root creates.
  # Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (derived from the
  # Cloudflare token). First run: see README.md ("First apply"), because the bucket does
  # not exist yet.
  backend "s3" {
    bucket = "parcel-data-api-tfstate"
    key    = "bootstrap/terraform.tfstate"
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

# Reads CLOUDFLARE_API_TOKEN from the environment.
provider "cloudflare" {}
