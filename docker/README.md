# Twingate in a Box

A complete Twingate deployment that runs on your dev machine. Test out the full power of Twingate
in Docker and avoid paying for cloud infrastructure or spinning up a test Kubernetes environment.

The Connector provides Zero Trust network access to anything you define as a Resource.
The Gateway adds identity-aware access for web apps, passing the caller's identity
through so that opening a supported app signs you in with no password. It does the same
for SSH, so `ssh ssh.box.internal` gets you a shell with no keys to manage.

Terraform owns the Twingate side and the network. Docker Compose owns the apps.
Terraform reads `docker-compose.yaml` and registers all of the Twingate Resources for you.

Everything here lives inside a box and the only way to add more services is through Docker. To put a Gateway in front of things you already run
elsewhere, see [`../proxy`](../proxy). Both share
[`../modules/twingate-stack`](../modules/twingate-stack).

> **Warning:** Terraform state holds the CA private key, the Gateway's private key and
> the Connector tokens in plaintext. `.gitignore` covers state and `terraform.tfvars`.
> Do not commit them.
>
> Apps are served over HTTPS, which means installing the box CA into your trust store.
> That tells your machine to trust anything the CA signs, and it is not name-constrained,
> so whoever holds that private key could sign for any domain. Keep state private, treat
> this as a lab tool, and remove the CA when you are finished.

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

To deploy on an Ubuntu VM with one command, see the
[quick start](../README.md#quick-start-on-an-ubuntu-vm). On your own machine:

```bash
cd docker
cp terraform.tfvars.example terraform.tfvars   # add tg_api_token and tg_network
terraform init
terraform apply
docker compose up -d
```

Terraform creates the network that Compose joins, so it has to run first. It also writes
`.env`, which Compose reads for your network name and the services to start.

### Choosing services

Every app apart from echo sits in a Compose profile named after it: `openwebui`,
`grafana` (which brings Prometheus with it), `uptimekuma`, `ssh` and `ittools`. All of
them run by default. To run a subset, list them in `terraform.tfvars`:

```hcl
services = ["grafana", "ssh"]
```

Terraform publishes only those, and the `COMPOSE_PROFILES` it writes to `.env` makes
Compose start the same set. Run `terraform apply && docker compose up -d` as usual.
Compose leaves a running service alone when its profile is switched off, so remove
those yourself. `terraform output disabled_services` lists them:

```bash
docker compose rm -sf $(terraform output -json disabled_services | jq -r '.[]')
```

A green apply does not mean the Gateway is running. The image is distroless and has no
healthcheck, so check that it stayed up:

```bash
docker logs twingate-in-a-box-gateway
```

Apps are published over HTTPS, so install the box CA before opening one. Terraform writes
it to `ca.pem`. From this directory:

```bash
# macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.pem

# Linux (update-ca-certificates only reads files ending in .crt)
sudo cp ca.pem /usr/local/share/ca-certificates/twingate-in-a-box-ca.crt && sudo update-ca-certificates

# Windows, from an elevated prompt
certutil -addstore -f Root ca.pem
```

Firefox keeps its own trust store, so import `ca.pem` there separately if you use it.

Remove it when you are done:

```bash
# macOS
sudo security delete-certificate -c twingate-in-a-box-ca /Library/Keychains/System.keychain

# Linux
sudo rm /usr/local/share/ca-certificates/twingate-in-a-box-ca.crt && sudo update-ca-certificates --fresh

# Windows, from an elevated prompt
certutil -delstore Root "twingate-in-a-box-ca"
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

Then run `terraform apply && docker compose up -d`. The app is published at
`https://myapp.box.internal`. Terraform creates the Docker network under the name
`box.internal`, and Docker's DNS answers every service on it as
`<service>.box.internal`, so that one name is the Resource address, the address the
Gateway connects to, and what you type.

The Gateway's certificate is a wildcard over `box.internal`, so it already covers that
name. Adding or removing a service leaves the certificate alone and the Gateway keeps
running, which means the other apps stay up. The one exception is a `twingate.alias`
pointing outside `box.internal`: that name has to be added to the certificate, so the
Gateway is replaced and everything drops for a few seconds.

A `twingate.header.<Name>` label injects a header into requests to that one service. The
value may contain a single `{{key}}` from `jwt`, `username`, `groups`,
`clientGeoLatLong`, `clientGeoCity`, `clientGeoRegion` or `clientGeoCountry`. An unknown
key is fatal when the Gateway boots.

## SSH

The box also runs an SSH server, published the same way with one extra label,
`twingate.protocol: "ssh"`. Connect with:

```bash
ssh ssh.box.internal
```

There are no keys or passwords to set up. The Gateway takes the SSH session from your
Client, then logs in to the server itself with a five-minute certificate signed by an SSH
CA that Terraform generates. The server trusts that CA and nothing else, so the only way
in is through Twingate. The Client adds the CA to `~/.ssh/known_hosts` for you, so there
is no host key prompt either.

Every session lands as the `gateway` account, whatever username you type. The Gateway
decides who gets in, based on your Twingate groups, and the server only sees the Gateway.

### Replaying a session

The Gateway records every session to its log as an [asciicast](https://docs.asciinema.org/manual/asciicast/v2/),
under the `asciicast` key. A long session is split into segments, every five minutes by
default, and each segment repeats the header. To list the recorded sessions (start time,
user, session ID):

```bash
docker logs twingate-in-a-box-gateway 2>&1 | jq -rR '
  fromjson? | select(.logger == "session_recording" and .asciicast_sequence_num == 1)
  | [(.asciicast | split("\n")[0] | fromjson | .timestamp | todate), .user.username, .ssh.channel.id]
  | @tsv'
```

To stitch one session's segments back into a single file, named after the session so
you can export several side by side:

```bash
ID=<session-id>
docker logs twingate-in-a-box-gateway 2>&1 | jq -nrR --arg id "$ID" '
  [inputs | fromjson? | select(.logger == "session_recording" and .ssh.channel.id == $id)]
  | sort_by(.asciicast_sequence_num)
  | (.[0].asciicast | split("\n")[0]), (.[].asciicast | split("\n")[1:][])' > "session-$ID.cast"
```

Then open the session player in your Admin Console,
`https://<network>.twingate.com/sessionplayer`, and load the file.

Both commands need [jq](https://jqlang.org/). The recordings live in the container log, so
they are gone once the Gateway is replaced, which happens on any certificate or config
change.

The server is built from [`ssh/`](ssh). To publish an SSH server of your own, it needs
a `gateway` account and the CA in `TrustedUserCAKeys`. Terraform writes the CA public
key to `ssh-ca.pub`, which [`ssh/sshd_config`](ssh/sshd_config) shows how to use.
`twingate.port` defaults to 22.

See `docker-compose.yaml` for the full label list and `variables.tf` for the inputs.

## Support

- For general issues using this project please open a GitHub issue.
- For account specific issues, please visit the [Twingate Subreddit](https://reddit.com/r/twingate)
