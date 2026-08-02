variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP Region for resources"
  default     = "us-central1"
}

variable "kms_key_name" {
  type        = string
  description = "Resource name of the Cloud KMS key for storage encryption"
  default     = null
}

variable "ingestion_service_account" {
  type        = string
  description = "Service account email allowed to write raw data to landing bucket"
}

variable "admin_email" {
  type        = string
  description = "Email address for dataset ownership"
}

variable "data_pipeline_service_account" {
  type        = string
  description = "Service account email running the data pipeline"
}