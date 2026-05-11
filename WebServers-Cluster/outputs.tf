output "load_balancer_dns_name" {
  value = aws_lb.LB.dns_name
  description = "The domain name of the load balancer"
}

output "asg_name" {
  value = aws_autoscaling_group.asg.name
  description = "The name of the auto scaling group"
}

output "security_group_id" {
  value = aws_security_group.sg.id
  description = "The ID of the security group"
}