variable "prefix" {
  description = "Préfixe des ressources"
  type        = string
  default     = "dgsn-p4"
}

variable "image" {
  type    = string
  default = "debian-12"
}

variable "flavor" {
  description = "Flavor réduite (écart lab : 512 Mo, qemu sans virtualisation imbriquée)"
  type        = string
  default     = "dgsn.p4"
}

variable "external_network" {
  type    = string
  default = "public1"
}

variable "cidr" {
  type    = string
  default = "10.40.0.0/24"
}

variable "admin_cidr" {
  description = "Seule source autorisée en SSH vers le bastion (VM1, poste de déploiement)"
  type        = string
  default     = "192.168.100.10/32"
}

variable "ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

# Rôle -> groupe de sécurité ; ip flottante seulement pour le bastion et le front web
variable "instances" {
  type = map(object({ role = string, floating = bool }))
  default = {
    bastion-1 = { role = "bastion", floating = true }
    web-1     = { role = "web", floating = true }
    web-2     = { role = "web", floating = true }
    app-1     = { role = "app", floating = false }
    db-1      = { role = "db", floating = false }
  }
}
