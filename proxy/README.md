# Twingate Gateway for apps you already run

An identity-aware reverse proxy in front of things Terraform does not manage. The Gateway
and Connector run as containers sharing the host's network namespace, so the Gateway
reaches whatever the host reaches: an LXC, a VM, a NAS, another container's address, a
device on the LAN. You list what to publish; nothing is discovered.

This is the counterpart to [`../docker`](../docker), where the apps live in the box and
Terraform reads them out of a compose file. Both share
[`../modules/twingate-stack`](../modules/twingate-stack).

> **Warning:** Terraform state holds the CA private key, the Gateway's private key and
> the Connector tokens in plaintext. `.gitignore` covers state and `terraform.tfvars`.
> Do not commit them.

## What host networking costs

The box registers its Gateway on a bridge nothing else can reach, so the Gateway never
sees a packet Twingate has not already authorized. Sharing the host's namespace gives that
up: the Gateway binds 8443 and 9090 on every host interface, and its config has no
listen-address key to narrow it. That is the trade for reaching addresses Docker cannot
route to. Firewall those ports if the host sits on an untrusted network.

Everything on 8443 except `GET /healthz` still demands a valid Twingate token and a
proof-of-possession signature, so the port is open but the traffic behind it is not. 9090
is Prometheus metrics, plain HTTP and unauthenticated.

The apps themselves are a separate question. An app that trusts `X-Twingate-User` must not
be reachable except through the Gateway, or anything that can reach it directly can forge
that header. An app that verifies the `{{jwt}}` signature is safe either way.

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

Give the Connector about 30 seconds to register, then connect the Twingate Client and open
one of the `app_urls` outputs.

## Publishing an app

Add it to `services`. The address is anything the Docker host can already reach.

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
browsing to `http://192.168.1.50`, which works but reads badly. Both end up on the
Gateway's certificate, an IP as an IP SAN and an alias as a DNS SAN, because no verifier
will match an IP literal against a DNS name.

Adding a service reissues that certificate, so Terraform replaces the Gateway container and
the other apps drop for a few seconds.

A `headers` map injects headers into requests to that one service, and **replaces**
`gateway_request_headers` for it rather than adding to them. The value may contain a single
`{{key}}` from `jwt`, `username`, `groups`, `clientGeoLatLong`, `clientGeoCity`,
`clientGeoRegion` or `clientGeoCountry`. An unknown key is fatal when the Gateway boots.
Twingate also caps the map at five, and a larger one is rejected atomically, which leaves
the app with no injected headers at all.

See `variables.tf` for the full list of inputs.

## The demo app

`demo-app.tf` runs an echo server on its own bridge and publishes it at
`http://echo.lab.internal`. It renders the request it received at `/headers`, which
separates "the Gateway isn't injecting" from "my app isn't reading them". That is worth
keeping around next to your own apps. Set `demo_app = false` to drop it.

It is deliberately on a network of its own with no published ports, which puts it in the
same position as an LXC or a VM: the Gateway reaches it because the host routes there, not
because Terraform put them on a network together.

## Clean up

```bash
terraform destroy
```

## Support

- For general issues using this project please open a GitHub issue.
- For account specific issues, please visit the [Twingate forum](https://forum.twingate.com/)
  or open a [support ticket](https://help.twingate.com/)
