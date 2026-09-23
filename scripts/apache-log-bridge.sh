#!/usr/bin/env bash
set -euo pipefail

# Lab-only bridge for legacy Metasploitable 2.
# Watches Apache access.log and forwards new lines into local syslog.
# The existing syslog configuration then forwards the event to Ubuntu.

LOG_FILE="/var/log/apache2/access.log"
TAG="apache_access"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Apache access log not found: $LOG_FILE" >&2
  exit 1
fi

echo "Starting Apache access-log bridge: $LOG_FILE -> syslog tag=$TAG"
echo "Press Ctrl+C to stop."

sudo tail -n 0 -F "$LOG_FILE" | sudo /usr/bin/logger -t "$TAG"
