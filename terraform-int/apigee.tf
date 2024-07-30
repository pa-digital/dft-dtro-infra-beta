# resource "google_apigee_organization" "apigee_org" {
#   project_id         = local.project_id
#   analytics_region   = var.region
#   display_name       = "${var.application_name}-${var.environment}-apigee-org"
#   description        = "Terraform-provisioned D-TRO Apigee Org."
#   runtime_type       = "CLOUD"
#   authorized_network = data.google_compute_network.alb_vpc_network.id
#   retention          = "DELETION_RETENTION_UNSPECIFIED"
#   billing_type       = "PAYG"
# }
#
# resource "google_apigee_instance" "apigee_instance" {
#   name     = "${var.application_name}-apigee-instance"
#   location = var.region
#   org_id   = google_apigee_organization.apigee_org.id
# }

resource "google_apigee_environment" "apigee_env" {
  org_id       = data.terraform_remote_state.primary_default_tfstate.outputs.apigee_org
  name         = "${local.name_prefix}-apigee-environment"
  description  = "${var.environment} ${var.application_name} Apigee Environment"
  display_name = "${var.integration_prefix} ${var.application_name} Environment"
  type         = "INTERMEDIATE"
}

resource "google_apigee_instance_attachment" "attachment" {
  instance_id = data.terraform_remote_state.primary_default_tfstate.outputs.apigee_instance_id
  environment = google_apigee_environment.apigee_env.name
}

resource "google_apigee_envgroup" "env_group" {
  name      = "${local.name_prefix}-apigee-environment-group"
  hostnames = [var.domain[var.environment]]
  org_id    = data.terraform_remote_state.primary_default_tfstate.outputs.apigee_org
}

resource "google_apigee_envgroup_attachment" "group_attachment" {
  envgroup_id = google_apigee_envgroup.env_group.id
  environment = google_apigee_environment.apigee_env.name
}
