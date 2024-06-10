resource "google_artifact_registry_repository" "artifact_repository" {
  location      = var.region
  repository_id = var.project
  description   = "Repository for housing prototype images"
  format        = "DOCKER"
  docker_config {
    immutable_tags = true
  }
}