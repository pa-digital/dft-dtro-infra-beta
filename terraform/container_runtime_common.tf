# Environmental variables and secrets
locals {
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

      PROJECTID         = var.project
      CONSUMESERVICEURL = "https://${var.consume_service_domain}"

      EnableRedisCache = var.feature_enable_redis_cache
  })
  #   common_secret_files = merge(
  #     local.db_connection_secret_files
  #   )
}

# Service account
resource "google_service_account" "cloud_run" {
  account_id   = "${var.application_name}-cloud-run"
  display_name = "${var.application_name}-cloud-run"
  description  = "Service Account for ${var.application_name} to run in Cloud Run"
}

locals {
  cloud_run_account = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Policies
resource "google_project_iam_member" "logging" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = local.cloud_run_account
}

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

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}