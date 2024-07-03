locals {
  artifact_registry_name = "${data.google_project.project.name}-repository"
  project_id             = data.google_project.project.project_id
}