variable "project_id" {
  description = "GCP project ID (globally unique, cannot be changed later)."
  type        = string
  default     = "parcel-data-api"
}

variable "project_name" {
  description = "Display name of the project."
  type        = string
  default     = "parcel-data-api"
}

variable "org_id" {
  description = "GCP organization (dicemi.org)."
  type        = string
  default     = "549080023569"
}

variable "billing_account" {
  description = "Billing account the project is linked to."
  type        = string
  default     = "0159C6-FC05F1-D71AD4"
}

variable "apis" {
  description = "APIs enabled on the project. Add to this list as later phases need more."
  type        = set(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "servicenetworking.googleapis.com",
    "compute.googleapis.com",
  ]
}

variable "owners" {
  description = "Members granted roles/owner on the project (additive; other owners are left alone). Add the owners group here once it exists."
  type        = set(string)
  default = [
    "user:maria.violante@dicemi.org",
    "user:jerry.happel@dicemi.org",
  ]
}
