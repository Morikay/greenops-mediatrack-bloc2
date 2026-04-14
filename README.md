# GreenOps MediTrack - Bloc 2

Projet de formation DevOps pour automatiser le deploiement d'une application backend conteneurisee sur AWS, en reutilisant le socle de l'etude de cas 1.

## Objectif

Ce projet repond a une etude de cas orientee conteneurisation et mise en production cloud avec les objectifs suivants :

- construire une image Docker pour une API Node.js ;
- publier cette image dans un depot ECR prive ;
- deployer une base PostgreSQL sur RDS ;
- deployer l'API sur ECS Fargate ;
- exposer l'API via un Application Load Balancer public ;
- appliquer un cloisonnement reseau simple et coherent.

## Logique generale

Le Bloc 2 part du socle Terraform du Bloc 1 et l'etend pour ajouter une plateforme API :

- le VPC existant est reutilise ;
- de nouveaux sous-reseaux prives sont ajoutes pour ECS et RDS ;
- un NAT Gateway permet aux taches Fargate en sous-reseau prive de recuperer l'image Docker et d'ecrire les logs ;
- l'API est construite localement depuis `api-backend/` ;
- le depot ECR est cree manuellement via AWS CLI ;
- l'image est poussee dans ECR avec Docker ;
- ECS Fargate consomme cette image et dialogue avec PostgreSQL ;
- l'ALB fournit le point d'entree HTTP public vers l'API.

## Architecture cible

- `VPC existant` : socle reseau repris du Bloc 1.
- `2 sous-reseaux publics` : instance EC2 existante et ALB public.
- `2 sous-reseaux prives` : taches ECS et base RDS.
- `ECR` : stockage prive de l'image Docker.
- `RDS PostgreSQL db.t3.micro` : base de donnees relationnelle privee.
- `ECS Fargate` : execution de l'API sans gerer de serveur applicatif.
- `ALB` : publication HTTP de l'API.
- `Secrets Manager` : stockage du mot de passe base de donnees.
- `CloudWatch Logs` : collecte des logs du conteneur.

## Etat actuel du projet

Le Bloc 2 est maintenant deploye et verifie sur AWS. Les ressources principales creees et validees sont :

- depot ECR : `691317218548.dkr.ecr.eu-west-3.amazonaws.com/greenops-mediatrack-api`
- base RDS PostgreSQL : `greenops-mediatrack-postgres.cr6s406e2tq2.eu-west-3.rds.amazonaws.com`
- cluster ECS : `greenops-mediatrack-cluster`
- service ECS : `greenops-mediatrack-api-service`
- ALB public : `http://greenops-mediatrack-alb-850454209.eu-west-3.elb.amazonaws.com`

Les tests fonctionnels reussis sont :

- `GET /` -> `200 OK`
- `GET /contacts` -> `200 OK`
- `POST /contact` -> `201 Created`

Le service ECS est actif, la target ALB est `healthy` et la table `contacts` est bien creee dans PostgreSQL.

Le socle Bloc 1 de reference reste deploye avec :

- URL CloudFront : `https://difzkce0aqf6s.cloudfront.net`
- EC2 DNS public : `ec2-51-44-86-157.eu-west-3.compute.amazonaws.com`
- Bucket S3 : `greenops-mediatrack-af18a78a`

## Arborescence reelle

```text
.
├── ansible/
│   ├── ansible.cfg
│   ├── inventory.ini
│   ├── playbook.yml
│   └── templates/
│       └── meditrack-nginx.conf.j2
├── api-backend/
│   ├── Dockerfile
│   ├── index.js
│   └── package.json
├── site/
│   ├── assets/
│   ├── contact.html
│   └── index.html
└── terraform/
    ├── api_platform.tf
    ├── main.tf
    ├── outputs.tf
    ├── provider.tf
    ├── variables.tf
    └── version.tf
```

## Role des dossiers

- `terraform/` : creation de l'infrastructure AWS du Bloc 1 et des extensions Bloc 2.
- `api-backend/` : code source de l'API Node.js et Dockerfile.
- `ansible/` : configuration de l'instance EC2 du Bloc 1.
- `site/` : site statique du Bloc 1.

## Fichiers Terraform Bloc 2

- [main.tf](/home/llesage/greenops-mediatrack-bloc2/terraform/main.tf) : socle d'infrastructure du Bloc 1.
- [api_platform.tf](/home/llesage/greenops-mediatrack-bloc2/terraform/api_platform.tf) : ressources specifiques au Bloc 2, notamment RDS, ECS, ALB, NAT et sous-reseaux prives.
- [variables.tf](/home/llesage/greenops-mediatrack-bloc2/terraform/variables.tf) : variables communes et variables du Bloc 2.
- [provider.tf](/home/llesage/greenops-mediatrack-bloc2/terraform/provider.tf) : provider AWS, region et profil local.
- [outputs.tf](/home/llesage/greenops-mediatrack-bloc2/terraform/outputs.tf) : valeurs utiles apres deploiement, comme l'endpoint RDS et le DNS de l'ALB.
- [version.tf](/home/llesage/greenops-mediatrack-bloc2/terraform/version.tf) : version minimale de Terraform et des providers.

