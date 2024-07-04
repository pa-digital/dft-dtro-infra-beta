locals {
  artifact_registry_name = "${data.google_project.project.name}-repository"
  database_name_prefix   = "${var.application_name}-${var.environment}"
  database_name          = "${local.database_name_prefix}-database"
  database_username      = var.application_name
  project_id             = data.google_project.project.project_id
}
