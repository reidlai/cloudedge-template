###################
# Local variables #
###################

locals {
  project_suffix              = var.project_suffix
  cloudedge_github_repository = var.cloudedge_github_repository
  project_id                  = var.project_id != "" ? var.project_id : "${local.cloudedge_github_repository}-${local.project_suffix}"
  region                      = var.region
  billing_account_name        = var.billing_account_name
  budget_amount               = var.budget_amount
  standard_tags = merge(
    var.resource_tags,
    {
      "project-suffix" = var.project_suffix
      "project"        = local.project_id
      "managed-by"     = "opentofu"
    }
  )
  enable_logging = var.enable_logging

  host_project_id = "vibetics-shared-${local.project_suffix}"
}

provider "google" {
  project = local.project_id
  region  = local.region

  # Required for billing budget API which needs a quota project
  user_project_override = true
  billing_project       = local.project_id
}

provider "google-beta" {
  project = local.project_id
  region  = local.region

  user_project_override = true
  billing_project       = local.project_id
}

data "google_billing_account" "billing_account" {
  display_name = local.billing_account_name
  depends_on   = [google_project_service.cloudbilling]
}

# Get Project Number for Service Agent
data "google_project" "current" {
  project_id = local.project_id
}

###############
# Googel APIs #
###############

resource "google_project_service" "billingbudgets" {
  project            = local.project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbilling" {
  project            = local.project_id
  service            = "cloudbilling.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project            = local.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "logging" {
  project            = local.project_id
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

#############################
# Google Billing and Budget #
#############################

resource "google_billing_budget" "budget" {
  billing_account = data.google_billing_account.billing_account.id
  display_name    = "Vibetics Cloud Edge Budget"

  budget_filter {
    projects = ["projects/${local.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "HKD"
      units         = local.budget_amount
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.8
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  depends_on = [google_project_service.billingbudgets]
}

##########################
# Project Logging bucket #
##########################

resource "google_logging_project_bucket_config" "logs_bucket" {
  count          = local.enable_logging ? 1 : 0
  project        = local.project_id
  location       = "global"
  retention_days = 30 # NFR-001: 30-day trace data retention
  bucket_id      = "${local.project_id}-logs"
  description    = "30-day retention bucket for demo backend service logs (NFR-001 compliance)"

  depends_on = [
    google_project_service.logging
  ]
}
