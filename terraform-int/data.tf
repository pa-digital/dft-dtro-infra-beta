data "google_project" "project" {}

# Commented out until we have valid organisation domain from DfT
data "google_organization" "organisation" {
  domain = var.org_domain
}

data "google_compute_network" "alb_vpc_network" {
  name = "${var.application_name}-${var.environment}-alb-network"
}
