terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }

  backend "s3" {
    bucket         = "db-integrations-canaries"
    dynamodb_table = "db-integrations-canaries"
    key            = "foundations/state_framework.tfstate"
    region         = "us-east-1"
  }
}

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

module "state_backend" {
  source              = "../modules/state_backend"
  bucket_name         = "db-integrations-canaries"
  dynamodb_table_name = "db-integrations-canaries"
}
