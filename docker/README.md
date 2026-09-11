# Twingate in a Box

A complete Twingate deployment that runs on your dev machine. Test out the full power of Twingate
in Docker and avoid paying for cloud infrastructure or spinning up a test Kubernetes environment.

The Connector provides Zero Trust network access to anything you define as a Resource.
The Gateway adds identity-aware access for web apps, passing the caller's identity
through so that opening a supported app signs you in with no password.

Terraform owns the Twingate side and the network. Docker Compose owns the apps.
Terraform reads `docker-compose.yaml` and registers all of the Twingate Resources for you.

> **Warning:** Terraform state holds the CA private key, the Gateway's private key and
> the Connector tokens in plaintext. `.gitignore` covers state and `terraform.tfvars`.
> Do not commit them.

## The environment is closed to inbound traffic by design

The Gateway registers at `172.28.0.250:8443`, an address on a Docker bridge network that
is not reachable from the host or the internet. Every Client arrives through the
Connector, so the Gateway never sees a packet Twingate has not already authenticated and
authorized.

Outbound is open, and meant to be. The Gateway can fetch your tenant's JWKS at boot, the Connector
can reach Twingate, and your apps can call whatever they need.

This is why no published service declares `ports:`, and why Terraform refuses the plan
if one does. A port on the host lets anything on the machine reach the app directly and
hand it a forged `X-Twingate-User`.

This is the standard approach for all Twingate deployments regardless of if they are local, or in the cloud.

## Requirements

- Terraform 1.11 or later
- Docker
- A Twingate API token with Read, Write and Provision permissions

## Usage

```bash
cd docker
cp terraform.tfvars.example terraform.tfvars   # add tg_api_token and tg_network
cp .env.example .env                           # add your network name for Grafana's JWKS access
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

Give the Connector about 30 seconds to register, then connect the [Twingate Client](https://www.twingate.com/download) and
open one of the `app_urls` outputs. Start with the echo app. It renders the injected
headers at `/headers`, which shows identity propagation working end to end.

## What the demo apps show

Open WebUI and Grafana both sign you in without a login form, by two different routes.
Open WebUI reads the username straight out of `X-Twingate-User` and trusts it. Grafana
takes the whole Twingate Gateway Access Token (GAT) from `X-JWT-Assertion` and checks its signature against
your tenant's public keys. A forged token then fails on cryptography rather than on where it
came from. Using the GAT is the recommended approach as it is the most secure.

Each is set per Resource with `twingate.header.*`, since the two apps want different
headers. Grafana goes further and maps the user's Twingate Group assignments in the GAT to a Grafana role.
This allows for automatic group assignment via Twingate rather than needing to also configure Grafana
for each user. The default behavior is all users receive the "Viewer" role on login.

Uptime Kuma and IT-Tools are examples of apps that do not support login via third party JWT or plaintext header.
The Gateway can still provide value for these services and act as a reverse proxy. By configuring an
alias for the Resource, users can access the service via this alias and will no longer need to remember IP addresses
and the associated ports for these services.

Grafana comes with the Prometheus datasource and two dashboards already loaded, from
`dashboards/`. Edits you make in the UI stick until the
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
      twingate.groups: "MyGroup"
```

Then run `terraform apply && docker compose up -d`. Docker resolves its address,
`myapp.twingate`, on its own. Adding a service changes the certificate, so Terraform
replaces the Gateway container and the other apps drop for a few seconds.

A `twingate.header.<Name>` label injects a header into requests to that one service. The
value may contain a single `{{key}}` from `jwt`, `username`, `groups`,
`clientGeoLatLong`, `clientGeoCity`, `clientGeoRegion` or `clientGeoCountry`. An unknown
key is fatal when the Gateway boots.

See `docker-compose.yaml` for the full label list and `variables.tf` for the inputs.

## Support

- For general issues using this project please open a GitHub issue.
- For account specific issues, please visit the [Twingate Subreddit](https://reddit.com/r/twingate)
