resource "google_project_service" "privateca" {
  project            = var.project_id
  service            = "privateca.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "certificatemanager" {
  project            = var.project_id
  service            = "certificatemanager.googleapis.com"
  disable_on_destroy = false
}
