data "google_project" "project" {}

# Commented out until we have valid organisation domain from DfT
# data "google_organization" "organisation" {
#   domain = var.org_domain
# }

data "google_apigee_instance" "apigee_instance" {
  name = "${var.application_name}-apigee-instance"
}
