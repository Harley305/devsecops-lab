module "network" {
  source = "./modules/network"

  name = "devsecops-lab"
  azs  = ["us-west-2a", "us-west-2b"]
}

module "storage" {
  source = "./modules/storage"

  name = "devsecops-lab"
  tags = local.tags
}

module "app" {
  source = "./modules/app"

  name        = "devsecops-lab"
  source_dir  = "${path.root}/../app"
  bucket_name = module.storage.bucket_name
  bucket_arn  = module.storage.bucket_arn
  tags        = local.tags
}

module "github_oidc" {
  source = "./modules/github-oidc"

  name        = "devsecops-lab"
  github_repo = "Harley305/devsecops-lab"
  tags        = local.tags
}

locals {
  tags = {
    Project     = "devsecops-lab"
    Owner       = "chris"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}