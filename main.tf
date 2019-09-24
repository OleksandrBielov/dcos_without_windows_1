provider "aws" {
  region = "us-east-1"
}

# Used to determine your public IP for forwarding rules
data "http" "whatismyip" {
  url = "http://whatismyip.akamai.com/"
}

locals {
  cluster_name = "OB-dcos-test-python"
}

module "dcos" {
  source  = "dcos-terraform/dcos/aws"
  version = "~> 0.2.0"

  providers = {

    aws = "aws"

  }

  cluster_name        = "${local.cluster_name}"
  ssh_public_key_file = "~/.ssh/ob_dcos.pub"
  admin_ips           = ["${data.http.whatismyip.body}/32"]

  num_masters        = "1"
  num_private_agents = "1"
  num_public_agents  = "1"

  dcos_instance_os        = "centos_7.5"
  bootstrap_instance_type = "m5.xlarge"

  dcos_variant              = "open"
  dcos_version              = "1.13.4"
  # dcos_license_key_contents = "${file("~/license.txt")}"
  #ansible_bundled_container = "sebbrandt87/dcos-ansible-bundle:windows-support"
  ansible_bundled_container = "sergiimatusepam/dcos-ansible-bundle:feature-windows-support"

  additional_windows_private_agent_ips       = ["${concat(module.winagent.private_ips)}"]
  additional_windows_private_agent_passwords = ["${concat(module.winagent.windows_passwords)}"]
}

module "winagent" {
  source  = "dcos-terraform/windows-instance/aws"

  providers = {
    aws = "aws"

  }

  cluster_name           = "${local.cluster_name}"
  hostname_format        = "%[3]s-winagent%[1]d-%[2]s"
  aws_subnet_ids         = ["${module.dcos.infrastructure.vpc.subnet_ids}"]
  aws_security_group_ids = ["${module.dcos.infrastructure.security_groups.internal}", "${module.dcos.infrastructure.security_groups.admin}"]
  aws_key_name           = "${module.dcos.infrastructure.aws_key_name}"
  aws_instance_type      = "m5.xlarge"

  num                    = "1"
}

module "winagent_python" {
  source  = "dcos-terraform/windows-instance_python/aws"
  #version = "~> 0.2.1"

  providers = {
    aws = "aws"

  }

  cluster_name           = "${local.cluster_name}"
  hostname_format        = "%[3]s-winagent-python%[1]d-%[2]s"
  aws_subnet_ids         = ["${module.dcos.infrastructure.vpc.subnet_ids}"]
  aws_security_group_ids = ["${module.dcos.infrastructure.security_groups.internal}", "${module.dcos.infrastructure.security_groups.admin}"]
  aws_key_name           = "${module.dcos.infrastructure.aws_key_name}"
  aws_instance_type      = "m5.xlarge"
  aws_ami                = "ami-0009d1b1be7b76713"

  num                    = "1"
  user_data              = "${file("${path.module}/user-data")}"
}

output "masters_dns_name" {
  description = "This is the load balancer address to access the DC/OS UI"
  value       = "${module.dcos.masters-loadbalancer}"
}
output "passwrod" {
  value       = "${module.winagent.windows_passwords}"
}

output "passwrod-2" {
  value       = "${module.winagent_python.windows_passwords}"
}

