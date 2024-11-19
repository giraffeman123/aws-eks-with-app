output "public_subnets_ids" {
  value = data.aws_subnets.my_subnets.ids
}

output "private_subnets_ids" {
  value = data.aws_subnets.my_subnets.ids
}