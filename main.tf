module "tags" {
  source          = "./modules/tags"
  application     = "flights-stackoverflow-answers"
  project         = "eks-cluster"
  team            = "infrastructure"
  environment     = "alpha"
  owner           = "giraffeman123"
  project_version = "1.0"
  contact         = "giraffeman123@gmail.com"
  cost_center     = "35009"
  sensitive       = false
}

# module "imported-vpc" {
#   source = "./modules/imported-vpc"
#   vpc_id = var.vpc_id
# }

module "vpc" {
  source                     = "./modules/new-vpc"
  mandatory_tags             = module.tags.mandatory_tags
  vpc_cidr_block             = "10.0.0.0/16"
  public_subnets_cidr_block  = ["10.0.0.0/20", "10.0.128.0/20"]
  private_subnets_cidr_block = ["10.0.16.0/20", "10.0.144.0/20"]

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.constructed_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                                  = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.constructed_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"                         = 1
  }
}

module "pipelines" {
  source         = "./modules/pipelines"
  mandatory_tags = module.tags.mandatory_tags
  name           = "fsa"

  fsa_api_docker_image_name        = "fsa-api"
  fsa_api_repository_url           = "giraffeman123/fsa-api"
  fsa_api_repository_branch        = "main"
  fsa_api_repository_provider_type = "GitHub"

  fsa_webapp_docker_image_name        = "fsa-webapp"
  fsa_webapp_repository_url           = "giraffeman123/fsa-webapp"
  fsa_webapp_repository_branch        = "main"
  fsa_webapp_repository_provider_type = "GitHub"

  fsa_stack_git_credentials_secret = var.fsa_stack_git_credentials_secret
}

module "rds" {
  source                     = "./modules/rds"
  mandatory_tags             = module.tags.mandatory_tags
  vpc_id                     = module.vpc.vpc_id
  private_subnets_ids        = module.vpc.private_subnets_ids
  private_subnets_cidr_block = module.vpc.private_subnets_cidr_block
  db_credentials_secret      = var.db_credentials_secret
  db_port                    = 3306
}

module "eks_cluster" {
  source          = "./modules/eks-cluster"
  mandatory_tags  = module.tags.mandatory_tags
  cluster_name    = local.constructed_cluster_name
  cluster_version = "1.26"

  vpc_id              = module.vpc.vpc_id
  private_subnets_ids = module.vpc.private_subnets_ids
  main_domain_name    = var.main_domain_name
  website_domain      = var.website_domain
  argocd_domain       = var.argocd_domain
}