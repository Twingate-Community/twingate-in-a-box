# Twingate in a Box

Two Terraform deployments of the same Twingate stack: a Remote Network, a Connector and a
Gateway, all as Docker containers. The Connector provides Zero Trust network access to
anything you define as a Resource. The Gateway adds identity-aware access for web apps,
passing the caller's identity through so that opening a supported app signs you in with no
password.

They differ in where the apps live and how Terraform learns about them.

| | [`docker/`](docker) | [`proxy/`](proxy) |
| --- | --- | --- |
| The apps | run in the box, from its own `docker-compose.yaml` | already run somewhere else |
| Discovery | parses `twingate.*` labels off the compose file | an explicit `services` map |
| Addressing | Docker DNS names, `<service>.twingate` | private IPs the host can reach |
| Networking | a bridge Terraform creates and Compose joins | the host's own namespace |
| Good for | seeing the whole thing work on a laptop | putting a Gateway in front of a homelab |

Start with [`docker/`](docker) if you want to understand what a Gateway does. Start with
[`proxy/`](proxy) if you have a Proxmox host, a NAS or a rack of LXCs and want them behind
Twingate.

Both call [`modules/twingate-stack`](modules/twingate-stack), which owns the CA, the
Gateway and the Connector. The only structural difference between them is the
`host_network` flag it takes.

> **Warning:** Terraform state holds the CA private key, the Gateway's private key and
> the Connector tokens in plaintext. `.gitignore` covers state and `terraform.tfvars`.
> Do not commit them.

## Requirements

- Terraform 1.11 or later
- Docker
- A Twingate API token with Read, Write and Provision permissions

Each directory is its own Terraform root with its own state, so `cd` into one and read its
README from there.

## Support

- For general issues using this project please open a GitHub issue.
- For account specific issues, please visit the [Twingate Subreddit](https://reddit.com/r/twingate)