resource "google_apigee_environment" "apigee_env" {
  org_id       = data.terraform_remote_state.primary_default_tfstate.outputs.apigee_org
  name         = "${local.name_prefix}-apigee-environment"
  description  = "${var.integration_prefix} ${var.application_name} Apigee Environment"
  display_name = "${local.name_prefix} Environment"
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
