variable "canary_name" {
  type    = string
  default = "Database_Integration_Canaries"
}

variable "base_vpc_id" {
  type    = string
  default = ""
}

variable "base_subnet_ids" {
  default = []
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "aws_eks_addon_version" {
  description = "aws-ebs-csi-driver addon version"
  type        = string
  default     = "v1.29.1-eksbuild.1"
}

variable "nodes_instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "nodes_ami_type" {
  type    = string
  default = "AL2_x86_64"
}

variable "node_volume_size" {
  type    = number
  default = 20
}

variable "cluster_desired_size" {
  type    = number
  default = 4
}

variable "cluster_max_size" {
  type    = number
  default = 8
}

variable "cluster_min_size" {
  type    = number
  default = 1
}

variable "stable_group_desired_size" {
  type    = number
  default = 2
}

variable "stable_group_max_size" {
  type    = number
  default = 4
}

variable "stable_group_min_size" {
  type    = number
  default = 1
}

variable "candidate_group_desired_size" {
  type    = number
  default = 2
}

variable "candidate_group_max_size" {
  type    = number
  default = 4
}

variable "candidate_group_min_size" {
  type    = number
  default = 1
}

variable "fargate_iam_role_arn" {
  description = "ARN of the Fargate runner IAM role"
  type        = string
  default     = "arn:aws:iam::997831524462:role/test_prerelease_fargate-zke"
}

variable "fargate_iam_role_user" {
  description = "RBAC user for the IAM role"
  type        = string
  default     = "fargate-user"
}

variable "subnet_ids_nodegroup" {
  type    = list(string)
  default = []
}

variable "subnet_ids_stable" {
  type    = list(string)
  default = []
}

variable "subnet_ids_candidate" {
  type    = list(string)
  default = []
}
