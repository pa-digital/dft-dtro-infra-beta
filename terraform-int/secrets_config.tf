resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "${local.name_prefix}-postgres-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "postgres_password_value" {
  secret      = google_secret_manager_secret.postgres_password.id
  secret_data = module.postgres_db.generated_user_password

  depends_on = [module.postgres_db]
}
