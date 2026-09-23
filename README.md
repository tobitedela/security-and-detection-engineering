# End-to-End Security Engineering & Threat Detection Project

> A hands-on cybersecurity project focused on **attack simulation, telemetry engineering, detection, investigation and incident response**.

## Project summary

I built a small SOC environment that connects an intentionally vulnerable Linux host to Microsoft Sentinel through an Ubuntu log-forwarding server.

The goal was not simply to install security tools. The goal was to understand the SOC workflow from first principles:

**Attack → Generate evidence → Collect telemetry → Normalize/ingest → Detect → Investigate → Respond → Identify telemetry gaps → Improve coverage**

The lab used:

- **Kali Linux** — attack simulation and reconnaissance
- **Metasploitable 2** — intentionally vulnerable target
- **Ubuntu Server** — log forwarder / telemetry boundary
- **Azure Arc** — connected the on-prem/VirtualBox Linux server to Azure
- **Azure Monitor Agent (AMA)** — collected telemetry for Azure
- **Data Collection Rule (DCR)** — defined what telemetry was collected and where it was sent
- **Log Analytics Workspace** — centralized log storage
- **Microsoft Sentinel** — SIEM, detection engineering and incident management
- **Microsoft Defender XDR** — investigation context and unified security operations workflow
- **KQL** — hunting and detection logic

---

## 1. Architecture

```text
                         VIRTUALBOX / HOME LAB

     Kali Linux                         Metasploitable 2
   192.168.56.101                       192.168.56.102
         │                                      │
         │ Recon / attack                       │ Syslog + Apache logs
         │                                      │
         └─────────────── Host-only ────────────┘
                                                │
                                                │ UDP 514
                                                ▼
                                  Ubuntu Log Forwarder
                                     192.168.56.104
                                  ┌───────────────────┐
                                  │ rsyslog           │
                                  │ Azure Arc         │
                                  │ Azure Monitor     │
                                  │ Agent (AMA)       │
                                  └─────────┬─────────┘
                                            │
                                            ▼
                                   Data Collection Rule
                                            │
                                            ▼
                                  Log Analytics Workspace
                                      SecurityOperations
                                            │
                                            ▼
                                    Microsoft Sentinel
                                            │
                                    ┌───────┴────────┐
                                    ▼                ▼
                               KQL Hunting     Analytics Rules
                                                     │
                                                     ▼
                                                  Incident
```

### Network design decision

Metasploitable 2 was intentionally kept on the **Host-only network**. It was not given Internet access. Ubuntu was the controlled bridge between the isolated lab network and Azure because it needed outbound connectivity for Arc/AMA and Azure services.

This design reduces unnecessary exposure of the deliberately vulnerable VM while still allowing the lab to demonstrate a realistic logging architecture.

![screenshots](/screenshots/01-lab-architecture.png)

---

## 2. Objectives

The project was designed around five practical SOC objectives:

1. Build a functioning Linux-to-Sentinel telemetry pipeline.
2. Simulate common attack behaviors from Kali against an intentionally vulnerable host.
3. Write KQL to hunt for attack evidence.
4. Turn validated KQL into Sentinel Analytics Rules and incidents.
5. Identify telemetry blind spots and improve the logging architecture instead of assuming the SIEM can see everything.

---

## 3. Environment

| Component | Role | Address / Location |
|---|---|---|
| Kali Linux | Attack simulation | `192.168.56.101` |
| Metasploitable 2 | Vulnerable target | `192.168.56.102` |
| Ubuntu Log Forwarder | Syslog receiver + Azure-connected collector | `192.168.56.104` |
| Log Analytics Workspace | Central log store | `SecurityOperations` / East US |
| Sentinel DCR | Linux Syslog collection | `DCR-Syslog-SocLab` |
| Azure Arc resource | Hybrid connection for Ubuntu | `UbuntuLogForwarderVM` / Canada Central |

> **Portfolio note:** Environment-specific subscription IDs, tenant IDs and authentication values should not be committed to GitHub. The portfolio version of the onboarding script uses placeholders.

---

## 4. What I built

### 4.1 Azure Arc connectivity

I connected the Ubuntu log-forwarding VM to Azure using Azure Arc.

Validation:

```bash
sudo azcmagent show
```

The Arc agent reported the machine as **Connected** and exposed the local VM as an Azure-managed resource.

### Skills demonstrated

- Azure Arc onboarding
- Hybrid infrastructure concepts
- Linux administration
- Azure resource management
- Troubleshooting agent connectivity

![screenshots](/screenshots/02-azure-arc-connected.png)

---

## 5. Azure Monitor Agent and DCR

Azure Monitor Agent (AMA) was installed on the Ubuntu log forwarder.

