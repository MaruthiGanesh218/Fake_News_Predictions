# NEWS CHUNK 10 — Deployment & Verification Automation
# Author: GPT-5 Codecs (acting as a 30-40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.84.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "Google Cloud project identifier"
  type        = string
}

variable "region" {
  description = "Deployment region (e.g. us-central1)"
  type        = string
  default     = "us-central1"
}

variable "backend_image" {
  description = "Container image for the backend Cloud Run service"
  type        = string
}

variable "frontend_image" {
  description = "Container image for the frontend Cloud Run service"
  type        = string
}

resource "google_cloud_run_service" "backend" {
  name     = "fake-news-backend"
  location = var.region

  template {
    spec {
      containers {
        image = var.backend_image
        ports {
          container_port = 8000
        }
        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
      container_concurrency = 80
      timeout_seconds       = 60
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_member" "backend_public" {
  location = google_cloud_run_service.backend.location
  project  = var.project_id
  service  = google_cloud_run_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_service" "frontend" {
  name     = "fake-news-frontend"
  location = var.region

  template {
    spec {
      containers {
        image = var.frontend_image
        ports {
          container_port = 8080
        }
        resources {
          limits = {
            cpu    = "1"
            memory = "256Mi"
          }
        }
      }
      container_concurrency = 150
      timeout_seconds       = 30
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_member" "frontend_public" {
  location = google_cloud_run_service.frontend.location
  project  = var.project_id
  service  = google_cloud_run_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
