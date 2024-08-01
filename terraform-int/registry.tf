resource "google_artifact_registry_repository" "dtro_artifact_repository" {
  location      = var.region
  repository_id = "${data.google_project.project.name}-int-repository"
  description   = "Repository for housing prototype images"
  format        = "DOCKER"
  docker_config {
    immutable_tags = false
  }
}

resource "google_artifact_registry_repository" "service_ui_artifact_repository" {
  location      = var.region
  repository_id = "${data.google_project.project.name}-ui-int-repository"
  description   = "Repository for housing Service Portal UI images"
  format        = "DOCKER"
  docker_config {
    immutable_tags = false
  }
}
