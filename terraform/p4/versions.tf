terraform {
  required_version = ">= 1.6"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Authentification par variables OS_* (fichier env du projet dgsn-ops sur VM1, puis Vault en P6).
# Aucun identifiant dans ce dépôt.
provider "openstack" {}
