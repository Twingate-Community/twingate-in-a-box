# Twingate in a Box

Two Terraform deployments of the same Twingate stack. A Remote Network, a Connector and a
Gateway, all as Docker containers. The Connector provides Zero Trust network access to
anything you define as a Resource. The Gateway adds identity-aware access for web apps,
passing the caller's identity through so that opening a supported app signs you in with no
password, and for SSH, signing a short-lived certificate per session so there are no keys
to manage. [`docker/`](docker) includes an SSH server to try it on.

They differ in where the apps live and how Terraform learns about them.

| | [`docker/`](docker) | [`proxy/`](proxy) |
| --- | --- | --- |
| The apps | run in the box, from its own `docker-compose.yaml` | already run somewhere else |
| Discovery | parses `twingate.*` labels off the compose file | an explicit `services` map |
| Addressing | `https://<service>.box.internal` | `https://<name>.box.internal` |
| Networking | a bridge Terraform creates and Compose joins | the host's own namespace |
| Good for | seeing the whole thing work on a dev machine | putting a Gateway in front of a homelab |

Start with [`docker/`](docker) if you want to understand what a Gateway does. Start with
[`proxy/`](proxy) if you have an existing setup of services and want to easily add Twingate ZTNA and IDFW.

Both call [`modules/twingate-stack`](modules/twingate-stack), which owns the CA, the
Gateway and the Connector. The only structural difference between them is the
`host_network` flag it takes.

> **Warning:** Terraform state holds the CA private key, the Gateway's private key and
> the Connector tokens in plaintext. `.gitignore` covers state and `terraform.tfvars`.
> Do not commit them.
>
> Apps are served over HTTPS, which means installing the box CA into your trust store.
> That tells your machine to trust anything the CA signs, and it is not name-constrained,
> so whoever holds that private key could sign for any domain. Keep state private, treat
> this as a lab tool, and remove the CA when you are finished. Each deployment's README
> has the install and removal commands.

## Quick start on an Ubuntu VM

One command deploys [`docker/`](docker) onto any Ubuntu 22.04 or later VM, on any cloud
or on your own hardware. It installs Docker and Terraform if they are missing, puts the
box in `/opt/twingate-in-a-box`, and creates everything in your Twingate tenant.

```bash
curl -fsSL https://raw.githubusercontent.com/Twingate-Community/twingate-in-a-box/main/install.sh \
  | sudo TG_API_TOKEN=<token> TG_NETWORK=<network> bash
```

Leave out either variable and the script asks for it. When it finishes it prints the app
URLs and the box CA, with the commands to trust that CA on the machine you browse from.

The VM needs:

- Ubuntu 22.04 or later, amd64 or arm64
- 2 vCPU, 4 GB RAM and 20 GB of disk with every service on. Leave out `openwebui` to get
  by with less.
- Outbound internet access. It needs **no inbound ports**. Every Client arrives through
  the Connector, which dials out.

### Choosing services

`TG_SERVICES` picks which apps run. Leave it unset for all of them. Echo is always on,
since it is the quickest way to check that identity reaches an app.

| Name | What it shows |
| --- | --- |
| `openwebui` | Sign-in from a trusted `X-Twingate-User` header. The heaviest service, at about 1 GB of RAM. |
| `grafana` | Sign-in from the Gateway's signed token, with Twingate groups mapped to Grafana roles. Brings Prometheus and dashboards for the Gateway and Connector. |
| `uptimekuma` | An app that keeps its own login, published behind a friendly name. |
| `ssh` | SSH with no keys or passwords, and session recording. |
| `ittools` | An app with no authentication at all, reachable only through Twingate. |

For example, a trial of web sign-in and SSH only:

```bash
curl -fsSL https://raw.githubusercontent.com/Twingate-Community/twingate-in-a-box/main/install.sh \
  | sudo TG_API_TOKEN=<token> TG_NETWORK=<network> TG_SERVICES=grafana,ssh bash
```

Re-run the command with a different `TG_SERVICES` to add or remove services on a running
box. Without `TG_SERVICES`, a re-run keeps the current set. Re-running also picks up
anything you have added to `/opt/twingate-in-a-box/docker/docker-compose.yaml`.

### Creating the VM with cloud-init

Most providers take cloud-init user data when you create a VM, which turns the install
into part of creating the VM:

```yaml
#cloud-config
runcmd:
  - curl -fsSL https://raw.githubusercontent.com/Twingate-Community/twingate-in-a-box/main/install.sh | TG_API_TOKEN=<token> TG_NETWORK=<network> bash
```

Follow progress in `/var/log/twingate-in-a-box-install.log`.

> **Warning:** User data is readable by anything on the VM that can reach the instance
> metadata service, and often by anyone who can view the VM in your cloud console. Use a
> token for a lab tenant, or revoke it once the box is up.

### Removing it

```bash
sudo bash /opt/twingate-in-a-box/install.sh --uninstall
```

This deletes the containers, the Remote Network, the Resources and everything else the
box created in your tenant. It leaves Docker and Terraform installed. Remove the CA from
anywhere you trusted it, using the commands in [`docker/README.md`](docker/README.md).

## Requirements

To run either deployment by hand:

- Terraform 1.11 or later
- Docker
- A Twingate API token with Read, Write and Provision permissions

Each directory is its own Terraform root with its own state, so `cd` into one and read its
README from there.

## Support

- For general issues using this project please open a GitHub issue.
- For account specific issues, please visit the [Twingate Subreddit](https://reddit.com/r/twingate)
