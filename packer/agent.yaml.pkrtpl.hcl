# One agent, baked into its image by packer/lab.pkr.hcl.
#
# osapi validates the whole file whatever the command, so an agent's config has
# to carry controller.api.security.signing_keys,
# controller.client.security.bearer_token and controller.nats.port even though
# the agent uses none of them. These are throwaway values, never the hub's.

controller:
  client:
    security:
      bearer_token: unused-by-the-agent
  api:
    security:
      signing_keys:
        - id: unused
          key: ${dummy_key}
  nats:
    port: 4222

agent:
  hostname: ${hostname}
  labels:
    distro: ${distro}
  nats:
    host: ${nats_host}
    port: ${nats_port}
    client_name: osapi-agent
    namespace: osapi
    # Its own user in osapi's NATS account: adding a host is issuing it
    # credentials, with no change on the server.
    auth:
      type: creds
      creds_file: ${creds_file}
  metrics:
    enabled: true
    host: 0.0.0.0
    port: 9091
  pki:
    enabled: true
  privilege_escalation:
    enabled: false

# The agent binds to buckets the NATS server created; these names have no
# default, so they are repeated from the hub role's template.
nats:
  facts:
    bucket: agent-facts
  state:
    bucket: agent-state
  objects:
    bucket: file-objects
  file_state:
    bucket: file-state
  audit:
    stream: AUDIT
    subject: audit

telemetry:
  tracing:
    enabled: true
    exporter: otlp
    otlp_endpoint: ${nats_host}:${tracing_port}
