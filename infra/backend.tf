# State lives in the S3 bucket created by bootstrap/, with native S3 locking.
# The bucket name is supplied at init time, once bootstrap has been applied:
#   terraform init -backend-config="bucket=<state_bucket_name output from bootstrap>"
terraform {
  backend "s3" {
    key          = "lab/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
