terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
    }
    metal = {
      source = "equinix/metal"
    }
    random = {
      source = "hashicorp/random"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 0.13"
}
