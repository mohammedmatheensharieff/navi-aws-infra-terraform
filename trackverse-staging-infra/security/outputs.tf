output "sg_alb_id" { value = aws_security_group.alb.id }
output "sg_api_id" { value = aws_security_group.api.id }
output "sg_ingest_id" { value = aws_security_group.ingest.id }
output "sg_rds_id" { value = aws_security_group.rds.id }
output "sg_redis_id" { value = aws_security_group.redis.id }

output "ssm_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_ssm_profile.name
}
