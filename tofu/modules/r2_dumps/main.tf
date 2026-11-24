# R2 bucket for parcel database dumps, with retention, delete protection and scoped tokens.
# Adapted from did-vaultwarden's r2_backups module.
#
# Layout (prefixes):
#   daily/    nightly pg_dump -Fc of the parcel database; expires after 30 days
#   loads/    dumps taken immediately before and after each data load; expires after 12 months
#   archive/  one-off archives, e.g. the final copy of db-dice's geo and assessing schemas;
#             never expires (delete by hand, deliberately)
terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

variable "account_id" {
  type = string
}

variable "bucket_name" {
  type = string
}

locals {
  day = 24 * 60 * 60

  # R2 bucket-scoped permission groups (stable Cloudflare ids).
  perm_item_read  = "6a018a9f2fc74eb6b293b0c548f38b39" # Workers R2 Storage Bucket Item Read
  perm_item_write = "2efd5506f9c8494dacb1fa10a3e7d5b6" # Workers R2 Storage Bucket Item Write

  bucket_resource = jsonencode({
    "com.cloudflare.edge.r2.bucket.${var.account_id}_default_${var.bucket_name}" = "*"
  })
}

resource "cloudflare_r2_bucket" "dumps" {
  account_id = var.account_id
  name       = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_r2_bucket_lifecycle" "dumps" {
  account_id  = var.account_id
  bucket_name = cloudflare_r2_bucket.dumps.name

  rules = [
    {
      id         = "abort-stale-multipart"
      enabled    = true
      conditions = { prefix = "" }
      abort_multipart_uploads_transition = {
        condition = { type = "Age", max_age = local.day }
      }
    },
    {
      id         = "expire-daily"
      enabled    = true
      conditions = { prefix = "daily/" }
      delete_objects_transition = {
        condition = { type = "Age", max_age = 30 * local.day }
      }
    },
    {
      id         = "expire-loads"
      enabled    = true
      conditions = { prefix = "loads/" }
      delete_objects_transition = {
        condition = { type = "Age", max_age = 365 * local.day }
      }
    },
    # No rule for archive/: those objects stay until someone deletes them on purpose.
  ]
}

# Objects cannot be deleted or overwritten for a fixed period, even with a valid write
# token, so a compromised writer cannot wipe recent dumps. R2 "Item Write" can also list,
# read and delete, so this lock (not the token scope) is what protects them.
resource "cloudflare_r2_bucket_lock" "dumps" {
  account_id  = var.account_id
  bucket_name = cloudflare_r2_bucket.dumps.name

  rules = [
    # Keep these sorted by id: Cloudflare returns them in that order, and the provider
    # compares the list by position, so any other order shows a permanent diff.
    {
      id        = "lock-archive"
      enabled   = true
      prefix    = "archive/"
      condition = { type = "Age", max_age_seconds = 30 * local.day }
    },
    {
      id        = "lock-daily"
      enabled   = true
      prefix    = "daily/"
      condition = { type = "Age", max_age_seconds = 14 * local.day }
    },
    {
      id        = "lock-loads"
      enabled   = true
      prefix    = "loads/"
      condition = { type = "Age", max_age_seconds = 30 * local.day }
    },
  ]
}

# Account-owned tokens (the provider's cloudflare_api_token resource calls a user-level
# endpoint that the bootstrap token cannot reach).
resource "cloudflare_account_token" "dump_write" {
  account_id = var.account_id
  name       = "parcel-data-api-dump-write"

  policies = [{
    effect            = "allow"
    permission_groups = [{ id = local.perm_item_write }]
    resources         = local.bucket_resource
  }]
}

resource "cloudflare_account_token" "dump_read" {
  account_id = var.account_id
  name       = "parcel-data-api-dump-read"

  policies = [{
    effect            = "allow"
    permission_groups = [{ id = local.perm_item_read }]
    resources         = local.bucket_resource
  }]
}

output "bucket_name" {
  value = cloudflare_r2_bucket.dumps.name
}

# R2's S3 access key id is the token id; the secret is the sha256 of the token value.
output "dump_write_credentials" {
  sensitive = true
  value = {
    access_key_id     = cloudflare_account_token.dump_write.id
    secret_access_key = sha256(cloudflare_account_token.dump_write.value)
  }
}

output "dump_read_credentials" {
  sensitive = true
  value = {
    access_key_id     = cloudflare_account_token.dump_read.id
    secret_access_key = sha256(cloudflare_account_token.dump_read.value)
  }
}
