# resource "aws_cloudwatch_log_group" "log_groups_eks" {
#   name              = "/aws/eks/${var.mandatory_tags.Environment}/${var.cluster_name}/cluster"
#   retention_in_days = 0
# }