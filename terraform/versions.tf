terraform {
  required_version = ">= 1.8.2"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.28.0"
    }
  }
}