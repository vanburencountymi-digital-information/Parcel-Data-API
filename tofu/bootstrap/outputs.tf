output "state_bucket" {
  value = cloudflare_r2_bucket.tfstate.name
}

output "dump_bucket" {
  value = module.r2_dumps.bucket_name
}

output "r2_endpoint" {
  value = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
}

# Sensitive: read with `tofu output -json dump_write_credentials`, then store the value
# in Secret Manager (do not print it into logs or commit it). Once the GCP project exists,
# a root there should write these into Secret Manager instead of a person copying them.
output "dump_write_credentials" {
  sensitive = true
  value     = module.r2_dumps.dump_write_credentials
}

output "dump_read_credentials" {
  sensitive = true
  value     = module.r2_dumps.dump_read_credentials
}
