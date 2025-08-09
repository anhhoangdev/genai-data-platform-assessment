# Phase-0 Deployment Checklist

## Pre-Deployment Requirements

### ✅ Prerequisites
- [ ] GCP Project created with billing enabled
- [ ] GitHub repository set up
- [ ] Local environment with Terraform >= 1.6
- [ ] gcloud CLI authenticated

### ✅ Configuration Files
- [ ] Copy `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Update `project_id` in terraform.tfvars
- [ ] Update `wif.attribute_condition` with your GitHub repo
- [ ] (Optional) Configure custom networking CIDRs

### ✅ Terraform State Backend
- [ ] Create GCS bucket for state: `gsutil mb gs://your-project-terraform-state`
- [ ] Enable versioning: `gsutil versioning set on gs://your-project-terraform-state`
- [ ] Update `backend.tf` with bucket name
- [ ] Run `terraform init -migrate-state`

## Deployment Steps

### ✅ Phase-0 Bootstrap
```bash
cd terraform/envs/dev
terraform init
terraform plan    # Review the plan
terraform apply   # Deploy foundation
```

### ✅ Post-Deployment Validation

**Verify APIs are enabled:**
```bash
gcloud services list --enabled --filter="name:iam.googleapis.com OR name:secretmanager.googleapis.com OR name:cloudkms.googleapis.com"
```

**Verify VPC and subnets:**
```bash
gcloud compute networks list --filter="name:vpc-data-platform"
gcloud compute networks subnets list --filter="region:us-central1"
```

**Verify firewall rules:**
```bash
gcloud compute firewall-rules list --filter="network:vpc-data-platform"
```

**Verify secrets:**
```bash
gcloud secrets list
```

**Verify KMS:**
```bash
gcloud kms keyrings list --location=us-central1
gcloud kms keys list --keyring=sec-core --location=us-central1
```

### ✅ GitHub Actions Setup

**Get outputs from Terraform:**
```bash
terraform output wif_provider_name
terraform output tf_cicd_service_account_email
```

**Configure GitHub repository secrets:**
- `WIF_PROVIDER`: Copy output from `wif_provider_name`
- `WIF_SERVICE_ACCOUNT`: Copy output from `tf_cicd_service_account_email`

**Test GitHub Actions:**
- [ ] Create a test PR modifying any Terraform file
- [ ] Verify plan runs successfully
- [ ] Merge to main branch
- [ ] Verify apply runs successfully

## Post-Bootstrap Security

### ✅ Service Account Permission Reduction
After successful deployment, reduce the Terraform service account permissions:

```bash
# Remove broad admin roles
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:tf-cicd@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.admin"

gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:tf-cicd@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudkms.admin"

# Add scoped operational roles
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:tf-cicd@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:tf-cicd@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"
```

## Phase-1 Preparation

The Phase-0 foundation is now ready for Phase-1 resources:

### ✅ Available for Phase-1
- Secure VPC with private subnets
- CMEK-encrypted secrets in Secret Manager
- Workload Identity Federation for CI/CD
- Firewall rules prepared for FreeIPA and bastion access
- Private DNS zone ready for service records

### ✅ Phase-1 TODO Items
- [ ] Add Filestore NFS module and instance
- [ ] Add bastion VM with IAP access
- [ ] Add FreeIPA server VM with static IP
- [ ] Add worker VM template and MIG
- [ ] Add DNS records for services
- [ ] Configure FreeIPA DNS forwarding (optional)
- [ ] Add Ansible configuration management

### ✅ Phase-1 Terraform Outputs Available
```bash
terraform output phase_1_inputs
```

This output provides all the resource IDs and names needed for Phase-1 modules.

## Success Criteria

Phase-0 is successfully deployed when:

✅ All Terraform modules apply without errors  
✅ GitHub Actions workflow runs plan and apply successfully  
✅ All required GCP APIs are enabled  
✅ VPC, subnets, and firewall rules are created  
✅ KMS keys and CMEK-encrypted secrets exist  
✅ Workload Identity Federation authenticates from GitHub  
✅ Cloud NAT provides egress for private subnets  
✅ Private DNS zone ready for service records  
✅ No service account keys present in the environment  

**Ready for Phase-1 deployment! 🚀**
