module "tfplan-functions" {
  source = "../common-functions/tfplan-functions/tfplan-functions.sentinel"
}

module "tfrun-functions" {
  source = "../common-functions/tfrun-functions/tfrun-functions.sentinel"
}

module "aws-functions" {
  source = "../common-functions/aws-functions/aws-functions.sentinel"
}

module "tfconfig-functions" {
  source = "../common-functions/tfconfig-functions/tfconfig-functions.sentinel"
}

# Policy to varify declared variables have description
policy "validate-variables-have-descriptions" {
  source = "./validate-variables-have-descriptions.sentinel"
  enforcement_level = "advisory"
}

# Policy to verify required terraform version used
policy "restrict-terraform-versions" {
  source = "./restrict-terraform-versions.sentinel"
  enforcement_level = "advisory"
}

# Policy to see that the cost of Infra is less than 150 doller per month 
#policy "infracost-less-than-150-doller-month" {
#  source = "./infracost-less-than-150-doller-month.sentinel"
#  enforcement_level = "soft-mandatory"
#}

# Policy to verify that the mandatory tags are in place
policy "enforce-mandatory-tags" {
  source = "./enforce-mandatory-tags.sentinel"
  enforcement_level = "advisory"
}
