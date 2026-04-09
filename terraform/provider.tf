# Provider AWS utilise par Terraform pour deployer l'infrastructure.
provider "aws" {
  region                   = var.region
  profile                  = var.aws_profile
  shared_config_files      = ["/home/llesage/.aws/config"]
  shared_credentials_files = ["/home/llesage/.aws/credentials"]



  # Tags communs appliques automatiquement a toutes les ressources AWS.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }
}
