output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_app_subnet_ids" {
  value = [for s in aws_subnet.priv_app : s.id]
}

output "private_db_subnet_ids" {
  value = [for s in aws_subnet.priv_db : s.id]
}

output "nat_gateway_ids" {
  value = [for n in aws_nat_gateway.nat : n.id]
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}
