# ─────────────────────────────────────────────────────────────────────────────
# variables.tf — Inputs with types, defaults, and validation
#
# WHY VALIDATION BLOCKS: fail at `terraform plan`, not 20 minutes into apply.
# ─────────────────────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must be set (use terraform.tfvars)."
  }
}

variable "region" {
  description = "GCP region for the cluster and network"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "Single zone for the cluster. Zonal (not regional) is deliberate: a regional control plane triples node redundancy requirements and cost — wrong tradeoff for a portfolio/dev platform."
  type        = string
  default     = "asia-south1-a"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "ai-platform"
}

variable "environment" {
  description = "Environment label applied to all resources"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "node_machine_type" {
  description = "Machine type for the general-purpose node pool"
  type        = string
  default     = "e2-standard-4" # 4 vCPU / 16GB — fits monitoring stack + vLLM CPU smoke test
}

variable "node_pool_min_count" {
  description = "Minimum nodes in the general pool"
  type        = number
  default     = 1
}

variable "node_pool_max_count" {
  description = "Maximum nodes in the general pool. Ceiling protects credits from a runaway HPA/KEDA loop."
  type        = number
  default     = 3

  validation {
    condition     = var.node_pool_max_count <= 5
    error_message = "Max 5 nodes — this is a credit-funded dev platform. Raise deliberately, not accidentally."
  }
}

variable "use_spot_nodes" {
  description = "Use Spot VMs for the node pool (~60-91% discount). Workloads must tolerate preemption — which is itself part of the reliability story."
  type        = bool
  default     = true
}

variable "master_authorized_cidr" {
  description = "CIDR allowed to reach the GKE control plane. Default 0.0.0.0/0 for dev convenience — tighten to your IP (e.g. 1.2.3.4/32) as soon as you know it."
  type        = string
  default     = "0.0.0.0/0"
}
