packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

# Every variable is passed by ansible/playbooks/images.yml.

# The lab's SSH public key, from .lab/ssh/id_ed25519.pub on the machine running
# Ansible.
variable "ssh_pubkey" {
  type = string
}

# The osapi linux build baked into the image, as copied to the hub.
variable "osapi_binary" {
  type = string
}

# The build's tag (short commit, -dirty for uncommitted changes), which names
# the image img-<distro>-<tag>, and its description, which the image records.
variable "image_tag" {
  type = string
}

variable "revision" {
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
    vm_name      = "img-ubuntu-${var.image_tag}"
  }

  source "source.tart-cli.base" {
    name         = "debian"
    vm_base_name = "ghcr.io/cirruslabs/debian:trixie"
    vm_name      = "img-debian-${var.image_tag}"
  }

  source "source.tart-cli.base" {
    name         = "fedora"
    vm_base_name = "ghcr.io/cirruslabs/fedora:42"
    vm_name      = "img-fedora-${var.image_tag}"
  }

  provisioner "file" {
    source      = "${path.root}/osapi-agent.service"
    destination = "/tmp/osapi-agent.service"
  }

  provisioner "file" {
    source      = var.osapi_binary
    destination = "/tmp/osapi"
  }

  provisioner "shell" {
    environment_vars = [
      "LAB_SSH_PUBKEY=${var.ssh_pubkey}",
      "LAB_IMAGE=img-${source.name}-${var.image_tag}",
      "LAB_REVISION=${var.revision}",
    ]
    execute_command = "echo admin | sudo -S env {{ .Vars }} sh -eu '{{ .Path }}'"
    script          = "${path.root}/provision.sh"
  }
}
