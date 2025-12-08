terraform {
  required_version = ">= 1.6.0"

  # GCS Backend for Google Cloud Platform
  # Configuration values are provided via backend-config.hcl (auto-generated)
  backend "gcs" {
    bucket = "vibetics-cloudedge-nonprod-tfstate"
    prefix = "vibetics-cloudedge-nonprod-demo-vpc"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}
