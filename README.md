# Twingate in a Box

A complete Twingate deployment that runs on your laptop. Docker holds the Remote
Network, the Connector and the Gateway, so there is no cloud infrastructure to stand up
or tear down.

The Connector provides Zero Trust network access to anything you define as a Resource.
The Gateway adds identity-aware access for web apps, passing the caller's identity
through so that opening a supported app signs you in with no password.

Terraform owns the Twingate side and the network. Docker Compose owns the apps, and
Terraform only reads `docker-compose.yaml` to find which ones to publish.

> **Warning:** Terraform state holds the CA private key, the Gateway's private key and
> the Connector tokens in plaintext. `.gitignore` covers state and `terraform.tfvars`.
> Do not commit them.

## The box is closed to inbound traffic

The Gateway registers at `172.28.0.250:8443`, an address on a Docker bridge network that
is not reachable from the host or the internet. Every Client arrives through the
Connector, so the Gateway never sees a packet Twingate has not already authenticated and
authorized.

Outbound is open, and meant to be. The Gateway fetches JWKS at boot, the Connector
reaches Twingate, and apps can call whatever they need.

This is why no published service declares `ports:`, and why Terraform refuses the plan
if one does. A port on the host lets anything on the machine reach the app directly and
hand it a forged `X-Twingate-User`.

## Requirements

- Terraform 1.11 or later
- Docker
- A Twingate API token with Read, Write and Provision permissions

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # add tg_api_token and tg_network
cp .env.example .env                           # add your network slug for Compose
terraform init
terraform apply
docker compose up -d
```

Terraform creates the network that Compose joins, so it has to run first.

A green apply does not mean the Gateway is running. The image is distroless and has no
healthcheck, so check that it stayed up:

```bash
docker logs twingate-in-a-box-gateway
```

Give the Connector about 30 seconds to register, then connect the Twingate Client and
open one of the `app_urls` outputs. Start with the echo app. It renders the injected
headers at `/headers`, which shows identity propagation working end to end.

## What the demo apps show

Open WebUI and Grafana both sign you in without a login form, by two different routes.
Open WebUI reads the username straight out of `X-Twingate-User` and trusts it. Grafana
takes the whole Twingate token from `X-JWT-Assertion` and checks its signature against
Twingate's public keys, so a forged token fails on cryptography rather than on where it
came from. That is the stronger pattern, and the one to copy for a real app.

Both are set per Resource with `twingate.header.*`, since each app wants a different
header. Grafana is also scoped to the Admin group while the others allow Everyone.

Prometheus scrapes the Gateway and the Connector. It is not published, because Grafana
reaches it over the box network and nothing else needs to.

Grafana comes with the Prometheus datasource and two dashboards already loaded, from
`dashboards/`. The Connector one is from
[Twingate-Community/dashboards](https://github.com/Twingate-Community/dashboards). The
Gateway one covers request rate and status, Client and upstream latency, authentication
attempts, throughput, and transport mix. Edits you make in the UI stick until the
container is recreated, so copy anything you want to keep back into `dashboards/`.

## Publishing an app

Add the service to `docker-compose.yaml`, join the `twingate` network, and label it.

```yaml
services:
  myapp:
    image: myorg/myapp
    networks:
      - twingate
    labels:
      twingate.enable: "true"
      twingate.port: "3000"
      twingate.groups: "Everyone"
```

Then run `terraform apply && docker compose up -d`. Its address is `myapp.twingate`,
which Docker resolves on its own. Adding a service changes the certificate, which
replaces the Gateway container. Expect a brief interruption.

A `twingate.header.<Name>` label injects a header into requests to that one service. The
value may contain a single `{{key}}` from `jwt`, `username`, `groups`,
`clientGeoLatLong`, `clientGeoCity`, `clientGeoRegion` or `clientGeoCountry`. An unknown
key is fatal when the Gateway boots.

See `docker-compose.yaml` for the full label list and `variables.tf` for the inputs.

## Support

- For general issues using this project please open a GitHub issue.
- For account specific issues, please visit the [Twingate forum](https://forum.twingate.com/)
  or open a [support ticket](https://help.twingate.com/)
