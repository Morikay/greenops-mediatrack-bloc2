# -----------------------------------------------------------------------------
# Sources de donnees AWS
# -----------------------------------------------------------------------------

# Lit la premiere zone disponible de la region.
data "aws_availability_zones" "available" {
  state = "available"
}

# Recupere une image Ubuntu recente pour l'instance EC2.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Variables locales
# -----------------------------------------------------------------------------

locals {
  site_root  = "${path.module}/../site"
  site_files = fileset(local.site_root, "**")

  site_content_types = {
    css   = "text/css"
    html  = "text/html"
    ico   = "image/x-icon"
    jpg   = "image/jpeg"
    js    = "application/javascript"
    png   = "image/png"
    svg   = "image/svg+xml"
    ttf   = "font/ttf"
    woff  = "font/woff"
    woff2 = "font/woff2"
  }
}

# -----------------------------------------------------------------------------
# Valeurs partagees entre plusieurs ressources
# -----------------------------------------------------------------------------

# Ajoute un suffixe aleatoire pour rendre le nom du bucket unique.
resource "random_id" "suffix" {
  byte_length = 4
}

# -----------------------------------------------------------------------------
# Reseau
# -----------------------------------------------------------------------------

# Cree le reseau principal du projet.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Donne un acces Internet au VPC.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Cree un sous-reseau public pour l'instance EC2.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# Cree une route par defaut vers Internet.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associe la table de routage au sous-reseau public.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Acces SSH et securite reseau
# -----------------------------------------------------------------------------

# Ouvre SSH depuis votre IP et HTTP/HTTPS pour le serveur web de demonstration.
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "SSH limite et HTTP public pour Nginx"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "Administration SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP pour le serveur web de demonstration"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS pour le serveur web de demonstration"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# -----------------------------------------------------------------------------
# Cle SSH et instance EC2
# -----------------------------------------------------------------------------

# Genere une paire de cles pour l'acces SSH a l'EC2.
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Sauvegarde la cle privee en local.
resource "local_file" "private_key_pem" {
  content         = tls_private_key.ec2.private_key_pem
  filename        = "${path.module}/${var.project_name}-ec2.pem"
  file_permission = "0600"
}

# Importe la cle publique dans AWS.
resource "aws_key_pair" "ec2" {
  key_name   = "${var.project_name}-${random_id.suffix.hex}-key"
  public_key = tls_private_key.ec2.public_key_openssh
}

# Cree l'instance EC2 legere pour le serveur web.
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

# -----------------------------------------------------------------------------
# Stockage S3 du site statique
# -----------------------------------------------------------------------------

# Cree le bucket S3 prive qui stocke les fichiers statiques.
resource "aws_s3_bucket" "site" {
  bucket        = "${var.project_name}-${random_id.suffix.hex}"
  force_destroy = true
}

# Force la propriete des objets par le bucket.
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bloque tout acces public direct au bucket.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Active le chiffrement S3 cote serveur.
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Active la versioning du bucket pour la tracabilite.
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Publie tout le contenu du dossier site/ vers S3.
resource "aws_s3_object" "site_files" {
  for_each = {
    for file in local.site_files :
    file => file
    if !endswith(file, "/") && !strcontains(file, "?")
  }

  bucket       = aws_s3_bucket.site.id
  key          = each.value
  source       = "${local.site_root}/${each.value}"
  etag         = filemd5("${local.site_root}/${each.value}")
  content_type = lookup(local.site_content_types, reverse(split(".", each.value))[0], "application/octet-stream")

  depends_on = [aws_s3_bucket_ownership_controls.site]
}

# -----------------------------------------------------------------------------
# Diffusion publique via CloudFront
# -----------------------------------------------------------------------------

# Autorise CloudFront a lire le bucket prive.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  description                       = "Acces securise au bucket S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Place CloudFront devant le bucket S3 et force le HTTPS.
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  wait_for_deployment = true

  lifecycle {
    # Le provider AWS remonte un drift persistant sur l'origine S3 et le
    # protocole minimum du certificat CloudFront par defaut, alors que la
    # distribution fonctionne deja correctement.
    ignore_changes = [
      origin,
      viewer_certificate[0].minimum_protocol_version,
    ]
  }

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}

# -----------------------------------------------------------------------------
# Politique d'acces S3 pour CloudFront
# -----------------------------------------------------------------------------

# Le bucket n'est accessible qu'a la distribution CloudFront.
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      }
    ]
  })
}
