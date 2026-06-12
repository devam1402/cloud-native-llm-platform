# ─────────────────────────────────────────────────────────────────────────────
# versions.tf — Provider & Terraform version pinning
#
# WHY PINNED: unpinned providers are how "it worked yesterday" happens.
# ~> 6.x allows patch/minor updates within the major version only.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}