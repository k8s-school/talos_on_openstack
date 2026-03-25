terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.6"
    }
  }
}

provider "openstack" {
  # Configuration loaded from environment variables
  # Source your openrc file: source ~/.novacreds/fink-openrc.sh
  # Or set these environment variables:
  # - OS_AUTH_URL
  # - OS_USERNAME
  # - OS_PASSWORD
  # - OS_PROJECT_NAME
  # - OS_USER_DOMAIN_NAME
  # - OS_PROJECT_DOMAIN_NAME
}

provider "talos" {}