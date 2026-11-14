packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

# The lab's SSH public key, from .lab/ssh/id_ed25519.pub. `just images` passes it.
variable "ssh_pubkey" {
  type = string
}

source "tart-cli" "base" {
  cpu_count    = 2
  memory_gb    = 2
  disk_size_gb = 20
  headless     = true
  # The Cirrus Labs Linux images ship with this account.
  ssh_username = "admin"
  ssh_password = "admin"
  ssh_timeout  = "180s"
}

# One image per distribution. Ubuntu and Debian are both the debian platform to
# osapi. Fedora has no provider of its own, so it gets the generic Linux
# providers and shows what osapi skips.
build {
  source "source.tart-cli.base" {
    name         = "ubuntu"
    vm_base_name = "ghcr.io/cirruslabs/ubuntu:24.04"
    vm_name      = "lab-ubuntu"
  }

  source "source.tart-cli.base" {
    name         = "debian"
    vm_base_name = "ghcr.io/cirruslabs/debian:trixie"
    vm_name      = "lab-debian"
  }

  source "source.tart-cli.base" {
    name         = "fedora"
    vm_base_name = "ghcr.io/cirruslabs/fedora:42"
    vm_name      = "lab-fedora"
  }

  provisioner "file" {
    source      = "${path.root}/osapi-agent.service"
    destination = "/tmp/osapi-agent.service"
  }

  provisioner "shell" {
    environment_vars = ["LAB_SSH_PUBKEY=${var.ssh_pubkey}"]
    execute_command  = "echo admin | sudo -S env {{ .Vars }} sh -eu '{{ .Path }}'"
    script           = "${path.root}/provision.sh"
  }
}
