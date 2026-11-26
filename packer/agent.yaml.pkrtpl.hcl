# The config of a lab VM's agent. The agent joins at its first boot with the
# join string: it pins the hub's certificate, asks the controller to admit it,
# and keeps its NATS user and the server in agent.pki.key_dir. Later starts
# read those, and use no token. The join string reaches the hub at the gateway
# of tart's network; the agent then checks the hub's certificate for its
# tailnet name (osapi-io/osapi#1491).
agent:
  hostname: ${hostname}
  join: ${join}
  labels:
    distro: ${distro}
  command:
    enabled: true

telemetry:
  tracing:
    enabled: true
    exporter: otlp
    otlp_endpoint: ${nats_host}:${tracing_port}
    tls:
      enabled: true
      server_name: ${hub_name}
