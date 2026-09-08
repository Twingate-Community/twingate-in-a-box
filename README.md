# Twingate in a Box

A self-contained lab that stands up a Twingate Gateway and publishes containerized
web apps through it, with the Gateway propagating the caller's identity to the app.

Terraform owns the Twingate side — remote network, connector, gateway, certificate
authority, and one resource per published app. Docker Compose owns the apps.

## Status

Early. The lab is being ported into this repo piece by piece.
