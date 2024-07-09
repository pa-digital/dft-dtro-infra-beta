locals {
  artifact_registry_name = "${data.google_project.project.name}-repository"
  name_prefix            = "${var.application_name}-${var.environment}"
  cloud_run_service_name = "${local.name_prefix}-${var.dtro_service_image}"
  database_name          = "${local.name_prefix}-database"
  alb_name               = "${local.name_prefix}-alb"
  database_username      = var.application_name
  project_id             = data.google_project.project.project_id
}
