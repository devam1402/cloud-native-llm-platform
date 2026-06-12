# ─────────────────────────────────────────────────────────────────────────────
# main.tf — GKE cluster (control plane definition)
#
# DESIGN DECISIONS (the parts an interviewer will ask about):
#   • Zonal cluster        → 1 control plane, free tier eligible; regional = 3x cost
#   • VPC-native           → alias IPs, required for modern GKE networking
#   • Workload Identity    → pods authenticate to GCP APIs WITHOUT node SA keys.
#                            This is how MinIO→GCS or vLLM→GCS model pulls stay keyless.
#   • remove_default_node_pool → the default pool is unmanageable via TF; we
#                            delete it and define our own (see node_pools.tf)
#   • Shielded nodes       → secure boot + integrity monitoring, zero cost
#   • Release channel      → REGULAR: Google manages K8s patching cadence
# ─────────────────────────────────────────────────────────────────────────────

resource "google_container_cluster" "platform" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.zone # zonal — see header

  network    = google_compute_network.platform.id
  subnetwork = google_compute_subnetwork.platform.id

  # We manage node pools explicitly; the default pool is deleted on creation.
  remove_default_node_pool = true
  initial_node_count       = 1

  # VPC-native cluster using the subnet's secondary ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Pods authenticate to GCP as Kubernetes service accounts — no exported keys.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  # Control plane reachable only from allowed CIDR (tighten in tfvars)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.master_authorized_cidr
      display_name = "admin-access"
    }
  }

  # Don't let a `terraform destroy` take prod down by accident.
  # Dev default is false — flip to true if this ever holds anything real.
  deletion_protection = false

  # Cost visibility per namespace/label in billing export —
  # feeds the cost-per-token analysis later.
  cost_management_config {
    enabled = true
  }

  # Keep logs lean: system + workloads, no API server audit firehose.
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    # Prometheus stack is OUR observability layer (deployed via ArgoCD).
    # Managed Prometheus off — we're building, not buying.
    managed_prometheus {
      enabled = false
    }
  }

  resource_labels = {
    environment = var.environment
    managed-by  = "terraform"
    project     = "ai-inference-platform"
  }

  lifecycle {
    # Node pool changes shouldn't force cluster replacement
    ignore_changes = [initial_node_count]
  }
}
