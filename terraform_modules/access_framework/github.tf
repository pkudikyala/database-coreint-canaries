locals {
  repositories_with_access = [
    "repo:newrelic/database-coreint-canaries:*",
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]
}

data "aws_iam_openid_connect_provider" "oidc" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_role_for_canaries" {
  name        = "github-role-for-canaries"
  description = "Role assumed by the GitHub OIDC provider for canaries"

  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect"    = "Allow",
        "Action"    = "sts:AssumeRoleWithWebIdentity",
        "Principal" = {
          "Federated" = data.aws_iam_openid_connect_provider.oidc.arn
        }
        "Condition" = {
          "StringEquals" = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com",
          }
          "ForAnyValue:StringLike" : {
            "token.actions.githubusercontent.com:sub" : local.repositories_with_access
          }
        }
      }
    ]
  })
}

locals {
  base_bucket  = data.terraform_remote_state.base_framework.config.bucket
  base_key     = data.terraform_remote_state.base_framework.outputs.tls_ca_and_ssh_keys.aws_key_pair.ssh_key_pair.key_name
  base_vpc_arn = data.aws_vpc.base_vpc.arn
}

resource "aws_iam_policy" "access_to_terraform_states" {
  name        = "access-to-terraform-states"
  description = "Allows storing and accessing tfstates"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${local.base_bucket}"]
        Action   = ["s3:ListBucket"]
      },
      {
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${local.base_bucket}/*"]
        Action   = ["s3:GetObject", "s3:PutObject"]
      },
      {
        Effect   = "Allow"
        Resource = ["arn:aws:dynamodb:*:*:table/${local.base_bucket}"]
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
      }
    ]
  })
}

resource "aws_iam_policy" "eks_canaries" {
  name        = "eks-canaries"
  description = "Allows managing EKS canary namespaces and Helm deployments"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:ListClusters",
          "eks:DescribeCluster",
          "eks:AccessKubernetesApi",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_role_terraform_states" {
  role       = aws_iam_role.github_role_for_canaries.name
  policy_arn = aws_iam_policy.access_to_terraform_states.arn
}

resource "aws_iam_role_policy_attachment" "github_role_eks" {
  role       = aws_iam_role.github_role_for_canaries.name
  policy_arn = aws_iam_policy.eks_canaries.arn
}

# Dev role — can be assumed locally by any IAM user in this account
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "dev_github_role_for_canaries" {
  name        = "dev-github-role-for-canaries"
  description = "Role assumed by IAM users in this account for local dev"

  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Action" = "sts:AssumeRole",
        "Principal" = {
          "AWS" : data.aws_caller_identity.current.account_id
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dev_role_terraform_states" {
  role       = aws_iam_role.dev_github_role_for_canaries.name
  policy_arn = aws_iam_policy.access_to_terraform_states.arn
}

resource "aws_iam_role_policy_attachment" "dev_role_eks" {
  role       = aws_iam_role.dev_github_role_for_canaries.name
  policy_arn = aws_iam_policy.eks_canaries.arn
}

output "github_runner" {
  value = {
    aws_iam_role = {
      github_role_for_canaries = {
        arn  = aws_iam_role.github_role_for_canaries.arn
        name = aws_iam_role.github_role_for_canaries.name
      }
      dev_github_role_for_canaries = {
        arn  = aws_iam_role.dev_github_role_for_canaries.arn
        name = aws_iam_role.dev_github_role_for_canaries.name
      }
    }
  }
}
