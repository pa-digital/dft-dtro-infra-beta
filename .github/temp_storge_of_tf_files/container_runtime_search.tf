# consume service
# resource "google_cloud_run_service_iam_policy" "consume_service_noauth" {
#   location = google_cloud_run_v2_service.consume_service.location
#   project  = google_cloud_run_v2_service.consume_service.project
#   service  = google_cloud_run_v2_service.consume_service.name
#
#   policy_data = data.google_iam_policy.noauth.policy_data
# }

resource "google_cloud_run_v2_service" "consume_service" {
  name     = "${local.service_name_prefix}-${var.consume_service_image}"
  location = var.region
  #   ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.cloud_run_service_account

    scaling {
      min_instance_count = 0
      max_instance_count = local.max_instance_count
    }

    vpc_access {
      connector = google_vpc_access_connector.serverless_connector.id
      egress    = "PRIVATE_RANGES_ONLY"
      #       network_interfaces {
      #         network = google_vpc_access_connector.serverless_connector.id
      #       }
    }

    containers {
      image = "europe-west1-docker.pkg.dev/pa-tc-sandbox-341312/pa-tc-sandbox-341312/ollama:latest"
      #       image = "${var.region}-docker.pkg.dev/${var.project}/dtro/${var.consume_service_image}:${var.tag}"

      dynamic "env" {
        for_each = local.common_service_envs
        content {
          name  = env.key
          value = env.value
        }
      }

      #       env {
      #         name = local.db_password_env_name
      #         value_source {
      #           secret_key_ref {
      #             secret  = google_secret_manager_secret.postgres_password.secret_id
      #             version = "latest"
      #           }
      #         }
      #       }

      #       dynamic "volume_mounts" {
      #         for_each = local.common_secret_files
      #         content {
      #           name       = volume_mounts.key
      #           mount_path = volume_mounts.value.mount_point
      #         }
      #       }

      startup_probe {
        period_seconds    = 4
        failure_threshold = 5

        http_get {
          path = "/health"
          port = 8080
        }
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
      }
    }

    #     dynamic "volumes" {
    #       for_each = local.common_secret_files
    #       content {
    #         name = volumes.key
    #         secret {
    #           secret       = volumes.value.secret
    #           default_mode = 0444
    #           items {
    #             version = "latest"
    #             path    = "value"
    #             mode    = 0400
    #           }
    #         }
    #       }
    #     }
  }

  #   depends_on = [
  #     # Access to secrets is required to start the container
  #     google_secret_manager_secret_iam_member.cloud_run_secrets
  #   ]
}