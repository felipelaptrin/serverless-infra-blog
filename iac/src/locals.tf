locals {
  vpc_id = var.vpc_deploy == true ? module.vpc[0].vpc_id : var.vpc_id
  vpc_ip = cidrhost(var.vpc_cidr, 0)
  all_subnets = [for i in range(4) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  public_subnets = slice(local.all_subnets, 0, 2)
  private_subnets = slice(local.all_subnets, 2, 4)
}