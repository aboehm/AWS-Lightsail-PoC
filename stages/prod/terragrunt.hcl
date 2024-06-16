include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules/webservice-container"
}

input {
  container-image   = "docker.io/hashicorp/http-echo:latest"
  domain            = "prod.example.com"
  service-instances = 2
  service-power     = "nano"
}
