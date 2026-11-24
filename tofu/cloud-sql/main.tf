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
      # Temporary public IP for setup only (var.public_ip_enabled, default false).
      # Still no authorized_networks: only the Auth Proxy with IAM works.
      ipv4_enabled    = var.public_ip_enabled
      private_network = google_compute_network.this.id
      ssl_mode        = "ENCRYPTED_ONLY"
      # No authorized_networks, on purpose.
    }

    # Lets people log in with their Google account (no password); see google_sql_user.iam below.
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
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

# Warns on every plan/apply while the public address is on.
check "public_ip_is_off" {
  assert {
    condition     = !var.public_ip_enabled
    error_message = "public_ip_enabled is true: the instance has a public IP (IAM + Auth Proxy only, no authorized networks). Apply again without -var public_ip_enabled=true to close it."
  }
}

# Built-in superuser. Password generated here and stored in Secret Manager, so nobody types or sees it.
# It is also in this root's state (private R2 bucket), same as the R2 keys.
resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "google_sql_user" "postgres" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = "postgres"
  password = random_password.postgres.result
}

resource "google_secret_manager_secret" "postgres_password" {
  project   = var.project_id
  secret_id = "cloud-sql-postgres-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "postgres_password" {
  secret      = google_secret_manager_secret.postgres_password.id
  secret_data = random_password.postgres.result
}

# ---------------------------------------------------------------------------
# Database roles (checklist 1.4, DIC-3117). No role for Walter, on purpose.
# ---------------------------------------------------------------------------

# Application logins: password generated here, stored in Secret Manager, never printed.
# Passwords are also in this root's state (private R2 bucket), same as the postgres one.
resource "random_password" "app_role" {
  for_each = var.app_roles

  length  = 32
  special = false
}

resource "google_sql_user" "app_role" {
  for_each = var.app_roles

  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = each.key
  password = random_password.app_role[each.key].result
}

resource "google_secret_manager_secret" "app_role" {
  for_each = var.app_roles

  project   = var.project_id
  secret_id = "cloud-sql-${replace(each.key, "_", "-")}-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app_role" {
  for_each = var.app_roles

  secret      = google_secret_manager_secret.app_role[each.key].id
  secret_data = random_password.app_role[each.key].result
}

# People: log in with their Google account through the Auth Proxy (--auto-iam-authn).
resource "google_sql_user" "iam" {
  for_each = var.iam_users

  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = each.value
  type     = "CLOUD_IAM_USER"
}

resource "google_project_iam_member" "iam_user" {
  for_each = {
    for pair in setproduct(var.iam_users, ["roles/cloudsql.client", "roles/cloudsql.instanceUser"]) :
    "${pair[0]}|${pair[1]}" => { user = pair[0], role = pair[1] }
  }

  project = var.project_id
  role    = each.value.role
  member  = "user:${each.value.user}"
}
