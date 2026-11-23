packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

# One image is the whole of one VM: the osapi build, its config, its NATS
# credential, its hostname and each package that the lab needs. Nothing
# configures a VM after it boots. ansible/playbooks/images.yml runs one build
# for each VM of the inventory and passes each variable; the NATS credential
# comes in PKR_VAR_nats_creds, so it is in no argument list and no log.

variable "vm" {
  type        = string
  description = "The VM, as the inventory names it, such as ubuntu-1. It is the hostname and names the image img-<vm>-<image_tag>."
}

variable "distro" {
  type        = string
  description = "The distribution of the VM: ubuntu, debian, fedora or opensuse."
  validation {
    condition     = contains(["ubuntu", "debian", "fedora", "opensuse"], var.distro)
    error_message = "The distro must be ubuntu, debian, fedora or opensuse."
  }
}

variable "base_image" {
  type        = string
  description = "The local Tart image to build on, for a distro with a directory under bases/. The tart_base role makes it on the hub. Empty for a distro that pulls its image from base_images."
  default     = ""
}

variable "image_tag" {
  type        = string
  description = "The tag of the osapi build (short commit, -dirty for uncommitted changes)."
}

variable "revision" {
  type        = string
  description = "The full revision of the osapi build, which the image records."
}

variable "osapi_binary" {
  type        = string
  description = "The osapi linux build on the hub, which the image installs."
}

variable "ssh_pubkey" {
  type        = string
  description = "The lab's SSH public key, so `just ssh` reaches the VM."
}

variable "nats_creds" {
  type        = string
  sensitive   = true
  description = "The VM's own NATS credential, from the lab's nsc account."
}

variable "nats_host" {
  type        = string
  description = "The address of the hub on the network of the VMs: the gateway of tart's shared network."
  default     = "192.168.64.1"
}

variable "nats_port" {
  type        = number
  description = "The NATS port of the hub."
  default     = 4222
}

variable "tracing_port" {
  type        = number
  description = "The OTLP port of the hub's tracing."
  default     = 4317
}

variable "dummy_key" {
  type        = string
  description = "A throwaway signing key, which the config must carry and the agent does not use."
}

locals {
  base_images = {
    ubuntu = "ghcr.io/cirruslabs/ubuntu:24.04"
    debian = "ghcr.io/cirruslabs/debian:trixie"
    fedora = "ghcr.io/cirruslabs/fedora:42"
    # Cirrus Labs publishes no openSUSE image. The hub makes one from
    # openSUSE's own cloud image: bases/opensuse has the source and the seed
    # of its first boot, and images.yml passes its name in base_image.
    opensuse = var.base_image
  }

  # The packages that osapi's behaviors run, so the lab can test them:
  # - Docker, for the container behaviors: docker.io on Ubuntu and Debian,
  #   moby-engine on Fedora, docker on openSUSE. Each has the daemon and the
  #   CLI. The agent runs
  #   as root, so no user joins the docker group.
  # - chrony, for the ntp behavior, which runs chronyc. On Ubuntu and Debian
  #   it replaces systemd-timesyncd.
  # The agent reports a behavior's program that the image lacks as
  # missing_programs, and the integration test TestPrograms fails on it.
  install_packages = {
    ubuntu   = ["apt-get update -q", "DEBIAN_FRONTEND=noninteractive apt-get install -y -q docker.io chrony"]
    debian   = ["apt-get update -q", "DEBIAN_FRONTEND=noninteractive apt-get install -y -q docker.io chrony"]
    fedora   = ["dnf install -y -q moby-engine chrony"]
    opensuse = ["zypper --non-interactive --quiet install --no-recommends docker chrony"]
  }

  # Fedora and openSUSE have no provider of their own, so their agents run the
  # generic Linux providers with IGNORE_LINUX and show what osapi skips.
  ignore_linux_dropin = [
    "install -d -m 0755 /etc/systemd/system/osapi-agent.service.d",
    "install -m 0644 /tmp/lab/agent-dropin.conf /etc/systemd/system/osapi-agent.service.d/lab.conf",
  ]
  agent_dropin = {
    ubuntu   = []
    debian   = []
    fedora   = local.ignore_linux_dropin
    opensuse = local.ignore_linux_dropin
  }

  image = "img-${var.vm}-${var.image_tag}"

  agent_config = templatefile("${path.root}/agent.yaml.pkrtpl.hcl", {
    hostname     = var.vm
    distro       = var.distro
    nats_host    = var.nats_host
    nats_port    = var.nats_port
    tracing_port = var.tracing_port
    creds_file   = "/etc/osapi/nats.creds"
    dummy_key    = var.dummy_key
  })
}

