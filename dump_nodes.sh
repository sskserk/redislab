#terraform output -json > node_dns.json
#!/usr/bin/env bash

#terraform output -json | jq -r '.node0_dns.value , .node1_dns.value , .node2_dns.value'


echo "[nodes]" > hosts

terraform output -json | \
  jq -r '"node0 ansible_host=" + .node0_dns.value , "node1 ansible_host="+.node1_dns.value , "node2 ansible_host="+ .node2_dns.value' >> hosts



echo '' >> hosts
cat hosts_template >> hosts

echo '# nodes' >> hosts
terraform output -json | \
  jq -r '"node0_private_ip = " + .node0_private_ip.value, "node1_private_ip = " + .node1_private_ip.value, "node2_private_ip = " + .node2_private_ip.value' >> hosts


