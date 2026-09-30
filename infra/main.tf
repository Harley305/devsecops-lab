module "network" {
  source = "./modules/network"

  name = "devsecops-lab"
  azs  = ["us-west-2a", "us-west-2b"]
}

module "storage" {
  source = "./modules/storage"

  name = "devsecops-lab"
}
