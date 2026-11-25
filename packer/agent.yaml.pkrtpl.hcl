# One agent, baked into its image by packer/lab.pkr.hcl. Each key that is not
# here has its default.

agent:
  hostname: ${hostname}
  labels:
    distro: ${distro}
  nats:
    host: ${nats_host}
    port: ${nats_port}
    # Its own user in osapi's NATS account: adding a host is issuing it
    # credentials, with no change on the server.
    auth:
      type: creds
      creds_file: ${creds_file}
    # The VM dials the hub by its address on tart's network; the hub's
    # certificate names its Tailscale name.
    tls:
      enabled: true
      server_name: ${hub_name}
  # osapi's integration suite runs its command examples against the lab, as
  # CI's agent allows them. The lab's VMs are test hosts.
  command:
    enabled: true

telemetry:
  tracing:
    enabled: true
    exporter: otlp
    otlp_endpoint: ${nats_host}:${tracing_port}
    # The VM dials the hub by its address on tart's network; the hub's
    # certificate names its Tailscale name.
    tls:
      enabled: true
      server_name: ${hub_name}
