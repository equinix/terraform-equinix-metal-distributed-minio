terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
    }
    packet = {
      source = "packethost/packet"
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
