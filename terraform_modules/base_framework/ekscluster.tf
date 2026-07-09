module "eks_cluster" {
  source               = "../modules/eks_cluster"
  canary_name          = "Database_Integration_Canaries"
  cluster_desired_size = 4
  cluster_max_size     = 8
  cluster_min_size     = 1

  base_vpc_id     = aws_vpc.base_vpc.id
  base_subnet_ids = [for s in aws_subnet.private_subnets : s.id]

  subnet_ids_nodegroup = [aws_subnet.private_subnets[0].id]
  subnet_ids_stable    = [aws_subnet.private_subnets[1].id]
  subnet_ids_candidate = [aws_subnet.private_subnets[2].id]
}
