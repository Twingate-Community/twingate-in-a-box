#!/usr/bin/env bash
#
# Twingate in a Box installer for Ubuntu 22.04 and later.
#
# Installs Docker and Terraform if needed, downloads the box to
# /opt/twingate-in-a-box, and deploys docker/ into your Twingate tenant.
#
#   curl -fsSL https://raw.githubusercontent.com/Twingate-Community/twingate-in-a-box/main/install.sh \
#     | sudo TG_API_TOKEN=... TG_NETWORK=... bash
#
# Environment:
#   TG_API_TOKEN   Twingate API token with Read, Write and Provision permissions.
#   TG_NETWORK     Your network name, the <network> in <network>.twingate.com.
#   TG_SERVICES    Optional. Comma-separated services to run: openwebui, grafana,
#                  uptimekuma, ssh, ittools. Unset runs all of them on first
#                  install and keeps the current set on a re-run. Set but empty
#                  runs only echo, which is always on.
#
# Re-run it at any time to apply changes, such as a service you added to
# /opt/twingate-in-a-box/docker/docker-compose.yaml or a new TG_SERVICES.
#
#   sudo bash install.sh --uninstall
#
# removes everything it created, in Docker and in your Twingate tenant.

set -euo pipefail

BOX_VERSION="${BOX_VERSION:-v0.1.0}"
REPO="Twingate-Community/twingate-in-a-box"
INSTALL_DIR="/opt/twingate-in-a-box"
BOX_DIR="${INSTALL_DIR}/docker"
LOG_FILE="/var/log/twingate-in-a-box-install.log"
PROJECT="twingate-in-a-box"

# Floors. Compose 2.23.1 added inline configs.content, which docker-compose.yaml
# uses. Terraform 1.11 added the write-only attributes the Twingate provider needs.
MIN_COMPOSE="2.23.1"
MIN_TERRAFORM="1.11.0"
MIN_MEM_MB=3800

export DEBIAN_FRONTEND=noninteractive

# First boot is when cloud-init and unattended-upgrades hold the dpkg lock, so
# wait for it instead of failing.
APT=(apt-get -y -q -o DPkg::Lock::Timeout=300)

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: sudo TG_API_TOKEN=... TG_NETWORK=... [TG_SERVICES=a,b] bash install.sh
       sudo bash install.sh --uninstall

Services: openwebui, grafana, uptimekuma, ssh, ittools. echo is always on.
EOF
  exit "${1:-0}"
}

has_tty() { { : </dev/tty; } 2>/dev/null; }

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

preflight() {
  [[ ${EUID} -eq 0 ]] || die "Run as root, for example: curl ... | sudo bash"

  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release. This installer supports Ubuntu only."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ ${ID:-} == "ubuntu" ]] || die "This installer supports Ubuntu only. Found: ${PRETTY_NAME:-unknown}."
  dpkg --compare-versions "${VERSION_ID:-0}" ge 22.04 \
    || die "Ubuntu 22.04 or later is required. Found ${VERSION_ID:-unknown}."
  CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  [[ -n ${CODENAME} ]] || die "Could not determine the Ubuntu codename."

  ARCH="$(dpkg --print-architecture)"
  [[ ${ARCH} == "amd64" || ${ARCH} == "arm64" ]] || die "Unsupported architecture: ${ARCH}. Use amd64 or arm64."

  local mem_mb
  mem_mb=$(( $(awk '/^MemTotal:/ {print $2}' /proc/meminfo) / 1024 ))
  if (( mem_mb < MIN_MEM_MB )); then
    warn "This machine has ${mem_mb} MB of RAM. 4 GB is recommended with every service on, and Open WebUI alone wants about 1 GB."
  fi
}

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

tfvars_file() { echo "${BOX_DIR}/terraform.tfvars"; }

# Reads a quoted string value back out of terraform.tfvars, as written by
# write_tfvars below.
tfvars_get() {
  local file
  file="$(tfvars_file)"
  [[ -f ${file} ]] || return 0
  sed -n "s/^$1 *= *\"\(.*\)\"\$/\1/p" "${file}" | head -n1
}

# The whole services line, so a re-run without TG_SERVICES keeps it as is.
tfvars_services_line() {
  local file
  file="$(tfvars_file)"
  [[ -f ${file} ]] || return 0
  grep -E '^services *=' "${file}" | head -n1 || true
}

