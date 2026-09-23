# Key commands used in the lab

This document captures the important commands used while building and troubleshooting the environment. Each command includes the practical reason it was used.

## Ubuntu — identity and network validation

```bash
lsb_release -a
```
Shows the Ubuntu version. Used to validate OS compatibility.

```bash
ip addr show enp0s8
```
Shows the Host-only network interface and confirms the expected lab IP.

```bash
curl -I https://management.azure.com
```
Tests outbound connectivity to an Azure endpoint. An HTTP error such as `400` still proves the endpoint was reachable from the VM.

## Ubuntu — Syslog receiver

```bash
sudo ss -lunp | grep ':514'
```
Confirms rsyslog is listening for UDP Syslog traffic on port 514.

```bash
sudo systemctl status rsyslog --no-pager
```
Checks the rsyslog service state.

## Ubuntu — AMA / Arc validation

```bash
sudo azcmagent show
```
Shows the Azure Arc agent status and connected resource information.

```bash
sudo azcmagent extension list
```
Shows Azure Arc extensions, including the Azure Monitor Agent.

```bash
sudo systemctl status extd --no-pager
```
Checks the Arc extension service used to manage extensions.

```bash
sudo systemctl status azuremonitoragent --no-pager
```
Checks the AMA service.

```bash
sudo ss -lnp | grep -E "28330|514"
```
Checks the key local ports used by the syslog receiver and AMA pipeline.

## Metasploitable — syslog forwarding

```bash
sudo cat /etc/syslog.conf
```
Shows the legacy syslogd configuration.

```text
*.* @192.168.56.104
```
The forwarding rule sends all syslog facilities to the Ubuntu collector over UDP 514.

```bash
sudo tail -20 /var/log/syslog
```
Shows recent local syslog events.

## Metasploitable — Apache logging

```bash
sudo tail -5 /var/log/apache2/access.log
```
Shows recent Apache HTTP requests recorded locally.

```bash
sudo apache2ctl configtest
```
Checks Apache configuration syntax before reloading it.

```bash
sudo /etc/init.d/apache2 reload
```
Reloads the old Apache service without fully stopping the web server.

## Metasploitable — Apache log bridge

```bash
sudo tail -n 0 -F /var/log/apache2/access.log | sudo /usr/bin/logger -t apache_access &
```
Lab-only bridge that watches Apache access.log and sends new entries to local syslog.

```bash
sudo tail -10 /var/log/syslog | grep apache_access
```
Confirms the Apache log bridge generated local syslog events.

## Kali — connectivity and reconnaissance

```bash
ping -c 4 192.168.56.102
```
Checks reachability of the vulnerable target.

```bash
nmap 192.168.56.102
```
Performs basic TCP service discovery against the target.

## Kali — SSH compatibility

```bash
ssh -o HostKeyAlgorithms=+ssh-rsa msfadmin@192.168.56.102
```
Allows the modern SSH client to negotiate the legacy RSA host-key algorithm required by the old Metasploitable server.

## Kali — HTTP validation

```bash
curl -I http://192.168.56.102
```
Checks that the Apache server is responding and shows HTTP headers.

```bash
curl -s http://192.168.56.102/ | head -30
```
Fetches the page and displays the first 30 lines for quick application discovery.

## KQL — SSH brute force

See:

- `../kql/ssh-brute-force-detection.kql`
- `../kql/syslog-ingestion-hunt.kql`
- `../kql/attack3-web-log-hunt.kql`
