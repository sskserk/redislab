output "node0_dns" {
  value = aws_instance.node_0.public_dns
}

output "node1_dns" {
  value = aws_instance.node_1.public_dns
}

output "node2_dns" {
  value = aws_instance.node_2.public_dns
}


output "node0_private_ip" {
  value = aws_instance.node_0.private_ip
}

output "node1_private_ip" {
  value = aws_instance.node_1.private_ip
}

output "node2_private_ip" {
  value = aws_instance.node_2.private_ip
}