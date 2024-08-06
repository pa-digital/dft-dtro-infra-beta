locals {
  apigee-mig-proxy       = "apigee-mig-proxy"
  ui-apigee-mig-proxy    = "ui_apigee-mig-proxy"
  cloud_run_service_name = "${local.name_prefix}-${var.dtro_service_image}"
  database_name          = "${local.name_prefix}-database"
  database_username      = var.application_name
  project_id             = data.google_project.project.project_id
  name_prefix            = "${var.application_name}-${var.environment}"
}
