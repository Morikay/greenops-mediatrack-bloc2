# Profil AWS local utilise par Terraform.
variable "aws_profile" {
  type    = string
  default = "greenops"
}

# Region AWS cible.
variable "region" {
  type    = string
  default = "eu-west-3"
}

# Prefixe simple reutilise pour les ressources.
variable "project_name" {
  type    = string
  default = "greenops-mediatrack"
}

# Reseau du VPC.
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# Reseau du sous-reseau public.
variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

# Second sous-reseau public pour l'ALB.
variable "public_subnet_b_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

# Sous-reseaux prives pour ECS et RDS.
variable "private_subnet_a_cidr" {
  type    = string
  default = "10.0.10.0/24"
}

variable "private_subnet_b_cidr" {
  type    = string
  default = "10.0.11.0/24"
}

# Type d'instance EC2.
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# Taille du volume racine EBS en Go.
variable "root_volume_size" {
  type    = number
  default = 8
}

# Niveau de couverture geographique de CloudFront.
variable "cloudfront_price_class" {
  type    = string
  default = "PriceClass_100"
}

# Adresse autorisee a se connecter en SSH.
variable "allowed_ssh_cidr" {
  type    = string
  default = "235.235.235.235/32"
}

# Tag de l'image Docker poussee vers ECR.
variable "api_image_tag" {
  type    = string
  default = "v1"
}

# URL du depot ECR prive cree manuellement via AWS CLI ou console.
variable "ecr_repository_url" {
  type = string
}

# Nombre de taches ECS desirees.
variable "ecs_desired_count" {
  type    = number
  default = 1
}

# Nom de la base PostgreSQL.
variable "db_name" {
  type    = string
  default = "meditrack"
}

# Utilisateur applicatif PostgreSQL.
variable "db_username" {
  type    = string
  default = "meditrackapp"
}