The final environment showed the AMA extension enabled on the Arc-connected Ubuntu VM.

The DCR was configured for **Linux Syslog** and associated with `UbuntuLogForwarderVM`.

The selected destination was the `SecurityOperations` Log Analytics workspace.

### Data flow

```text
Linux Syslog
     ↓
Azure Monitor Agent
     ↓
DCR-Syslog-SocLab
     ↓
SecurityOperations
     ↓
Syslog table
```

### Validation examples

```bash
sudo azcmagent extension list
sudo systemctl status azuremonitoragent --no-pager
sudo ss -lnp | grep -E "28330|514"
```

These checks were used to verify the extension state, AMA service state and local log-ingestion ports.

### Screenshot placeholders

> **[SCREENSHOT 03 — AMA ENABLED]**  
> Show the AMA extension as `ENABLED` on Ubuntu.

> **[SCREENSHOT 04 — DCR CONFIGURATION]**  
> Show `DCR-Syslog-SocLab`, Linux Syslog data source, selected facilities/severity and the `SecurityOperations` destination.

> **[SCREENSHOT 05 — DCR DEPLOYMENT SUCCESS]**  
> Show the successful DCR deployment/association.

---

## 6. Syslog ingestion

Metasploitable 2 uses an older syslog implementation. Its configuration was set to forward syslog events to Ubuntu over UDP 514:

```text
*.* @192.168.56.104
```

Ubuntu was configured to receive UDP 514.

Validation included checking that rsyslog was listening and using packet capture to prove the network flow.

Example:

```bash
sudo ss -lunp | grep ':514'
```

Packet capture showed traffic similar to:

```text
192.168.56.102.514 > 192.168.56.104.514: SYSLOG
```

### Result

**Metasploitable → Ubuntu Syslog was successfully verified.**

### Screenshot placeholders

> **[SCREENSHOT 06 — UDP 514 LISTENING]**  
> Show Ubuntu listening on UDP 514.

> **[SCREENSHOT 07 — TCPDUMP PROOF]**  
> Show the Metasploitable-to-Ubuntu Syslog packets.

> **[SCREENSHOT 08 — LOG ANALYTICS SYSLOG EVENTS]**  
> Show Metasploitable events appearing in the `Syslog` table.

---

# 7. Attack simulations

## Attack 1 — Network reconnaissance

### Objective

Simulate an attacker performing basic network reconnaissance against the vulnerable host.

### Action

From Kali:

```bash
nmap 192.168.56.102
```

This identified a large number of exposed TCP services on the intentionally vulnerable host, including SSH, FTP, HTTP, SMB, MySQL, PostgreSQL, VNC and other services.

### Outcome

The scan successfully demonstrated the target's exposed attack surface.

### SOC lesson

A SIEM cannot detect activity that the underlying telemetry does not capture.

The Nmap scan did **not** produce an obvious corresponding event in the current Sentinel Syslog dataset. This became a deliberate telemetry-gap finding rather than a failed project result.

### Key lesson

**Detection depends on telemetry.**

For network reconnaissance, useful data sources could include network sensors, firewalls, IDS/IPS, flow logs, endpoint telemetry or a host-based network monitoring source. Plain Linux Syslog alone is not enough to reliably identify an Nmap scan.

### Screenshot placeholders

> **[SCREENSHOT 09 — NMAP RESULTS]**  
> Show the Nmap result and exposed services.

> **[SCREENSHOT 10 — SENTINEL HUNT / NO NETWORK-SCAN TELEMETRY]**  
> Show the Sentinel query/result demonstrating that the current Syslog source did not expose useful Nmap evidence.

---

## Attack 2 — SSH brute-force simulation

### Objective

Generate repeated failed SSH authentication attempts and detect them as a credential-access behavior.

### Action

From Kali, repeated SSH attempts were made against Metasploitable using an incorrect password.

Metasploitable generated Linux authentication logs containing messages such as:

```text
Failed password for msfadmin from 192.168.56.101
```

Those events were forwarded through the existing Syslog → AMA → DCR → Log Analytics → Sentinel pipeline.

### Detection logic

```kusto
Syslog
| where Computer == "192.168.56.102"
| where ProcessName == "sshd"
| where SyslogMessage contains "Failed password"
| extend SourceIP = extract(@"from ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)", 1, SyslogMessage)
| summarize FailedAttempts = count() by SourceIP, bin(TimeGenerated, 5m)
| where FailedAttempts >= 5
| order by FailedAttempts desc
```

### Logic in plain English

1. Look only at Metasploitable.
2. Look only at SSH daemon events.
3. Keep failed-password events.
4. Extract the source IP.
5. Count failures per source over five-minute windows.
6. Alert when there are at least five failures.

### Outcome

The query identified:

