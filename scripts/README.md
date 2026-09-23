# Scripts

This directory contains the reusable scripts/commands produced during the lab.

## Security note

The original Azure Arc onboarding script contained environment-specific identifiers such as subscription and tenant IDs. Those values are intentionally **not included** in this portfolio repository.

`arc-onboarding-template.sh` preserves the onboarding logic but uses placeholders.

`apache-log-bridge.sh` is the lab bridge used to convert Apache access-log lines into local syslog events on the legacy Metasploitable host.
