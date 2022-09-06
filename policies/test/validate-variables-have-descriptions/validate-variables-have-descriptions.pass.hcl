#module "tfplan-functions" {
#  source = "../../../common-functions/tfplan-functions/tfplan-functions.sentinel"
#}

mock "tfplan/v2" {
  module {
    source = "mock-tfplan-v2.sentinel"
  }
}

mock "tfconfig/v2" {
  module {
    source = "mock-tfconfig-v2.sentinel"
  }
}

test {
  rules = {
    main =  true
  }
}

