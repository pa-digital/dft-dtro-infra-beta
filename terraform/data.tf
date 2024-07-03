data "google_project" "project" {}

data "google_organization" "organisation" {
  domain = var.org_domain
}