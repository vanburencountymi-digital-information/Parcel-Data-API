variable "proxy_port" {
  description = "Local port of the Cloud SQL Auth Proxy for parcel-data-api-pg."
  type        = number
  default     = 5433
}

variable "database" {
  description = "Database that holds the geo and assessing schemas."
  type        = string
  default     = "postgres"
}

variable "schemas" {
  description = "Parcel schemas restored from db-dice (checklist 2.2)."
  type        = set(string)
  default     = ["geo", "assessing"]
}

variable "read_roles" {
  description = "Roles with read-only access to the parcel schemas. Walter, parcel_studio_app and bsa_featureserv_ro are not recreated, on purpose."
  type        = set(string)
  default     = ["martin_ro", "steward_app"]
}

variable "table_owner" {
  description = "Role that creates tables in the parcel schemas (default privileges apply to its future objects)."
  type        = string
  default     = "postgres"
}
