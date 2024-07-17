locals {
  apigee-mig-proxy       = "apigee-mig-proxy"
  artifact_registry_name = "${data.google_project.project.name}-repository"
  cloud_run_service_name = "${local.name_prefix}-${var.dtro_service_image}"
  database_name          = "${local.name_prefix}-database"
  database_username      = var.application_name
  domain                 = var.environment == "prod" ? "${var.application_name}.${var.org_domain}" : "${var.application_name}-${var.environment}.${var.org_domain}"
  project_id             = data.google_project.project.project_id
  name_prefix            = "${var.application_name}-${var.environment}"
}
