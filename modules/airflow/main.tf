terraform {
  # FIX for terraform_required_version
  required_version = ">= 1.11.0"

  # FIX for terraform_required_providers
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

resource "google_project_service" "container" {
  project            = var.project_name
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "airflow_sa" {
  project    = var.project_name
  account_id = "${var.project_name}-airflow-sa"
}

resource "google_project_iam_member" "airflow_dataproc_editor" {
  project = var.project_name
  role    = "roles/dataproc.editor"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_project_iam_member" "airflow_sa_user" {
  project = var.project_name
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_project_iam_member" "airflow_storage" {
  project = var.project_name
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

resource "google_container_cluster" "airflow" {
  #checkov:skip=CKV_GCP_91: "Workshop cluster — CSEK not needed"
  #checkov:skip=CKV_GCP_24: "Workshop cluster — PodSecurityPolicy not needed"
  #checkov:skip=CKV_GCP_25: "Workshop cluster — private cluster not required"
  #checkov:skip=CKV_GCP_18: "Workshop cluster — master auth networks not required"
  #checkov:skip=CKV_GCP_12: "Workshop cluster — network policy not required"
  #checkov:skip=CKV_GCP_23: "Workshop cluster — alias IPs not required"
  #checkov:skip=CKV_GCP_20: "Workshop cluster — Google Groups for RBAC/Master Auth not available"
  #checkov:skip=CKV_GCP_64: "Workshop cluster — Private nodes not used to avoid Cloud NAT costs"
  #checkov:skip=CKV_GCP_65: "Workshop cluster — Google Groups for GKE not available"
  #checkov:skip=CKV_GCP_13: "Workshop cluster — Binary Authorization not required"
  depends_on = [google_project_service.container]

  name     = "airflow-cluster"
  project  = var.project_name
  location = "${var.region}-b"

  #Fix CKV_GCP_21
  resource_labels = {
    env     = "workshop"
    project = "tbd"
    user    = "blagoja"
  }

  # FIX for CKV_GCP_70: Release Channel
  release_channel {
    channel = "REGULAR"
  }

  # FIX for CKV_GCP_66: Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # FIX for CKV_GCP_69: Workload Identity / Metadata Server
  node_config {
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    # FIX for CKV_GCP_68: Secure Boot
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # FIX for CKV_GCP_61: Intranode Visibility
  enable_intranode_visibility = true

  # Use Standard mode (not Autopilot) to avoid SSD quota issues
  initial_node_count       = 1
  remove_default_node_pool = true

  network    = var.network
  subnetwork = var.subnet

  deletion_protection = false
}

resource "google_container_node_pool" "airflow_nodes" {
  name     = "airflow-pool"
  project  = var.project_name
  location = "${var.region}-b"
  cluster  = google_container_cluster.airflow.name

  node_count = 2

  # FIX BOTH CKV_GCP_9 and CKV_GCP_10
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  lifecycle {
    ignore_changes = [node_config]
  }

  node_config {
    machine_type    = var.machine_type
    service_account = google_service_account.airflow_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    disk_type    = "pd-standard"
    disk_size_gb = 50

    # FIX for CKV_GCP_68: Secure Boot
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
