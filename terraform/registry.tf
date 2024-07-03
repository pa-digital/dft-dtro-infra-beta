locals {
  artifact_registry_name = "${data.google_project.project.name}-repository"
}

resource "google_artifact_registry_repository" "artifact_repository" {
  location      = var.region
  repository_id = local.artifact_registry_name
  description   = "Repository for housing prototype images"
  format        = "DOCKER"
  docker_config {
    immutable_tags = false
  }
}