```text
SourceIP:       192.168.56.101
FailedAttempts: 5
```

A Microsoft Sentinel Analytics Rule was then created:

**SSH Brute Force - Multiple Failed Logins**

Configured properties included:

- Type: Scheduled
- Severity: Medium
- Tactic: Credential Access
- MITRE technique: T1110
- Sub-technique: T1110.001

The rule generated a **real Sentinel incident** containing the alert/event and the incident was assigned for investigation.

### Skills demonstrated

- Linux authentication log analysis
- KQL
- Detection engineering
- MITRE ATT&CK mapping
- Threshold-based detection
- Sentinel Analytics Rules
- Incident creation and triage

### Screenshot placeholders

> **[SCREENSHOT 11 — FAILED SSH LOGS]**  
> Show the failed authentication events in Sentinel/Log Analytics.

> **[SCREENSHOT 12 — KQL DETECTION RESULT]**  
> Show the query returning `192.168.56.101` with five failed attempts.

> **[SCREENSHOT 13 — SENTINEL ANALYTICS RULE]**  
> Show the rule configuration.

> **[SCREENSHOT 14 — SENTINEL INCIDENT]**  
> Show `SSH Brute Force - Multiple Failed Logins` as a Sentinel incident.

---

## Attack 3 — Web application / SQL injection simulation

### Objective

Simulate an SQL injection attempt against the deliberately vulnerable Mutillidae application and build the telemetry required to hunt it.

### Reconnaissance

From Kali, the Apache web server and the vulnerable Mutillidae application were identified.

The login endpoint was discovered and tested with a controlled SQL injection payload in a lab environment.

### Action

A controlled POST request was sent to the Mutillidae login page using an SQL injection payload.

The important point was not simply whether the application returned a result. The SOC goal was to determine:

**Did the attack produce evidence that Sentinel could see?**

### Initial result

The SQL injection request reached Apache successfully.

Apache recorded the request in:

```text
/var/log/apache2/access.log
```

Example evidence included a POST to:

```text
/mutillidae/index.php?page=login.php
```

However, the existing Sentinel Syslog pipeline did not contain Apache access-log records.

### Telemetry engineering response

Because Metasploitable 2 is an old and intentionally vulnerable operating system, I avoided putting an Internet-facing Azure agent directly on it.

Instead, I kept the existing architecture and built a local bridge:

```text
Apache access.log
       ↓
tail -F
       ↓
logger -t apache_access
       ↓
Metasploitable syslogd
       ↓ UDP 514
Ubuntu
       ↓
AMA / DCR / Log Analytics / Sentinel
```

The bridge was tested locally and successfully produced:

```text
apache_access: 192.168.56.101 ... "GET / HTTP/1.1" 200 ...
```

### Current status

The **Apache → local syslog bridge was verified on Metasploitable**.

The final **Ubuntu → Sentinel verification for the newly bridged Apache events was still pending** at the time this portfolio package was prepared.

That distinction is intentional: I would rather document an open telemetry-validation step than claim a detection that was never proven end-to-end.

### SOC lesson

This attack demonstrated a core detection-engineering principle:

> **The presence of an attack does not guarantee the presence of telemetry.**

The first SQL injection test showed that an attack can reach the web server while remaining invisible to the SIEM because the relevant application/web logs were not being collected.

### Next improvement

Once Apache events are confirmed in Sentinel, the next step is to build a web-attack detection based on the actual fields available in the collected Apache telemetry.

A stronger production design could use a web application firewall, ModSecurity/application logs, endpoint telemetry or a supported custom-log ingestion pattern where appropriate.

### Screenshot placeholders

> **[SCREENSHOT 15 — MUTILLIDAE / WEB TARGET]**  
> Show the vulnerable application page used for the lab.

> **[SCREENSHOT 16 — APACHE ACCESS LOG]**  
> Show the SQLi request appearing in `/var/log/apache2/access.log`.

> **[SCREENSHOT 17 — APACHE → SYSLOG BRIDGE]**  
> Show `apache_access` events in `/var/log/syslog`.

> **[SCREENSHOT 18 — SENTINEL APACHE EVENT]**  
> Insert once the event is verified in Sentinel.

> **[SCREENSHOT 19 — WEB ATTACK KQL]**  
> Insert once the final detection rule is built and tested.

---

# 8. Detection engineering approach

The detection workflow used in this project was:

```text
1. Simulate behavior
        ↓
2. Identify what the endpoint actually logs
        ↓
3. Confirm the log reaches the collector
        ↓
4. Confirm the event reaches Log Analytics
        ↓
5. Write a hunting query
        ↓
6. Validate true positives / expected noise
        ↓
7. Convert query into Sentinel Analytics Rule
        ↓
8. Map to MITRE ATT&CK
        ↓
9. Generate / triage incident
        ↓
10. Identify missing telemetry and improve coverage
```

