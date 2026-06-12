# ─────────────────────────────────────────────────────────────────────────────
# network.tf — Dedicated VPC + subnet with secondary ranges
#
# WHY NOT THE DEFAULT VPC: the default network is a junk drawer with
# auto-created subnets in every region and permissive firewall rules.
# A dedicated VPC is isolation, intent, and an interview answer.
#
# WHY SECONDARY RANGES: VPC-native (alias IP) clusters route pod/service
# traffic natively — required for the cleanest GKE networking mode.
# ─────────────────────────────────────────────────────────────────────────────

resource "google_compute_network" "platform" {
  name                    = "${var.cluster_name}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false # explicit subnets only
}

resource "google_compute_subnetwork" "platform" {
  name    = "${var.cluster_name}-subnet"
  project = var.project_id
  region  = var.region
  network = google_compute_network.platform.id

  ip_cidr_range = "10.10.0.0/20" # nodes: ~4k addresses, plenty

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16" # pods
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20" # services
  }

  # Flow logs OFF — they cost money and a dev platform doesn't need them.
  # Documented absence > silent default.
}

# Egress for spot nodes pulling images / models from the internet.
# Cloud NAT means nodes need no public IPs — smaller attack surface.
resource "google_compute_router" "platform" {
  name    = "${var.cluster_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.platform.id
}

resource "google_compute_router_nat" "platform" {
  name                               = "${var.cluster_name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.platform.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY" # log failures, not every packet
  }
}
