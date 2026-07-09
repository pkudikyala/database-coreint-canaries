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
    key            = "foundations/access_framework.tfstate"
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
