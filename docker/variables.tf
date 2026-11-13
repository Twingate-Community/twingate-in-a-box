variable "tg_api_token" {
  description = "Twingate API token with Read, Write and Provision permissions."
  type        = string
  sensitive   = true
}

variable "tg_network" {
  description = "Twingate network slug (the '<slug>' in <slug>.twingate.com)."
  type        = string
}

variable "gateway_image" {
  description = "Gateway image."
  type        = string
  default     = "ghcr.io/twingate/gateway:2.0.0"
}

variable "connector_image" {
  description = "Connector image."
  type        = string
  default     = "twingate/connector:1"
}

variable "gateway_request_headers" {
  description = "Headers the Gateway injects into every proxied request. Applied with Header.Set(), so a Client cannot spoof them. Per-Resource twingate.header.* labels override these."
  type        = map(string)

  # No {{jwt}} by default: the Gateway logs full request headers on every
  # request, so that would put the token in stdout.
  default = {
    "X-Twingate-User"   = "{{username}}" # the user's email address
    "X-Twingate-Groups" = "{{groups}}"   # comma-separated
  }
}
