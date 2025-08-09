# Backend configuration for Terraform state
# Configure this after creating a GCS bucket for state storage

terraform {
  backend "gcs" {
    # bucket = "your-terraform-state-bucket"
    # prefix = "envs/dev"
  }
}

# Uncomment and configure the backend after creating state storage:
# 1. Create a GCS bucket: gsutil mb gs://your-project-terraform-state
# 2. Enable versioning: gsutil versioning set on gs://your-project-terraform-state
# 3. Uncomment the bucket line above and set your bucket name
# 4. Run: terraform init -migrate-state
