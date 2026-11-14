#!/bin/sh
# Prepares a base image to run an osapi agent. Runs as root under Packer.
#
# The image holds no osapi binary and no config: `just deploy` copies both in,
# so testing a branch never needs an image rebuild and an image never holds a
# secret.

# The lab's key, so `just deploy` reaches the VM without a password.
install -d -m 0700 -o admin -g admin /home/admin/.ssh
echo "$LAB_SSH_PUBKEY" > /home/admin/.ssh/authorized_keys
chown admin:admin /home/admin/.ssh/authorized_keys
chmod 0600 /home/admin/.ssh/authorized_keys

# `just deploy` runs install and systemctl through sudo over SSH.
echo 'admin ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/admin
chmod 0440 /etc/sudoers.d/admin

install -d -m 0755 /etc/osapi /var/lib/osapi

# The unit waits on the binary and config `just deploy` puts in place, so a VM
# booted from a fresh image starts quietly rather than failing in a loop.
install -m 0644 /tmp/osapi-agent.service /etc/systemd/system/osapi-agent.service
systemctl daemon-reload
systemctl enable osapi-agent.service

# osapi's ping provider uses unprivileged ICMP sockets.
echo 'net.ipv4.ping_group_range = 0 2147483647' > /etc/sysctl.d/90-osapi-ping.conf
