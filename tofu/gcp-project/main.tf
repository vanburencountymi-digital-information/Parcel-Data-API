# The GCP project for parcel-data-api (migration checklist 1.1, DIC-3114).
# Everything else in GCP (Cloud SQL, Secret Manager, service accounts) goes in its own
# root or is added here, never created by hand in the console.

resource "google_project" "this" {
  name            = var.project_name
  project_id      = var.project_id
  org_id          = var.org_id
  billing_account = var.billing_account

  # Do not create the default network; networking is defined as code later.
  auto_create_network = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_service" "apis" {
  for_each = var.apis

  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}

# Additive on purpose: authoritative bindings would remove owners we do not manage here.
resource "google_project_iam_member" "owners" {
  for_each = var.owners

  project = google_project.this.project_id
  role    = "roles/owner"
  member  = each.value
}
