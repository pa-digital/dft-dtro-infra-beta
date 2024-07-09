# Apigee
resource "google_apigee_organization" "apigee_org" {
  project_id         = local.name_prefix
  analytics_region   = var.region
  display_name       = "${local.name_prefix}-apigee-org"
  description        = "Terraform-provisioned D-TRO Apigee Org."
  runtime_type       = "CLOUD"
  authorized_network = module.alb_vpc_network.network_id
  retention          = "DELETION_RETENTION_UNSPECIFIED"
  billing_type       = "PAYG"
}

resource "google_apigee_instance" "apigee_instance" {
  name     = "${var.application_name}-apigee-instance"
  location = var.region
  org_id   = google_apigee_organization.apigee_org.id
  ip_range = "10.9.0.0/22"
}

resource "google_apigee_environment" "apigee_env" {
  org_id       = google_apigee_organization.apigee_org.id
  name         = "${local.name_prefix}-apigee-environment"
  description  = "${var.environment} ${var.application_name} Apigee Environment"
  display_name = "${var.environment} ${var.application_name} Environment"
  type         = "INTERMEDIATE"
}

resource "google_apigee_instance_attachment" "attachment" {
  for_each    = google_apigee_environment.apigee_env
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.apigee_env.name
}

resource "google_apigee_envgroup" "env_group" {
  name      = "${local.name_prefix}-apigee-environment-group"
  hostnames = var.environment == "prod" ? ["dtro.${var.org_domain}"] : ["${var.environment}.${var.org_domain}"]
  org_id    = google_apigee_organization.apigee_org.id
}

resource "google_apigee_envgroup_attachment" "group_attachment" {
  envgroup_id = google_apigee_envgroup.env_group.id
  environment = google_apigee_environment.apigee_env.name
}
