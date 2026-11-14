#!/bin/sh
# Prepares a base image to run an osapi agent. Runs as root under Packer.
#
# The image holds the osapi binary but never its config: the config carries the
# NATS password, and an image never holds a secret. Ansible drops the config in
# after cloning, and the agent starts once it is there.

# The lab's key, so Ansible reaches the VM without a password.
install -d -m 0700 -o admin -g admin /home/admin/.ssh
echo "$LAB_SSH_PUBKEY" > /home/admin/.ssh/authorized_keys
chown admin:admin /home/admin/.ssh/authorized_keys
chmod 0600 /home/admin/.ssh/authorized_keys

# Ansible's agent role runs install and systemctl through sudo over SSH.
echo 'admin ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/admin
chmod 0440 /etc/sudoers.d/admin

install -d -m 0755 /etc/osapi /var/lib/osapi
install -m 0755 /tmp/osapi /usr/local/bin/osapi
rm -f /tmp/osapi

# What this image is and which osapi build it holds, so a VM cloned from it can
# say. The list playbook reads it.
install -d -m 0755 /etc/osapi-lab
printf 'image=%s\nrevision=%s\nbuilt=%s\n' \
  "$LAB_IMAGE" "$LAB_REVISION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > /etc/osapi-lab/image

# The unit waits for the config Ansible drops in after cloning, so a VM booted
# from a fresh image starts quietly rather than failing in a loop.
install -m 0644 /tmp/osapi-agent.service /etc/systemd/system/osapi-agent.service
systemctl daemon-reload
systemctl enable osapi-agent.service

# osapi's ping provider uses unprivileged ICMP sockets.
echo 'net.ipv4.ping_group_range = 0 2147483647' > /etc/sysctl.d/90-osapi-ping.conf

# Every clone of this image must get its own machine ID, which osapi uses as the
# agent's identity. An empty file makes systemd generate one on first boot.
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
