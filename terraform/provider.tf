provider "google" {
  project = local.project_id
  region  = var.region
}