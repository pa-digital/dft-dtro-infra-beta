locals {
  # At most `database_max_connections` in total can be opened
  max_instance_count   = floor(var.database_environment_configuration[var.environment].max_connections / var.db_connections_per_cloud_run_instance)
  db_password_env_name = "POSTGRES_PASSWORD"

  cr_envs_vars = merge(
    {
      DEPLOYED               = timestamp()
      PROJECTID              = data.google_project.project.project_id
      EnableRedisCache       = var.feature_enable_redis_cache
      POSTGRES_DB            = local.database_name
      POSTGRES_USER          = local.database_username
      POSTGRES_HOST          = var.postgres_host
      POSTGRES_PORT          = var.postgres_port
      POSTGRES_SSL           = var.postgres_use_ssl
      POSTGRES_MAX_POOL_SIZE = var.db_connections_per_cloud_run_instance
  })
}

# TODO: Move this File to dft-dtro-beta repo
resource "google_cloud_run_v2_service" "dtro_service" {
  count    = 0
  name     = "${local.cloud_run_service_name}-2"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = var.execution_service_account

    scaling {
      min_instance_count = 1
      max_instance_count = local.max_instance_count
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [module.postgres_db.instance_connection_name]
      }
    }

    vpc_access {
      connector = google_vpc_access_connector.serverless_connector.id
      egress    = "PRIVATE_RANGES_ONLY"
      #       network_interfaces {
      #         network = google_vpc_access_connector.serverless_connector.id
      #       }
    }

    containers {
      #       image = "${var.region}-docker.pkg.dev/${local.project_id}/${local.artifact_registry_name}/${var.dtro_service_image}:${var.tag}"
      # TODO: Below is the last stable image
      image = "europe-west1-docker.pkg.dev/dft-dtro-dev-01/dft-dtro-dev-repository/dft-dtro-beta@sha256:f34febca186167410eb8ee2a8362975521c8994c675ba22a5590cb563d442e0f"
      ports {
        container_port = 8080
      }

      dynamic "env" {
        for_each = local.cr_envs_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      env {
        name = local.db_password_env_name
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.postgres_password.secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        timeout_seconds   = 3
        period_seconds    = 15
        failure_threshold = 10
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

    containers {
      name  = "cloud-sql-proxy"
      image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest"
      args  = ["--private-ip", "${local.project_id}:${var.region}:${module.postgres_db.instance_name}"]
    }
  }
}