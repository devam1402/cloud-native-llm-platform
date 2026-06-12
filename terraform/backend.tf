# ─────────────────────────────────────────────────────────────────────────────
# backend.tf — Remote state in GCS
#
# WHY REMOTE STATE: local tfstate on a laptop is a single point of failure
# and leaks secrets into your filesystem. GCS gives versioning + locking.
#
# BOOTSTRAP (one-time, before first `terraform init`):
#   gsutil mb -l asia-south1 gs://llm-inference-platform-tfstate
#   gsutil versioning set on gs://llm-inference-platform-tfstate
#
# NOTE: backend blocks cannot use variables — values are hardcoded by design.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  backend "gcs" {
    bucket = "gold-courage-498911-e4-tfstate"
    prefix = "gke/platform"
  }
}
