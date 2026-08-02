terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ------------------------------------------------------------------------------
# 1. Google Cloud Storage: D0 Raw Landing Bucket
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "d0_raw_landing" {
  name                     = "${var.project_id}-d0-raw-landing"
  location                 = var.region
  force_destroy            = false
  public_access_prevention = "enforced"

  # Uniform Bucket-Level Access for strict RBAC
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  # Cost Optimization: Transition raw logs/landings after 30 days
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  encryption {
    default_kms_key_name = var.kms_key_name
  }
}

# IAM Binding for Least Privilege (Raw Ingestion Role)
resource "google_storage_bucket_iam_member" "ingestion_writer" {
  bucket = google_storage_bucket.d0_raw_landing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.ingestion_service_account}"
}

# ------------------------------------------------------------------------------
# 2. BigQuery Dataset: D1 Staged / Enforced
# ------------------------------------------------------------------------------
resource "google_bigquery_dataset" "d1_staged_enforced" {
  dataset_id                  = "d1_staged_enforced"
  friendly_name               = "D1 Staged Enforced Data"
  description                 = "Enforced and validated staging layer for onboarding data"
  location                    = var.region
  default_table_expiration_ms = 3600000000 # 41.6 days

  access {
    role          = "OWNER"
    user_by_email = var.admin_email
  }

  # Comment out until the service account exists
  # access {
  #   role          = "WRITER"
  #   user_by_email = var.data_pipeline_service_account
  # }
}

# BigQuery Table
resource "google_bigquery_table" "student_onboarding_staged" {
  dataset_id          = google_bigquery_dataset.d1_staged_enforced.dataset_id
  table_id            = "student_onboarding"
  deletion_protection = false # Set to true for production once initial testing passes

  schema = <<EOF
[
  {"name": "student_id", "type": "STRING", "mode": "REQUIRED"},
  {"name": "parent_id", "type": "STRING", "mode": "REQUIRED"},
  {"name": "has_learning_support_needs", "type": "BOOLEAN", "mode": "REQUIRED"},
  {"name": "created_at", "type": "TIMESTAMP", "mode": "REQUIRED"}
]
EOF
}

# ------------------------------------------------------------------------------
# 3. Row-Level Access Policy (Executed via Native BigQuery SQL DDL Job)
# ------------------------------------------------------------------------------
resource "google_bigquery_job" "create_row_access_policy" {
  job_id = "job_create_lsa_filter_${google_bigquery_table.student_onboarding_staged.table_id}"

  query {
    query = <<EOF
CREATE OR REPLACE ROW ACCESS POLICY filter_lsa_assigned_students
ON `${var.project_id}.${google_bigquery_dataset.d1_staged_enforced.dataset_id}.${google_bigquery_table.student_onboarding_staged.table_id}`
GRANT TO ("group:lsas@habotconnect.com", "group:parents@habotconnect.com")
FILTER USING (SESSION_USER() = parent_id OR SESSION_USER() = '${var.admin_email}');
EOF

    use_legacy_sql = false
  }

  depends_on = [
    google_bigquery_table.student_onboarding_staged
  ]
}