# Escapes a value for a double-quoted HCL string, including template sequences.
hcl_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//\$\{/\$\$\{}"
  s="${s//%\{/%%\{}"
  printf '%s' "${s}"
}

prompt() {
  local var="$1" text="$2" secret="${3:-}"
  has_tty || die "${var} is not set and there is no terminal to ask on. Pass it in the environment: sudo ${var}=... bash"
  local value=""
  if [[ -n ${secret} ]]; then
    read -r -s -p "${text}: " value </dev/tty
    echo >/dev/tty
  else
    read -r -p "${text}: " value </dev/tty
  fi
  printf '%s' "${value}"
}

resolve_inputs() {
  TOKEN="${TG_API_TOKEN:-$(tfvars_get tg_api_token)}"
  NETWORK="${TG_NETWORK:-$(tfvars_get tg_network)}"

  [[ -n ${NETWORK} ]] || NETWORK="$(prompt TG_NETWORK "Twingate network (the <network> in <network>.twingate.com)")"
  [[ -n ${TOKEN} ]]   || TOKEN="$(prompt TG_API_TOKEN "Twingate API token (Read, Write and Provision)" secret)"

  # Accept a pasted URL or hostname as well as the bare name.
  NETWORK="${NETWORK#http://}"
  NETWORK="${NETWORK#https://}"
  NETWORK="${NETWORK%%/*}"
  NETWORK="${NETWORK%.twingate.com}"
  NETWORK="$(printf '%s' "${NETWORK}" | tr '[:upper:]' '[:lower:]')"
  [[ ${NETWORK} =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "TG_NETWORK '${NETWORK}' does not look like a Twingate network name."
  [[ -n ${TOKEN} ]] || die "TG_API_TOKEN is empty."

  # Unset keeps whatever is already in terraform.tfvars, which on a first install
  # is nothing, meaning every service. Set but empty means none.
  if [[ -n ${TG_SERVICES+set} ]]; then
    local cleaned name items=()
    cleaned="$(printf '%s' "${TG_SERVICES}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
    IFS=',' read -r -a names <<<"${cleaned}"
    for name in "${names[@]}"; do
      [[ -z ${name} ]] && continue
      [[ ${name} =~ ^[a-z0-9_-]+$ ]] || die "TG_SERVICES has an invalid name: '${name}'."
      items+=("\"${name}\"")
    done
    local joined
    joined="$(IFS=','; echo "${items[*]:-}")"
    SERVICES_LINE="services = [${joined//,/, }]"
  else
    SERVICES_LINE="$(tfvars_services_line)"
  fi
}

write_tfvars() {
  local file
  file="$(tfvars_file)"
  umask 077
  {
    echo "# Written by install.sh. Re-run it to change these, or edit and run terraform apply."
    echo "tg_api_token = \"$(hcl_escape "${TOKEN}")\""
    echo "tg_network   = \"$(hcl_escape "${NETWORK}")\""
    [[ -n ${SERVICES_LINE} ]] && echo "${SERVICES_LINE}"
  } >"${file}.tmp"
  chmod 0600 "${file}.tmp"
  mv "${file}.tmp" "${file}"
}

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

apt_update() {
  # DPkg::Lock::Timeout does not cover the lists lock that update takes, so
  # retry while something else is running apt.
  local i
  for i in $(seq 1 30); do
    "${APT[@]}" update && return 0
    warn "apt-get update failed, likely another apt process holds the lock. Retrying in 10s (${i}/30)."
    sleep 10
  done
  die "apt-get update kept failing. See ${LOG_FILE}."
}

install_prereqs() {
  log "Installing prerequisites"
  apt_update
  "${APT[@]}" install ca-certificates curl gnupg jq
}

compose_version() {
  docker compose version --short 2>/dev/null | sed 's/^v//; s/-.*//'
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    local v
    v="$(compose_version || true)"
    if [[ -n ${v} ]] && dpkg --compare-versions "${v}" ge "${MIN_COMPOSE}"; then
      log "Docker already installed, Compose ${v}"
      systemctl enable --now docker >/dev/null 2>&1 || true
      return
    fi
    # Swapping an existing Docker for Docker's own packages would stop whatever
    # it is running, which is not this script's call to make.
    die "Docker is installed but Compose is ${v:-missing}, and ${MIN_COMPOSE} or later is needed. Install it from Docker's repository (https://docs.docker.com/engine/install/ubuntu/) and re-run."
  fi

  log "Installing Docker from Docker's apt repository"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    >/etc/apt/sources.list.d/docker.list
  apt_update
  "${APT[@]}" install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

terraform_version() {
  terraform version 2>/dev/null | head -n1 | sed -n 's/^Terraform v\([0-9.]*\).*/\1/p'
}

install_terraform() {
  local v
  v="$(terraform_version || true)"
  if [[ -n ${v} ]] && dpkg --compare-versions "${v}" ge "${MIN_TERRAFORM}"; then
    log "Terraform ${v} already installed"
    return
  fi

  log "Installing Terraform from HashiCorp's apt repository"
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" \
    >/etc/apt/sources.list.d/hashicorp.list
  apt_update
  "${APT[@]}" install terraform

  v="$(terraform_version || true)"
  if [[ -z ${v} ]] || ! dpkg --compare-versions "${v}" ge "${MIN_TERRAFORM}"; then
    die "Terraform ${MIN_TERRAFORM} or later is required, got ${v:-nothing}."
  fi
}

# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

fetch_source() {
  # An existing install is left alone, so a re-run applies whatever has been
  # changed in it rather than overwriting it.
  if [[ -d ${BOX_DIR} ]]; then
    log "Using the existing install in ${INSTALL_DIR}"
    return
  fi
  [[ ! -e ${INSTALL_DIR} ]] || die "${INSTALL_DIR} exists but has no docker/ in it. Move it aside and re-run."

  log "Downloading twingate-in-a-box ${BOX_VERSION}"
  mkdir -p "$(dirname "${INSTALL_DIR}")"
  local tmp
  tmp="$(mktemp -d "$(dirname "${INSTALL_DIR}")/.twingate-in-a-box.XXXXXX")"
  curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/${BOX_VERSION}" \
    | tar -xz --strip-components=1 -C "${tmp}" \
    || { rm -rf "${tmp}"; die "Could not download ${REPO} at ${BOX_VERSION}."; }
  [[ -f ${tmp}/docker/docker-compose.yaml ]] || { rm -rf "${tmp}"; die "The download does not contain docker/docker-compose.yaml."; }

  mv "${tmp}" "${INSTALL_DIR}"
  # State will hold the CA private key and Connector tokens.
  chmod 0700 "${INSTALL_DIR}"
}

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------

compose() { docker compose --project-directory "${BOX_DIR}" "$@"; }

# Removes this project's containers for the given Compose services. Done with
# labels rather than Compose itself, because Compose ignores a service whose
# profile is off.
remove_services() {
  local service ids
  for service in "$@"; do
    ids="$(docker ps -aq \
      --filter "label=com.docker.compose.project=${PROJECT}" \
      --filter "label=com.docker.compose.service=${service}")"
    if [[ -n ${ids} ]]; then
      log "Removing ${service}, which is switched off"
      # shellcheck disable=SC2086
      docker rm -f ${ids} >/dev/null
    fi
  done
}

deploy() {
  cd "${BOX_DIR}"

  log "Creating the Twingate side with Terraform"
  terraform init -input=false -no-color >/dev/null
  terraform apply -input=false -auto-approve

  log "Starting the apps with Docker Compose"
  compose up -d --build --remove-orphans

  local disabled=()
  mapfile -t disabled < <(terraform output -json disabled_services | jq -r '.[]')
  (( ${#disabled[@]} == 0 )) || remove_services "${disabled[@]}"
}

# The Gateway image is distroless with no healthcheck, so a green apply says
# nothing about whether it stayed up. Watch for a crash loop instead.
check_health() {
  log "Checking the Gateway and Connector stay up"
  local name before=() after running restarting
  local containers=("${PROJECT}-gateway" "${PROJECT}-connector")

  for name in "${containers[@]}"; do
    before+=("$(docker inspect -f '{{.RestartCount}}' "${name}" 2>/dev/null || echo missing)")
  done
  sleep 20

  local i=0 failed=0
  for name in "${containers[@]}"; do
    read -r running restarting after < <(docker inspect -f '{{.State.Running}} {{.State.Restarting}} {{.RestartCount}}' "${name}" 2>/dev/null || echo "false false missing")
    if [[ ${running} != "true" || ${restarting} == "true" || ${after} != "${before[$i]}" ]]; then
      warn "${name} is not staying up. Its last log lines:"
      docker logs --tail 50 "${name}" 2>&1 | sed 's/^/    /' >&2 || true
      failed=1
    fi
    i=$((i + 1))
  done
  (( failed == 0 )) || die "The box did not come up cleanly. Fix the error above and re-run."
}

summary() {
  cd "${BOX_DIR}"
  local ca
  ca="$(cat ca.pem)"

  cat <<EOF

$(log "Twingate in a Box is running")

Give the Connector about 30 seconds to register, then connect the Twingate Client
on your own machine. Nothing on this VM needs an inbound port.

Web apps:
$(terraform output -json app_urls | jq -r 'to_entries[] | "    \(.value)"')
EOF

  if [[ $(terraform output -json ssh_hosts | jq 'length') -gt 0 ]]; then
    cat <<EOF

SSH (any username, no keys):
$(terraform output -json ssh_hosts | jq -r 'to_entries[] | "    \(.value)"')
EOF
  fi

  cat <<EOF

Apps are served over HTTPS by the box's own CA, so trust it on the machine you
browse from. Paste this there to save it:

cat > twingate-in-a-box-ca.pem <<'PEM'
${ca}
PEM

Then install it:

  macOS:   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain twingate-in-a-box-ca.pem
  Linux:   sudo cp twingate-in-a-box-ca.pem /usr/local/share/ca-certificates/twingate-in-a-box-ca.crt && sudo update-ca-certificates
  Windows: certutil -addstore -f Root twingate-in-a-box-ca.pem   (elevated prompt)

The CA is not name-constrained, so remove it when you are done. The commands are
in the README.

Terraform state in ${BOX_DIR} holds the CA private key, the Gateway's private key
and the Connector tokens in plaintext. It is readable by root only. Keep it that way.

To change services:  re-run with TG_SERVICES=...
To remove it all:    sudo bash ${INSTALL_DIR}/install.sh --uninstall
Install log:         ${LOG_FILE}
EOF
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

uninstall() {
  [[ -d ${BOX_DIR} ]] || die "Nothing to uninstall: ${BOX_DIR} does not exist."
  cd "${BOX_DIR}"

  # Compose only sees services whose profile is on, so go by label to catch all
  # of them. They have to go first, because they sit on the network Terraform
  # is about to delete.
  log "Removing the apps"
  local ids
  ids="$(docker ps -aq --filter "label=com.docker.compose.project=${PROJECT}")"
  # shellcheck disable=SC2086
  [[ -z ${ids} ]] || docker rm -f ${ids} >/dev/null
  ids="$(docker volume ls -q --filter "label=com.docker.compose.project=${PROJECT}")"
  # shellcheck disable=SC2086
  [[ -z ${ids} ]] || docker volume rm ${ids} >/dev/null
  docker image rm "${PROJECT}-ssh" >/dev/null 2>&1 || true

  log "Removing the Twingate side with Terraform"
  terraform init -input=false -no-color >/dev/null
  terraform destroy -input=false -auto-approve

  log "Removing ${INSTALL_DIR}"
  cd /
  rm -rf "${INSTALL_DIR}"

  log "Done. Docker and Terraform are still installed, and so is the box CA anywhere you trusted it."
}

# ---------------------------------------------------------------------------

main() {
  local mode="install"
  case "${1:-}" in
    "") ;;
    --uninstall) mode="uninstall" ;;
    -h|--help) usage 0 ;;
    *) warn "Unknown option: $1"; usage 1 ;;
  esac

  preflight

  # Everything from here on is kept, including on a cloud-init boot where
  # nobody is watching the console.
  touch "${LOG_FILE}" && chmod 0600 "${LOG_FILE}"
  exec > >(tee -a "${LOG_FILE}") 2>&1
  log "$(date -u '+%Y-%m-%dT%H:%M:%SZ') install.sh ${mode} (${BOX_VERSION})"

  if [[ ${mode} == "uninstall" ]]; then
    uninstall
    return
  fi

  install_prereqs
  install_docker
  install_terraform
  fetch_source
  resolve_inputs
  write_tfvars
  deploy
  check_health
  summary
}

# Last line on purpose: a download cut short by curl | bash runs nothing.
main "$@"
