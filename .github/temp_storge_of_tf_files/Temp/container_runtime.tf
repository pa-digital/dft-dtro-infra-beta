# Environmental variables and secrets
locals {
  #
  service_name_prefix = "${var.application_name}-${var.environment}"

  #
  cloud_run_account = "serviceAccount:${var.cloud_run_service_account}"

  # At most `database_max_connections` in total can be opened, there are 2 services (publish and consume)
  max_instance_count = floor(var.database_max_connections / var.db_connections_per_cloud_run_instance / 2)

  # Postgres database
  #   db_connection_envs = {
  #     Postgres__Host        = module.postgres_db.private_ip_address
  #     Postgres__Port        = "5432",
  #     Postgres__User        = var.application_name
  #     Postgres__DbName      = local.database_name
  #     Postgres__UseSsl      = true
  #     Postgres__MaxPoolSize = var.db_connections_per_cloud_run_instance
  #     PGSSLCERT             = "/secrets/postgres-cert/value"
  #     PGSSLKEY              = "/secrets/postgres-key/value"
  #   }
  #   db_password_env_name = "Postgres__Password"
  #
  #   db_connection_secret_files = {
  #     secret_postgres_client_certificate = {
  #       secret      = google_secret_manager_secret.postgres_client_certificate.secret_id,
  #       mount_point = "/secrets/postgres-cert"
  #     },
  #     secret_postgres_client_key = {
  #       secret      = google_secret_manager_secret.postgres_client_key.secret_id,
  #       mount_point = "/secrets/postgres-key"
  #     }
  #   }

  common_service_envs = merge(
    #     local.db_connection_envs,
    {
      DEPLOYED = timestamp()

      PROJECTID = var.project

      EnableRedisCache = var.feature_enable_redis_cache
  })
  #   common_secret_files = merge(
  #     local.db_connection_secret_files
  #   )
}

# Policies
# resource "google_secret_manager_secret_iam_member" "cloud_run_secrets" {
#   for_each = {
#     for i, value in flatten([
#       google_secret_manager_secret.postgres_password,
#       google_secret_manager_secret.postgres_client_certificate,
#       google_secret_manager_secret.postgres_client_key,
#       var.feature_enable_redis_cache ? [
#         one(google_secret_manager_secret.redis_auth_string),
#         one(google_secret_manager_secret.redis_server_ca)
#       ] : [],
#     ]) : i => value
#   }
#
#   project   = var.project
#   secret_id = each.value.secret_id
#   role      = "roles/secretmanager.secretAccessor"
#   member    = local.cloud_run_account
# }

# data "google_iam_policy" "noauth" {
#   binding {
#     role = "roles/run.invoker"
#     members = [
#       "allUsers",
#     ]
#   }
# }

resource "google_cloud_run_v2_service" "publish_service" {
  name     = "${local.service_name_prefix}-${var.publish_service_image}"
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
      #       image = "${var.region}-docker.pkg.dev/${var.project}/dtro/${var.publish_service_image}:${var.tag}"

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
