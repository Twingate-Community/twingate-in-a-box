# Twingate in a Box

A complete Twingate deployment that runs on your laptop. Docker holds the Remote Network,
the Connector and the Gateway, so there is no cloud infrastructure to stand up or tear
down.

The deployment lives in [`docker/`](docker), which is its own Terraform root with its own
state. Read its README from there.

```bash
cd docker
```

## Support

- For general issues using this project please open a GitHub issue.
- For account specific issues, please visit the [Twingate forum](https://forum.twingate.com/)
  or open a [support ticket](https://help.twingate.com/)
