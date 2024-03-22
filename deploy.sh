export TF_VAR_project_id=$(grep GCP_PROJECT env.yaml | awk '{print $2}')
export TF_VAR_sa_account=$(grep SA_ACCOUNT env.yaml | awk '{print $2}')
#export GOOGLE_APPLICATION_CREDENTIALS="/credentials.json"

terraform init
terraform fmt
terraform validate
terraform apply -auto-approve

# terraform destroy --auto-approve