data "google_project" "project" {}

# Commented out until we have valid organisation domain from DfT
data "google_organization" "organisation" {
  domain = var.org_domain
}
