# Attack simulation notes

> These commands were run only against the intentionally vulnerable Metasploitable 2 VM inside the isolated lab network.

## Attack 1 — Network reconnaissance

### Connectivity check

```bash
ping -c 4 192.168.56.102
```

Checks that the target is reachable before testing it.

### Port/service discovery

```bash
nmap 192.168.56.102
```

Enumerates exposed TCP services on the lab target.

### Result

The scan exposed multiple services including FTP, SSH, Telnet, SMTP, DNS, HTTP, SMB, NFS, MySQL, PostgreSQL, VNC, IRC and other legacy services.

### Detection outcome

No useful Nmap-specific evidence was visible in the current Sentinel Syslog dataset. The result was treated as a telemetry gap and documented as such.

---

## Attack 2 — SSH brute-force simulation

### Connect using legacy SSH compatibility

```bash
ssh -o HostKeyAlgorithms=+ssh-rsa msfadmin@192.168.56.102
```

Allows the modern Kali SSH client to connect to the old target's RSA host-key algorithm.

### Generate controlled failed authentication attempts

Repeat the SSH connection attempts and deliberately use an incorrect password.

```text
Username: msfadmin
Password: WrongPassword123!
```

The goal was to generate failed authentication telemetry, not to compromise the host.

### Detection query

See:

```text
../kql/ssh-brute-force-detection.kql
```

### Detection result

```text
Source IP: 192.168.56.101
Failed attempts: 5
Window: 5 minutes
```

The query was promoted into a Sentinel Analytics Rule and generated a real incident.

---

## Attack 3 — Web application / SQL injection simulation

### Discover the Apache server

```bash
curl -I http://192.168.56.102
```

Checks that the HTTP service is reachable and reveals the web-server headers.

### Discover the vulnerable application

```bash
curl -s http://192.168.56.102/ | head -30
```

Retrieves the homepage and displays the first part of the response for application discovery.

### Check Mutillidae

```bash
curl -I http://192.168.56.102/mutillidae/
```

Checks whether the intentionally vulnerable Mutillidae application is available.

### Inspect the login form

```bash
curl -s "http://192.168.56.102/mutillidae/index.php?page=login.php" | grep -iE "<form|input|action|method"
```

Looks for the form action, HTTP method and input fields so the test can be performed against the intended endpoint.

### Controlled SQL injection request

```bash
curl -i -X POST "http://192.168.56.102/mutillidae/index.php?page=login.php" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=' OR '1'='1" \
  --data-urlencode "login-php-submit-button=Login"
```

Sends a deliberately crafted SQL injection payload to the training application's login endpoint.

### Evidence observed

Apache recorded the request in:

```text
/var/log/apache2/access.log
```

The key telemetry lesson was that the attack reached the web application but initially did not appear in Sentinel because Apache access logs were not part of the existing Syslog collection path.

### Log bridge used for the lab

```bash
sudo tail -n 0 -F /var/log/apache2/access.log | sudo /usr/bin/logger -t apache_access &
```

Watches Apache access.log and sends new records to local syslog so they can follow the existing Metasploitable → Ubuntu → AMA → Sentinel route.

### Current status

The Apache access-log → local syslog bridge was verified on Metasploitable. End-to-end ingestion of those new `apache_access` events into Sentinel was still pending at the time of the portfolio write-up.
