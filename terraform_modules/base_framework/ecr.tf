resource "aws_ecr_repository" "falcon_sensor" {
  name = "falcon-sensor"
}

locals {
  testing_and_development_repositories = [
    "testing_and_development"
  ]
}

resource "aws_ecr_repository" "testing_and_development" {
  for_each = toset(local.testing_and_development_repositories)

  name = each.value
}

resource "aws_ecr_lifecycle_policy" "expire_tests" {
  for_each = aws_ecr_repository.testing_and_development

  repository = each.key

  // From the docs:
  // [!NOTE]
  //
  // Only one aws_ecr_lifecycle_policy resource can be used with the same ECR repository. To apply multiple rules,
  // they must be combined in the policy JSON.
  //
  // The AWS ECR API seems to reorder rules based on rulePriority. If you define multiple rules that are not
  // sorted in ascending rulePriority order in the Terraform code, the resource will be flagged for recreation every terraform plan.

  policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 100,
        "description" : "Expire untagged images older than 2 days",
        "selection" : {
          "tagStatus" : "untagged",
          "countType" : "sinceImagePushed",
          "countUnit" : "days",
          "countNumber" : 2
        },
        "action" : {
          "type" : "expire"
        }
      },
      {
        "rulePriority" : 200,
        "description" : "Expire tests and tilt builds older than a 3 weeks",
        "selection" : {
          "tagStatus" : "any",
          "countType" : "sinceImagePushed",
          "countUnit" : "days",
          "countNumber" : 21
        },
        "action" : {
          "type" : "expire"
        }
      },
    ]
  })
}

output "ecr" {
  value = {
    aws_ecr_repository = {
      falcon_sensor = {
        arn            = aws_ecr_repository.falcon_sensor.arn
        id             = aws_ecr_repository.falcon_sensor.id
        name           = aws_ecr_repository.falcon_sensor.name
        repository_url = aws_ecr_repository.falcon_sensor.repository_url
      }
      testing_and_development = {
        for k, v in aws_ecr_repository.testing_and_development : k => {
          arn            = v.arn
          id             = v.id
          name           = v.name
          repository_url = v.repository_url
        }
      }
    }
  }
}
