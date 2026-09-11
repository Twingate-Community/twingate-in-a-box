# Twingate Gateway for apps you already run

An identity-aware reverse proxy in front of things Terraform does not manage. The Gateway
and Connector run as containers sharing the host's network namespace, so the Gateway
reaches whatever the host reaches. As long as the Gateway can access the target via the network,
you can configure access to it via Twingate.

This is the counterpart to [`../docker`](../docker), where the apps live in the box and
Terraform reads them out of a compose file. Both share
[`../modules/twingate-stack`](../modules/twingate-stack).

> **Warning:** Terraform state holds the CA private key, the Gateway's private key and
> the Connector tokens in plaintext. `.gitignore` covers state and `terraform.tfvars`.
> Do not commit them.

## What host networking security considerations

The [docker example](../docker) registers its Gateway on a bridge nothing else can reach, so the Gateway never
sees a packet Twingate has not already authorized. This example shares the host's network which means all
ingress restrictions are up to the host. Make sure your environment's firewall restricts access so that
Twingate is the only way to reach the Gateway and the Web Apps it has registered.

It is also important that firewall rules are in place restricting ingress to the Web Apps themselves, especially
if they are trusting headers injected by the Gateway. Without some kind of restriction or whitelist, headers can be
trusted from a malicious source. Grafana solves this issue by enabling a whitelist as an [example](https://www.twingate.com/docs/web-app-grafana#trusted-header-integration-fallback).

## Requirements

- Terraform 1.11 or later
- Docker
- A Twingate API token with Read, Write and Provision permissions

## Usage

```bash
cd proxy
cp terraform.tfvars.example terraform.tfvars   # add tg_api_token and tg_network
terraform init
terraform apply
```

A green apply does not mean the Gateway is running. The image is distroless and has no
healthcheck, so check that it stayed up:

```bash
docker logs twingate-proxy-gateway
```

Give the Connector about 30 seconds to register, then connect the [Twingate Client](https://www.twingate.com/download) and
open one of the `app_urls` outputs. Start with the echo app. It renders the injected
headers at `/headers`, which shows identity propagation working end to end.

## Publishing an app

Below is an example of adding a new service entry:

```hcl
services = {
  grafana = {
    address = "192.168.1.50"
    port    = 3000
    groups  = ["Everyone"]
    alias   = "grafana.lab.internal"
  }
}
```

`address` is what the Gateway dials. `alias` is the name you type. Without one you would be
browsing to `http://192.168.1.50:3000` instead of `http://grafana.lab.internal`. Both end up on the
Gateway's certificate, an IP as an IP SAN and an alias as a DNS SAN.

Adding a service reissues that certificate, so Terraform replaces the Gateway container and
the other apps drop for a few seconds while the new container spins up.

A `headers` map injects headers into requests to that one service, and **replaces** the global
`gateway_request_headers` for it rather than adding to them. The value may contain a single
`{{key}}` from the following list: `jwt`, `username`, `groups`, `clientGeoLatLong`, `clientGeoCity`,
`clientGeoRegion` or `clientGeoCountry`. Twingate caps the map at five entries.

See `variables.tf` for the full list of inputs.

## The demo app

`demo-app.tf` runs an echo server on its own bridge and publishes it at
`http://echo.lab.internal`. It renders the request it received at `/headers`, which works
really well as a debugging tool. Keeping this app up next to your existing apps makes it easy
to see if the Gateway isn't injecting headers correctly vs the target app not reading them correctly.
Set `demo_app = false` to remove it.

## Clean up

```bash
terraform destroy
```

## Support

- For general issues using this project please open a GitHub issue.
- For account specific issues, please visit the [Twingate Subreddit](https://reddit.com/r/twingate)
