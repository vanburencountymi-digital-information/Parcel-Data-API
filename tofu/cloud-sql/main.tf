# Dedicated Cloud SQL Postgres 17 for parcel data only (migration checklist 1.2, DIC-3115).
# Private IP only: no public address and no authorized networks.

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = "parcel-data-api"
  auto_create_subnetworks = false
}

# Private services access: a reserved range plus a peering to Google's service network.
resource "google_compute_global_address" "psa" {
  project       = var.project_id
  name          = "parcel-data-api-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_prefix_length
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}

resource "google_sql_database_instance" "this" {
  project          = var.project_id
  name             = var.instance_name
  region           = var.region
  database_version = "POSTGRES_17"

  # OpenTofu-level guard; settings.deletion_protection_enabled is the GCP-side one.
  deletion_protection = true

  settings {
    edition                     = "ENTERPRISE"
    tier                        = var.tier
    availability_type           = var.availability_type
    activation_policy           = var.activation_policy
    disk_type                   = "PD_SSD"
    disk_size                   = var.disk_size_gb
    disk_autoresize             = true
    deletion_protection_enabled = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.this.id
      ssl_mode        = "ENCRYPTED_ONLY"
      # No authorized_networks, on purpose.
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "08:00" # UTC, about 3-4 am Eastern
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day  = 7 # Sunday
      hour = 9 # UTC
    }
  }

  depends_on = [google_service_networking_connection.psa]
}
