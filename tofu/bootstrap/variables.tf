variable "cloudflare_account_id" {
  description = "Cloudflare account that owns R2 (the team account, the same one did-vaultwarden uses). Not a secret."
  type        = string
  default     = "b2a7b4d3a2d2a130919b11524e7564b2"
}

variable "state_bucket_name" {
  description = "R2 bucket holding OpenTofu state for this project's envs."
  type        = string
  default     = "parcel-data-api-tfstate"
}

variable "dump_bucket_name" {
  description = "R2 bucket holding parcel database dumps and archives."
  type        = string
  default     = "parcel-data-api-dumps"
}
