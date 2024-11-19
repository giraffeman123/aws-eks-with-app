locals {
  ephemeral_instance_user_data_filepath = "scripts/bootstrap-db.sh"
  bootstrap_db_script_filepath          = "scripts/init.sql"
  role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}