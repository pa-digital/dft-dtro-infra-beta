locals {
  apigee-mig-proxy       = "apigee-mig-proxy"
  artifact_registry_name = "${data.google_project.project.name}-repository"
  cloud_run_service_name = "${local.name_prefix}-${var.dtro_service_image}"
  database_name          = "${local.name_prefix}-database"
  database_username      = var.application_name
  project_id             = data.google_project.project.project_id
  name_prefix            = var.environment == "test" && var.integration_prefix == "int" ? "${var.application_name}-${var.integration_prefix}" : "${var.application_name}-${var.environment}"
}