source "tart-cli" "vm" {
  vm_base_name = local.base_images[var.distro]
  vm_name      = local.image
  cpu_count    = 2
  memory_gb    = 2
  disk_size_gb = 20
  headless     = true
  # The Cirrus Labs Linux images ship with this account, and the seed of a
  # base under bases/ makes it.
  ssh_username = "admin"
  ssh_password = "admin"
  ssh_timeout  = "180s"
}

build {
  sources = ["source.tart-cli.vm"]

  provisioner "shell" {
    inline = ["mkdir -p /tmp/lab"]
  }

  provisioner "file" {
    source      = var.osapi_binary
    destination = "/tmp/lab/osapi"
  }

  provisioner "file" {
    source      = "${path.root}/osapi-agent.service"
    destination = "/tmp/lab/osapi-agent.service"
  }

  provisioner "file" {
    content     = local.agent_config
    destination = "/tmp/lab/osapi.yaml"
  }

  provisioner "file" {
    content     = var.nats_creds
    destination = "/tmp/lab/nats.creds"
  }

  provisioner "file" {
    content     = "${var.ssh_pubkey}\n"
    destination = "/tmp/lab/authorized_keys"
  }

  provisioner "file" {
    content     = "net.ipv4.ping_group_range = 0 2147483647\n"
    destination = "/tmp/lab/90-osapi-ping.conf"
  }

  provisioner "file" {
    content     = "[Service]\nEnvironment=IGNORE_LINUX=1\n"
    destination = "/tmp/lab/agent-dropin.conf"
  }

  provisioner "file" {
    content     = "image=${local.image}\nrevision=${var.revision}\nbuilt=${timestamp()}\n"
    destination = "/tmp/lab/image"
  }

  provisioner "shell" {
    execute_command = "echo admin | sudo -S env {{ .Vars }} sh -eu '{{ .Path }}'"
    inline = concat(
      [
        # The lab's key, so Ansible's client role and `just ssh` reach the VM
        # without a password, and sudo with no password for the admin user.
        "install -d -m 0700 -o admin -g admin /home/admin/.ssh",
        "install -m 0600 -o admin -g admin /tmp/lab/authorized_keys /home/admin/.ssh/authorized_keys",
        "echo 'admin ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/admin",
        "chmod 0440 /etc/sudoers.d/admin",
        "hostnamectl set-hostname ${var.vm}",
      ],
      local.install_packages[var.distro],
      [
        "systemctl enable docker.service",
        "systemctl enable chronyd.service || systemctl enable chrony.service",
        # osapi's ping provider uses unprivileged ICMP sockets.
        "install -m 0644 /tmp/lab/90-osapi-ping.conf /etc/sysctl.d/90-osapi-ping.conf",
        "install -d -m 0755 /etc/osapi /var/lib/osapi /etc/osapi-lab",
        "install -m 0755 /tmp/lab/osapi /usr/local/bin/osapi",
        "install -m 0600 /tmp/lab/osapi.yaml /etc/osapi/osapi.yaml",
        "install -m 0600 /tmp/lab/nats.creds /etc/osapi/nats.creds",
        "install -m 0644 /tmp/lab/image /etc/osapi-lab/image",
        "install -m 0644 /tmp/lab/osapi-agent.service /etc/systemd/system/osapi-agent.service",
        # A config that osapi refuses fails the build, not the boot of a VM.
        "! /usr/local/bin/osapi -f /etc/osapi/osapi.yaml client health liveness 2>&1 | grep -q 'invalid config'",
      ],
      local.agent_dropin[var.distro],
      [
        "systemctl daemon-reload",
        "systemctl enable osapi-agent.service",
        "rm -rf /tmp/lab",
        # Every clone of this image must get its own machine ID, which osapi
        # uses as the agent's identity. An empty file makes systemd generate
        # one on first boot.
        ": > /etc/machine-id",
        "rm -f /var/lib/dbus/machine-id",
      ],
    )
  }
}
