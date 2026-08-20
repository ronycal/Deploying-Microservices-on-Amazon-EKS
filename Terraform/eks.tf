# ============================================================
# Amazon EKS Cluster
# ============================================================


# ------------------------------------------------------------
# EKS Cluster IAM Role
# ------------------------------------------------------------

# IAM role that the Amazon EKS control plane will assume.
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-cluster-role"
  }
}


# ------------------------------------------------------------
# EKS Cluster IAM Policy
# ------------------------------------------------------------

# Gives the EKS control plane the AWS permissions it requires.
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}


# ------------------------------------------------------------
# Amazon EKS Cluster
# ------------------------------------------------------------

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  # Connect the EKS cluster to our private subnets.
  vpc_config {
    subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]

    # Allow Kubernetes API communication from inside the VPC.
    endpoint_private_access = true

    # Allow kubectl on our local computer to communicate
    # with the Kubernetes API.
    endpoint_public_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = var.cluster_name
  }
}


# ============================================================
# EKS Worker Nodes
# ============================================================


# ------------------------------------------------------------
# Worker Node IAM Role
# ------------------------------------------------------------

# The managed node group consists of EC2 instances.
# This role allows those EC2 instances to interact with AWS.
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-node-role"
  }
}


# ------------------------------------------------------------
# Worker Node IAM Policies
# ------------------------------------------------------------

# Allows EC2 worker nodes to communicate with EKS.
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}


# Provides permissions required by the Amazon VPC CNI plugin.
#
# For a production environment, this permission would typically
# be separated from the node IAM role using a dedicated IAM role
# for the VPC CNI add-on.
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}


# Allows worker nodes to pull container images from Amazon ECR.
resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.eks_node_role.name
}


# ============================================================
# EKS Managed Node Group
# ============================================================

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.cluster_name}-workers"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  # Worker nodes will run inside the private subnets.
  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  # EC2 instance type used by the Kubernetes worker nodes.
  instance_types = ["t3.medium"]

  # Start with two EC2 worker nodes.
  #
  # NOTE:
  # This controls EC2 node capacity. It is separate from the
  # Kubernetes Horizontal Pod Autoscaler that we'll configure
  # later for WordPress.
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  # During managed node updates, only one worker node can be
  # unavailable at a time.
  update_config {
    max_unavailable = 1
  }

  # Ensure all required IAM policies exist before AWS attempts
  # to create the worker nodes.
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only
  ]

  tags = {
    Name = "${var.cluster_name}-workers"
  }
}