## Fichiers API

- [package.json](/home/llesage/greenops-mediatrack-bloc2/api-backend/package.json) : dependances Node.js de l'API.
- [index.js](/home/llesage/greenops-mediatrack-bloc2/api-backend/index.js) : logique de l'API Express et acces PostgreSQL.
- [Dockerfile](/home/llesage/greenops-mediatrack-bloc2/api-backend/Dockerfile) : construction de l'image conteneur.

## Prerequis

- Terraform 1.5 ou plus
- AWS CLI
- Docker
- un profil AWS CLI local fonctionnel
- les droits IAM necessaires pour ECR, ECS, ELBv2, RDS, IAM, Secrets Manager, CloudWatch Logs, EC2 et VPC

## Authentification AWS

Terraform utilise le provider AWS declare dans [provider.tf](/home/llesage/greenops-mediatrack-bloc2/terraform/provider.tf) avec :

- la region `eu-west-3`
- le profil local `greenops`
- les fichiers AWS locaux :
  - `/home/llesage/.aws/config`
  - `/home/llesage/.aws/credentials`

Le profil local `greenops` pointe vers l'utilisateur IAM AWS `greenops-mediatrack-deployer`.

## Sequence de deploiement recommandee

### 1. Verifier Terraform

Contexte : machine locale, dossier `/home/llesage/greenops-mediatrack-bloc2/terraform`

```bash
cd /home/llesage/greenops-mediatrack-bloc2/terraform
HOME=/home/llesage terraform init
HOME=/home/llesage terraform validate
HOME=/home/llesage terraform plan
```

### 2. Creer le depot ECR en AWS CLI

```bash
HOME=/home/llesage aws ecr create-repository \
  --repository-name greenops-mediatrack-api \
  --image-tag-mutability MUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --profile greenops \
  --region eu-west-3
```

### 3. Construire et pousser l'image Docker

Exemple de sequence :

```bash
HOME=/home/llesage aws ecr get-login-password --profile greenops --region eu-west-3 | docker login --username AWS --password-stdin 691317218548.dkr.ecr.eu-west-3.amazonaws.com
cd /home/llesage/greenops-mediatrack-bloc2/api-backend
docker build -t meditrack-api:v1 .
docker tag meditrack-api:v1 691317218548.dkr.ecr.eu-west-3.amazonaws.com/greenops-mediatrack-api:v1
docker push 691317218548.dkr.ecr.eu-west-3.amazonaws.com/greenops-mediatrack-api:v1
```

### 4. Deployer l'infrastructure complete

```bash
cd /home/llesage/greenops-mediatrack-bloc2/terraform
HOME=/home/llesage terraform apply
```

### 5. Verifier l'API

Une fois l'ALB et ECS actifs, tester :

- `GET /`
- `GET /contacts`
- `POST /contact`

Exemple de tests reussis :

```bash
curl http://greenops-mediatrack-alb-850454209.eu-west-3.elb.amazonaws.com/
curl http://greenops-mediatrack-alb-850454209.eu-west-3.elb.amazonaws.com/contacts
curl -X POST http://greenops-mediatrack-alb-850454209.eu-west-3.elb.amazonaws.com/contact \
  -H 'Content-Type: application/json' \
  -d '{"nom":"Test User","email":"test@example.com","message":"Bonjour depuis ECS"}'
```

## Securite mise en oeuvre

- ALB public uniquement sur le port `80`
- ECS accessible uniquement depuis le security group de l'ALB sur le port `3000`
- RDS accessible uniquement depuis le security group ECS sur le port `5432`
- RDS non public
- secrets de base de donnees stockes dans Secrets Manager
- logs conteneur dans CloudWatch
- chiffrement S3 et EBS deja herites du Bloc 1

## Point de vigilance important

Ce dossier Bloc 2 est separe du Bloc 1 sur le plan du code, mais il reutilise le socle d'infrastructure Terraform issu du Bloc 1. Un `terraform apply` Bloc 2 ajoute donc des ressources autour de ce socle et peut mettre a jour certains elements communs si les variables diffèrent.

Un drift residuel CloudFront existait au depart sur le socle Bloc 1. Il a ete neutralise dans [main.tf](/home/llesage/greenops-mediatrack-bloc2/terraform/main.tf). Il reste toutefois un ecart recurrent sur la configuration de chiffrement S3 du socle statique, qui n'affecte pas le fonctionnement du Bloc 2.

Le depot ECR n'est plus gere par Terraform dans cette version du projet. Il est cree manuellement via AWS CLI, puis son URL est fournie a Terraform via `terraform.tfvars`.

## Fichiers sensibles

Ces fichiers ne doivent pas etre publies dans un depot public :

- `terraform/terraform.tfstate`
- `terraform/terraform.tfstate.backup`
- `terraform/greenops-mediatrack-ec2.pem`
- tout fichier `terraform.tfvars` local

Si une cle ou un secret a deja ete expose, il faut le regenerer.
