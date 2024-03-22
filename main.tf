terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.69.1"
    }
  }
}

provider "google" {
  credentials = file("credentials.json")

  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_storage_project_service_account" "default" {
}

# Used to retrieve project information
data "google_project" "project" {}

variable "GCP_SERVICES" {
  type        = list(string)
  description = "The list of apis necessary for the project"
  default = [
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "bigquery.googleapis.com",
    "workflows.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ]
}

resource "google_project_service" "gcp_services" {
  for_each = toset(var.GCP_SERVICES)
  service  = each.value
}


resource "google_project_iam_member" "gcs_pubsub_publishing" {
  project = data.google_project.project.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.default.email_address}"
}

resource "google_service_account" "account" {
  account_id   = "gcf-sa"
  display_name = "Test Service Account - used for both the cloud function and eventarc trigger in the test"
}

variable "GCP_ROLES" {
  type = list(string)
  default = [
    "roles/iam.serviceAccountUser",
    "roles/run.invoker",
    "roles/workflows.invoker",
    "roles/eventarc.eventReceiver",
    "roles/pubsub.publisher",
    "roles/artifactregistry.reader"
  ]
}

resource "google_project_iam_member" "main_sa_roles" {
  project  = data.google_project.project.id
  for_each = toset(var.GCP_ROLES)
  role     = each.value
  member   = "serviceAccount:${google_service_account.account.email}"
  #"serviceAccount:${var.project_id}@${var.project_id}.iam.gserviceaccount.com}"
}

# Cloud Storage bucket names must be globally unique
resource "random_id" "bucket_name_suffix" {
  byte_length = 4
}

# Create new storage bucket in the US multi-region
# with standard storage

resource "google_storage_bucket" "adjlist_bucket" {
  name          = "adjlist-${data.google_project.project.name}"
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  labels = {
    env = "dev"
  }
}

# Upload a text file as an object
# to the storage bucket

#resource "google_storage_bucket_object" "default" {
#  name         = "network.adjlist"
#  source       = "files/network.adjlist"
#  content_type = "text/plain"
#  bucket       = google_storage_bucket.adjlist.id
#}

resource "google_storage_bucket" "visits_bucket" {
  name          = "visits-${data.google_project.project.name}"
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  labels = {
    env = "dev"
  }
}

# Upload a text file as an object
# to the storage bucket

#resource "google_storage_bucket_object" "visits" {
#  name         = "network.visits"
#  source       = "files/visits.adjlist"
#  content_type = "text/plain"
#  bucket       = google_storage_bucket.visits.id
#}

# now you can grab the entire lambda source directory or specific subdirectories
data "archive_file" "visits_zip" {
  type        = "zip"
  output_path = "visits_function.zip"
  source_dir  = "${path.module}/cloud_functions/visits_to_bq/"
}

resource "google_storage_bucket" "visits_fn_bucket" {
  name                        = "visits_fn_bucket-gcf-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "visits_fn_object" {
  name   = "visits_function.zip"
  bucket = google_storage_bucket.visits_fn_bucket.name
  source = data.archive_file.visits_zip.output_path # Add path to the zipped function source code
}

resource "google_cloudfunctions2_function" "visits_function" {
  depends_on = [
    google_project_iam_member.main_sa_roles
  ]
  name        = "visits-to-bq"
  location    = var.region
  description = "This function load file from a bucket which will receive visits info in CSV format."

  build_config {
    runtime     = "python38"
    entry_point = "visits_to_bq" # Set the entry point

    source {
      storage_source {
        bucket = google_storage_bucket.visits_fn_bucket.name
        object = google_storage_bucket_object.visits_fn_object.name
      }
    }
  }
  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60

    environment_variables = {
      DATASET       = "node_management"
      TABLE_NAME    = "visits_data"
      PARTITION_COL = "visit_date:"
    }
  }
  event_trigger {
    trigger_region = var.region # The trigger must be in the same location as the bucket
    event_type     = "google.cloud.storage.object.v1.finalized"
    retry_policy   = "RETRY_POLICY_RETRY"
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.visits_bucket.name
    }
  }
}

output "visits_function_uri" {
  value = google_cloudfunctions2_function.visits_function.service_config[0].uri
}


# now you can grab the entire lambda source directory or specific subdirectories
data "archive_file" "adjlist_zip" {
  type        = "zip"
  output_path = "adjlist_function.zip"
  source_dir  = "${path.module}/cloud_functions/adjlist_to_bq/"
}

resource "google_storage_bucket" "adjlist_fn_bucket" {
  name                        = "adjlist_fn_bucket-gcf-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "adjlist_fn_object" {
  name   = "adjlist_function.zip"
  bucket = google_storage_bucket.adjlist_fn_bucket.name
  source = data.archive_file.adjlist_zip.output_path # Add path to the zipped function source code
}

resource "google_cloudfunctions2_function" "adjlist_function" {
  depends_on = [
    google_project_iam_member.main_sa_roles
  ]
  name        = "adjlist-to-bq"
  location    = var.region
  description = "This function load file from a bucket which will receive adjlist info in CSV format."

  build_config {
    runtime     = "python38"
    entry_point = "adjlist_to_bq" # Set the entry point
    source {
      storage_source {
        bucket = google_storage_bucket.adjlist_fn_bucket.name
        object = google_storage_bucket_object.adjlist_fn_object.name
      }
    }
  }
  service_config {
    min_instance_count = 0
    max_instance_count = 10
    available_memory   = "512Mi"
    timeout_seconds    = 600

    environment_variables = {
      DATASET    = "node_management"
      TABLE_NAME = "adjlist_data"
    }
  }
  event_trigger {
    trigger_region = var.region # The trigger must be in the same location as the bucket
    event_type     = "google.cloud.storage.object.v1.finalized"
    retry_policy   = "RETRY_POLICY_RETRY"
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.adjlist_bucket.name
    }
  }
}

output "adjlist_function_uri" {
  value = google_cloudfunctions2_function.adjlist_function.service_config[0].uri
}

resource "google_bigquery_dataset" "my_dataset" {
  dataset_id    = "node_management"
  friendly_name = "Dataset Name"
  location      = var.location # Adjust location as needed

  # Optional configurations
  description = "This is a dataset for storing node_management data."
  # default_table_expiration_ms = 3600000  # 1 hour in milliseconds
  labels = {
    env = "dev"
  }
}
