include $(CURDIR)/../../common/ansible.mk

# This target get the SSH key from the terraform state.
# Terraform output has the key needed to SSH to the machine, we are extracting that key so
# we can set it in the inventory file (above) as the key to be used to connect to th
# machine.
.SILENT: ansible/sshkey
ansible/sshkey:
	terraform output -json sensitive_tls_ca_and_ssh_keys | \
		jq -r '.tls_private_key.ssh_client.private_key_pem' > \
		ansible/sshkey
	chmod 400 ansible/sshkey


.SILENT: ansible/inventory
ansible/inventory: ansible/sshkey
	$(eval public_ip := $(shell terraform output -json jump_machine | jq -r '.aws_instance.jump_machine.public_ip'))
	$(eval username := $(shell terraform output -json jump_machine | jq -r '.aws_instance.jump_machine.username'))
	echo jump_machine \
			ansible_host=$(public_ip) \
			ansible_user=$(username) \
			ansible_ssh_private_key_file=ansible/sshkey \
			ansible_ssh_common_args=\'-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\' \
			> ansible/inventory
