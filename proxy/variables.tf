variable "tg_api_token" {
  description = "Twingate API token with Read, Write and Provision permissions."
  type        = string
  sensitive   = true
}

variable "tg_network" {
  description = "Twingate network name (the '<network_name>' in <network_name>.twingate.com)."
  type        = string
}

variable "services" {
  description = "Apps to publish. Nothing is discovered: each entry is an address the Gateway can already reach, the port the app listens on, and who gets in. An alias gives it a name to type instead of the address."

  type = map(object({
    address = string
    port    = number
    groups  = list(string)
    alias   = optional(string)
    name    = optional(string)
    headers = optional(map(string), {})
  }))

  # Empty is a working deployment as long as demo_app is on, which is what makes
  # this runnable before it is pointed at anything real.
  default = {}
}

variable "demo_app" {
  description = "Run an echo app and publish it. It renders the request it received at /headers, so it is worth leaving on next to your own apps: it tells you whether the Gateway is injecting identity, separately from whether an app reads it."
  type        = bool
  default     = true
}

variable "gateway_image" {
  description = "Gateway image."
  type        = string
  default     = "ghcr.io/twingate/gateway:1.1.0"
}

variable "connector_image" {
  description = "Connector image."
  type        = string
  default     = "twingate/connector:1"
}

variable "gateway_request_headers" {
  description = "Headers the Gateway injects into every proxied request. Applied with Header.Set(), so a Client cannot spoof them. Per-service headers override these."
  type        = map(string)

  # No {{jwt}} by default: the Gateway logs full request headers on every
  # request, so that would put the token in stdout.
  default = {
    "X-Twingate-User"   = "{{username}}" # the user's email address
    "X-Twingate-Groups" = "{{groups}}"   # comma-separated
  }
}
