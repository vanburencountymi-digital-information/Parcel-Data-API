variable "project_id" {
  description = "GCP project created by ../gcp-project."
  type        = string
  default     = "parcel-data-api"
}

variable "region" {
  description = "Region for the network and the instance."
  type        = string
  default     = "us-central1"
}

variable "instance_name" {
  description = "Cloud SQL instance name. Names cannot be reused for about a week after deletion."
  type        = string
  default     = "parcel-data-api-pg"
}

variable "tier" {
  description = "Machine tier. Smallest sensible size; resize after checklist 2.1 measures geo + assessing."
  type        = string
  default     = "db-custom-1-3840"
}

variable "availability_type" {
  description = "ZONAL, or REGIONAL for a standby in a second zone (HA)."
  type        = string
  default     = "ZONAL"
}

variable "activation_policy" {
  description = "NEVER = instance stopped (storage and backups only are billed); ALWAYS = running. Set to ALWAYS before checklist 1.3 (extensions)."
  type        = string
  default     = "NEVER"

  validation {
    condition     = contains(["NEVER", "ALWAYS"], var.activation_policy)
    error_message = "activation_policy must be NEVER or ALWAYS."
  }
}

variable "disk_size_gb" {
  description = "Initial disk size; it grows automatically."
  type        = number
  default     = 10
}

variable "psa_prefix_length" {
  description = "Prefix length of the range reserved for private services access (20 = about 4,000 addresses)."
  type        = number
  default     = 20
}
