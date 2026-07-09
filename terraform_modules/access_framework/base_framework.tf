data "terraform_remote_state" "base_framework" {
  backend = "s3"

  config = {
    bucket         = "db-integrations-canaries"
    dynamodb_table = "db-integrations-canaries"
    key            = "foundations/terraform-states-backend.tfstate"
    region         = "us-east-1"
  }
}

data "aws_vpc" "base_vpc" {
  id = data.terraform_remote_state.base_framework.outputs.common_networking.aws_vpc.base_vpc.id
}
