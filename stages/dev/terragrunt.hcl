include {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "../../modules/webservice-container"
}

inputs = {
  container-image = "docker.io/hashicorp/http-echo:latest"
  domain          = "dev.example.com"
}
