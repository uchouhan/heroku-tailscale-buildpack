#!/usr/bin/env bash

set -e

function log() {
  echo "-----> $*"
}

function indent() {
  sed -e 's/^/       /'
}

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
  log "Skipping Tailscale"

else
  log "Starting Tailscale"

  if [ -z "$TAILSCALE_HOSTNAME" ]; then
    if [ -z "$HEROKU_APP_NAME" ]; then
      tailscale_hostname=$(hostname)
    else
      # Only use the first 8 characters of the commit sha.
      # Swap the . and _ in the dyno with a - since tailscale doesn't
      # allow for periods.
      DYNO=${DYNO//./-}
      DYNO=${DYNO//_/-}
      tailscale_hostname=${HEROKU_SLUG_COMMIT:0:8}"-$DYNO-$HEROKU_APP_NAME"
    fi
  else
    tailscale_hostname="$TAILSCALE_HOSTNAME"
  fi
  log "Using Tailscale hostname=$tailscale_hostname"

  tailscaled --verbose ${TAILSCALED_VERBOSE:-0} --tun=userspace-networking &
  until tailscale up \
    --authkey=${TAILSCALE_AUTH_KEY} \
    --hostname="$tailscale_hostname" \
    --accept-dns \
    --accept-routes
  do
    log "Waiting for 5s for Tailscale to start"
    sleep 5
    retry_count=$((retry_count + 1))
    if [[ $retry_count -gt $max_retries ]]; then
      log "Tailscale failed to start after $max_retries retries"
      # Handle failure, e.g., send an alert, exit the script, or retry later
      exit 1
    fi
  done

  export ALL_PROXY=socks5://localhost:1055/
  log "Tailscale started"
fi
