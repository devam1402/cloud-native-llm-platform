# ─────────────────────────────────────────────────────────────────────────────
# outputs.tf — What you need after apply, nothing else
# ─────────────────────────────────────────────────────────────────────────────

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.platform.name
}

output "cluster_endpoint" {
  description = "Control plane endpoint"
  value       = google_container_cluster.platform.endpoint
  sensitive   = true # keep it out of CI logs
}

output "kubeconfig_command" {
  description = "Run this to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.platform.name} --zone ${var.zone} --project ${var.project_id}"
}

output "node_service_account" {
  description = "Least-privilege SA the nodes run as"
  value       = google_service_account.nodes.email
}

output "network_name" {
  description = "Dedicated VPC name"
  value       = google_compute_network.platform.name
}
