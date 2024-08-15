locals {
  cloud_run_service_name = "${local.name_prefix}-${var.dtro_service_image}"
  database_name          = "${local.name_prefix}-database"
  database_username      = var.application_name
  project_id             = data.google_project.project.project_id
  name_prefix            = "${var.application_name}-${var.integration_prefix}"
}
