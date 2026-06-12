# ─────────────────────────────────────────────────────────────────────────────
# node_pools.tf — General-purpose pool (CPU, spot, autoscaling)
#
# THE COST STORY LIVES HERE:
#   • Spot VMs        → ~60-91% discount; preemption tolerance is a feature
#                       of the platform's reliability narrative, not a bug
#   • Autoscale 1→3   → idle = 1 node (~$0.04/hr), load = burst to 3
#   • Dedicated SA    → least-privilege, not the default compute SA
#
# NO GPU POOL — deliberate. GPU compute is rented (RunPod L4) and external.
# See docs/DECISIONS.md. A gpu_pool.tf.disabled could be staged for the
# future, but absent code > dead code.
# ─────────────────────────────────────────────────────────────────────────────

# Least-privilege service account for nodes.
# The default compute SA has Editor on the project — never use it.
resource "google_service_account" "nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE node pool SA (least privilege)"
  project      = var.project_id
}

# The minimum roles a GKE node actually needs:
resource "google_project_iam_member" "node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader", # pull images
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_node_pool" "general" {
  name     = "general"
  project  = var.project_id
  location = var.zone
  cluster  = google_container_cluster.platform.name

  autoscaling {
    min_node_count = var.node_pool_min_count
    max_node_count = var.node_pool_max_count
  }

  # Recreate nodes on K8s upgrades without downtime
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Spot nodes get drained with 30s notice — surge keeps capacity during upgrades
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = var.node_machine_type
    spot         = var.use_spot_nodes

    disk_size_gb = 50        # default 100 wastes credits; 50 fits images + emptyDir
    disk_type    = "pd-balanced"

    service_account = google_service_account.nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform" # IAM does the limiting, not scopes
    ]

    # Secure boot + integrity monitoring — free hardening
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA" # required for Workload Identity
    }

    labels = {
      pool        = "general"
      environment = var.environment
    }

  
    tags = ["gke-node", "${var.cluster_name}-node"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# NOTE on the spot taint: every workload we deploy (ArgoCD, MinIO, monitoring,
# vLLM) must tolerate it. The toleration is added once in each Helm values /
# manifest — this is intentional friction: it forces every component to
# DECLARE it can survive preemption. That declaration is the reliability story.