This helped avoid a common beginner mistake: **writing detection logic before verifying the evidence exists.**

---

# 9. Troubleshooting lessons

## Azure Arc

An early onboarding attempt used an unsupported/older Ubuntu environment for the lab. The VM was rebuilt using Ubuntu 24.04 LTS and Arc onboarding succeeded.

### Lesson

Check platform support before spending time debugging the agent.

---

## Azure Monitor Agent extension

The AMA extension initially became stuck during deletion. The extension service (`extd`) had to be restored before the extension could be cleanly reinstalled.

### Lesson

Agent/extension troubleshooting needs to consider both the Azure resource state and the Linux-side extension service.

---

## Legacy SSH compatibility

Modern Kali rejected the very old SSH server algorithms offered by Metasploitable 2 during initial testing.

The working administrative SSH command used:

```bash
ssh -o HostKeyAlgorithms=+ssh-rsa msfadmin@192.168.56.102
```

### Lesson

Old systems can fail for reasons unrelated to credentials. Protocol and algorithm compatibility matter during security testing.

---

## Hydra compatibility issue

Hydra initially failed because the old target's SSH MAC algorithms did not match those supported by the modern client path being used.

Instead of weakening the modern client stack just to make a brute-force tool work, controlled failed SSH authentications were generated manually for the detection exercise.

### Lesson

The SOC objective was to generate trustworthy authentication telemetry — not to force a specific attack tool to work.

---

# 10. Security boundaries and design decisions

### Why Metasploitable was not given Internet access

Metasploitable 2 is intentionally vulnerable. Giving it unnecessary outbound or inbound Internet exposure would introduce risk without adding value to the exercise.

### Why Ubuntu was the Azure boundary

Ubuntu could safely have:

- a NAT interface for Azure connectivity
- a Host-only interface for the isolated attack lab

This created a simple controlled boundary:

```text
Host-only attack network → Ubuntu → Azure
```

rather than connecting the vulnerable target directly to Azure-facing infrastructure.

---

# 11. Skills demonstrated

## Security Operations

- SOC workflow from telemetry to incident
- Attack simulation in a controlled lab
- Threat hunting
- Detection engineering
- Incident creation and triage
- Telemetry gap analysis

## Microsoft Security

- Microsoft Sentinel
- Microsoft Defender XDR
- Azure Monitor Agent
- Data Collection Rules
- Log Analytics
- Azure Arc
- KQL
- MITRE ATT&CK mapping

## Linux

- SSH
- systemd/service troubleshooting
- Apache
- Syslog / syslogd
- rsyslog
- network sockets
- packet capture
- log files
- process inspection
- configuration management

## Offensive security fundamentals

- Nmap reconnaissance
- HTTP enumeration
- SSH authentication attacks
- SQL injection simulation
- Vulnerable application testing

## Analytical thinking

- First-principles troubleshooting
- Hypothesis-driven investigation
- Evidence-based validation
- Separation of attack success from detection success
- Identifying and closing telemetry gaps

---



# 12. Future improvements

This project can be extended into a larger detection-engineering portfolio.

### Planned attack scenarios

- PowerShell execution
- suspicious process execution
- malware download/execution
- persistence
- privilege escalation
- lateral movement
- credential dumping
- data staging and exfiltration
- web attacks beyond SQL injection

### Planned detections

For each scenario:

```text
Attack
→ Telemetry source
→ Raw evidence
→ KQL hunt
→ Detection rule
→ MITRE mapping
→ Alert
→ Incident
→ Investigation
→ Response
→ Lessons learned
```

### Telemetry improvements

- Endpoint telemetry
- Microsoft Defender for Endpoint integration
- Network telemetry
- Firewall/IDS events
- Web server logs
- Application logs
- Authentication telemetry
- File integrity/process telemetry

---

# 13. Repository structure

```text
soc-sentinel-lab/
│
├── README.md
├── .gitignore
│
├── scripts/
│   ├── README.md
│   ├── arc-onboarding-template.sh
│   └── apache-log-bridge.sh
│
├── kql/
│   ├── ssh-brute-force-detection.kql
│   ├── syslog-ingestion-hunt.kql
│   └── attack3-web-log-hunt.kql
│
├── docs/
│   └── commands-used.md
│
└── screenshots/
    └── README.md
```

---

# 14. Important portfolio note

This repository represents a **hands-on home cybersecurity lab**, not a production enterprise SOC.

The value of the project is the demonstrated engineering process:

**build → attack → observe → detect → investigate → troubleshoot → improve**

Environment-specific secrets and identifiers should remain outside GitHub.
