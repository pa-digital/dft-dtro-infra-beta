resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "${var.application_name}-postgres-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "postgres_password_value" {
  count       = 0
  secret      = google_secret_manager_secret.postgres_password.id
  secret_data = module.postgres_db.generated_user_password

  depends_on = [module.postgres_db]
}
