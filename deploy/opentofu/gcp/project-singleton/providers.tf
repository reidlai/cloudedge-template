provider "google" {
  project = var.project_id
  region  = var.region

  # Required for billing budget API which needs a quota project
  user_project_override = true
  billing_project       = var.project_id
}

provider "google-beta" {
  project = var.project_id
  region  = var.region

  user_project_override = true
  billing_project       = var.project_id
}
