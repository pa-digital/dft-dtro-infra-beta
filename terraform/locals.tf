locals {
  artifact_registry_name = "${data.google_project.project.name}-repository"
  project_id             = data.google_project.project.project_id

  database_name_prefix = "${var.application_name}-${var.environment}"
  database_name        = "${local.database_name_prefix}-database"
  database_username    = var.application_name
}