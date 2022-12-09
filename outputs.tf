# Outputs
# Show EC2 Instance Public IPv4 Address
output "ec2publicip" {
  value = aws_instance.instance1.public_ip
}

# Show DB Instance Address
output "dbinstanceaddress" {
  value = aws_db_instance.dbinstance.address
}

# Show DNS of LB
output "lb_dns_name" {
  description = "The DNS of LB"
  value       = aws_lb.alb.dns_name
}
