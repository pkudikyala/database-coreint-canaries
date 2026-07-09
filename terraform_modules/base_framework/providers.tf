terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.48"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.2"
    }
  }

  backend "s3" {
    bucket         = "db-integrations-canaries"
    dynamodb_table = "db-integrations-canaries"
    key            = "foundations/terraform-states-backend.tfstate"
    region         = "us-east-1"
  }
}

provider "tls" {}

provider "cloudinit" {}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      "owning_team" = "database-integrations"
      "purpose"     = "development-db-integrations-environments"
    }
  }
}

data "aws_region" "current" {}
