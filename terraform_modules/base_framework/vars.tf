variable "canary_name" {
  type    = string
  default = "Database_Integration_Canaries"
}

variable "network_cidr" {
  type    = string
  default = "10.10.64.0/20"
}

variable "bastion_ubuntu_release" {
  type    = string
  default = "jammy"
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "nodes_instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "nodes_ami_type" {
  type    = string
  default = "AL2_x86_64"
}
