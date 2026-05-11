# 🛡️ OpenBao HA Cluster with HAProxy & Docker

A clean, user-friendly deployment guide for running a **3-node OpenBao HA cluster** with **Raft Integrated Storage** and a **single HAProxy load balancer entry point** using **Docker Compose** on Ubuntu Server.

> Current setup is designed for an internal/private environment. TLS and firewall hardening are intentionally skipped for now.

---

## 🎯 Why We Are Deploying OpenBao

At the moment, our applications do **not** have a centralized environment variable or secret management system.  
This means `.env` values need to be updated manually by logging into individual servers, which can become difficult to manage as the number of services and servers grows.

This creates common operational problems:

- Environment variables are scattered across multiple servers.
- Updates require manual server access.
- Different servers may accidentally have different `.env` values.
- Secret rotation becomes harder.
- There is no single controlled place for application secrets.
- Manual changes increase the risk of human error.

OpenBao helps solve this by acting as a **centralized secret management server**. Instead of storing important values directly inside each server’s `.env` file, applications can fetch required secrets and configuration values from OpenBao.

In this setup, OpenBao is deployed in **High Availability mode**, so secret access can continue even if one OpenBao node goes down.

```text
Before:
  App Server 1 -> local .env
  App Server 2 -> local .env
  App Server 3 -> local .env

After:
  App Servers -> HAProxy -> OpenBao HA Cluster -> centralized secrets
```

✅ Centralized secret storage  
✅ Easier secret updates  
✅ Reduced manual server changes  
✅ Better consistency across application servers  
✅ HA/fail-safe OpenBao backend  
✅ Foundation for future automated secret injection  

---

## 🔐 What is OpenBao?

**OpenBao** is an open-source secrets management system. It is used to securely store, manage, access, and rotate sensitive information such as:

- Application environment variables
- API keys
- Database credentials
- Tokens
- Passwords
- Certificates
- Service credentials

OpenBao allows applications and administrators to retrieve secrets from a central location instead of keeping sensitive values scattered across many servers or configuration files.

In our case, OpenBao will be used as the central place for managing application `.env` values and other secrets.  
The HA setup ensures that this central secret service remains available even if one OpenBao node becomes unavailable.


---

## 📌 Table of Contents

- [Why We Are Deploying OpenBao](#-why-we-are-deploying-openbao)
- [What is OpenBao?](#-what-is-openbao)
- [1. Architecture Overview](#1-architecture-overview)
- [2. Server Inventory](#2-server-inventory)
- [3. What This Setup Provides](#3-what-this-setup-provides)
- [4. Port Usage](#4-port-usage)
- [5. Docker Installation](#5-docker-installation)
- [6. Hostname Resolution](#6-hostname-resolution)
- [7. Directory Layout](#7-directory-layout)
- [8. OpenBao Docker Deployment](#8-openbao-docker-deployment)
- [9. OpenBao Node Configurations](#9-openbao-node-configurations)
- [10. Initialize and Unseal OpenBao](#10-initialize-and-unseal-openbao)
- [11. Verify Raft Cluster Health](#11-verify-raft-cluster-health)
- [12. HAProxy Docker Deployment](#12-haproxy-docker-deployment)
- [13. Single Entry Point](#13-single-entry-point)
- [14. Failover Behavior](#14-failover-behavior)
- [15. Daily Operations](#15-daily-operations)
- [16. Backup Procedure](#16-backup-procedure)
- [17. Troubleshooting Notes](#17-troubleshooting-notes)
- [18. Security Notes](#18-security-notes)
- [19. Future Improvements](#19-future-improvements)

---

## 1. Architecture Overview

```text
                         Users / Apps / Admins
                                  |
                                  |
                         Single Entry Point
                         http://10.9.0.70:8200
                                  |
                                  |
                            HAProxy Docker
                              10.9.0.70
                                  |
              ------------------------------------------------
              |                      |                       |
              |                      |                       |
        OpenBao Node 1         OpenBao Node 2          OpenBao Node 3
            bao1                   bao2                    bao3
         10.9.0.71              10.9.0.72               10.9.0.73
         API  : 8200            API  : 8200             API  : 8200
         Raft : 8201            Raft : 8201             Raft : 8201
              |                      |                       |
              ------------------------------------------------
                         Raft Replication Cluster
```

---

## 2. Server Inventory

| Role | Hostname | IP Address | Deployment |
|---|---|---:|---|
| Load Balancer | `haproxy` | `10.9.0.70` | HAProxy Docker |
| OpenBao Node 1 | `bao1` | `10.9.0.71` | OpenBao Docker |
| OpenBao Node 2 | `bao2` | `10.9.0.72` | OpenBao Docker |
| OpenBao Node 3 | `bao3` | `10.9.0.73` | OpenBao Docker |

---

## 3. What This Setup Provides

✅ 3-node OpenBao HA cluster  
✅ Raft Integrated Storage  
✅ HAProxy as a single client entry point  
✅ Automatic routing to the active OpenBao leader  
✅ One OpenBao node failure tolerance  
✅ Docker Compose based deployment  
✅ No native OpenBao installation  
✅ No manual certificate setup  
✅ No manual firewall setup  

⚠️ Current limitations:

- HAProxy itself is still a single point of failure.
- Traffic is HTTP, not HTTPS.
- Manual unseal is required after node/container restart.

---

## 4. Port Usage

| Port | Component | Purpose |
|---:|---|---|
| `8200` | OpenBao | API and UI |
| `8201` | OpenBao | Raft cluster communication |
| `8200` | HAProxy | Client-facing OpenBao endpoint |
| `8404` | HAProxy | HAProxy statistics page |

Client access URL:

```text
http://10.9.0.70:8200
```

HAProxy statistics URL:

```text
http://10.9.0.70:8404/stats
```

---

## 5. Docker Installation

Docker was installed using Ubuntu packages:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2
```

Verify Docker:

```bash
docker --version
docker compose version
```

If you want to run Docker without `sudo`, add your user to the Docker group:

```bash
sudo usermod -aG docker "$USER"
```

Then log out and log in again.

> In this guide, commands use `sudo docker` so they work immediately without requiring group changes.

---

## 6. Hostname Resolution

Edit `/etc/hosts` on **all 4 servers** so each node can resolve the HAProxy and OpenBao node names locally.

Run:

```bash
sudo nano /etc/hosts
```

Add or confirm the following entries:

```text
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

10.9.0.70 bao-lb.local bao-lb
10.9.0.71 bao1.local bao1
10.9.0.72 bao2.local bao2
10.9.0.73 bao3.local bao3
```

Verify hostname resolution:

```bash
getent hosts bao-lb
getent hosts bao1
getent hosts bao2
getent hosts bao3
```

Expected result:

```text
10.9.0.70      bao-lb.local bao-lb
10.9.0.71      bao1.local bao1
10.9.0.72      bao2.local bao2
10.9.0.73      bao3.local bao3
```

---

## 7. Directory Layout

### On each OpenBao node

```text
/opt/openbao/
├── docker-compose.yml
└── config/
    └── openbao.hcl
```

### On HAProxy node

```text
/opt/haproxy/
├── docker-compose.yml
└── haproxy.cfg
```

---

## 8. OpenBao Docker Deployment

Run this on each OpenBao node:

```bash
sudo mkdir -p /opt/openbao/config
cd /opt/openbao
```

Create `/opt/openbao/docker-compose.yml`:

```yaml
services:
  openbao:
    image: openbao/openbao:latest
    container_name: openbao
    restart: unless-stopped
    command: server -config=/openbao/config/openbao.hcl
    ports:
      - "8200:8200"
      - "8201:8201"
    volumes:
      - ./config:/openbao/config
      - openbao-data:/openbao/file
      - openbao-logs:/openbao/logs

volumes:
  openbao-data:
  openbao-logs:
```

Start OpenBao:

```bash
cd /opt/openbao
sudo docker compose up -d
```

Check container:

```bash
sudo docker ps
```

Check logs:

```bash
sudo docker logs -f openbao
```

---

## 9. OpenBao Node Configurations

> Important: each node has a different `cluster_addr` and `node_id`.

---

### 9.1 `bao1` Configuration

Node:

```text
10.9.0.71
```

File:

```text
/opt/openbao/config/openbao.hcl
```

```hcl
ui = true
disable_mlock = true

api_addr     = "http://10.9.0.70:8200"
cluster_addr = "http://10.9.0.71:8201"

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = true
}

storage "raft" {
  path    = "/openbao/file"
  node_id = "bao1"

  performance_multiplier = 1
}
```

---

### 9.2 `bao2` Configuration

Node:

```text
10.9.0.72
```

File:

```text
/opt/openbao/config/openbao.hcl
```

```hcl
ui = true
disable_mlock = true

api_addr     = "http://10.9.0.70:8200"
cluster_addr = "http://10.9.0.72:8201"

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = true
}

storage "raft" {
  path    = "/openbao/file"
  node_id = "bao2"

  retry_join {
    leader_api_addr = "http://10.9.0.71:8200"
  }

  retry_join {
    leader_api_addr = "http://10.9.0.73:8200"
  }

  performance_multiplier = 1
}
```

---

### 9.3 `bao3` Configuration

Node:

```text
10.9.0.73
```

File:

```text
/opt/openbao/config/openbao.hcl
```

```hcl
ui = true
disable_mlock = true

api_addr     = "http://10.9.0.70:8200"
cluster_addr = "http://10.9.0.73:8201"

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = true
}

storage "raft" {
  path    = "/openbao/file"
  node_id = "bao3"

  retry_join {
    leader_api_addr = "http://10.9.0.71:8200"
  }

  retry_join {
    leader_api_addr = "http://10.9.0.72:8200"
  }

  performance_multiplier = 1
}
```

---

## 10. Initialize and Unseal OpenBao

### 10.1 Initialize Cluster

Initialization is done **only once** on the first node, `bao1`.

Run on `bao1`:

```bash
sudo sh -c 'docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator init -key-shares=5 -key-threshold=3 > /root/openbao-init.txt'
```

View the generated keys:

```bash
sudo cat /root/openbao-init.txt
```

The output contains:

```text
5 unseal keys
1 initial root token
```

🚨 Store these securely.

---

### 10.2 Unseal a Node

Run this command three times and enter three different unseal keys:

```bash
sudo docker exec -it -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator unseal
```

Check status:

```bash
sudo docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao bao status
```

Expected:

```text
Initialized    true
Sealed         false
HA Enabled     true
```

Repeat unseal on:

```text
bao1
bao2
bao3
```

---

## 11. Verify Raft Cluster Health

### 11.1 List Raft Peers

Run from any unsealed OpenBao node:

```bash
sudo docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator raft list-peers
```

Expected:

```text
Node    Address           State       Voter
----    -------           -----       -----
bao1    10.9.0.71:8201    leader      true
bao2    10.9.0.72:8201    follower    true
bao3    10.9.0.73:8201    follower    true
```

The leader may change after failover.

---

### 11.2 Check Autopilot State

```bash
sudo docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator raft autopilot state
```

Healthy output:

```text
Healthy:                         true
Failure Tolerance:               1
Leader:                          bao1
Voters:
   bao1
   bao2
   bao3
```

✅ This means the cluster can tolerate one OpenBao node failure.

---

## 12. HAProxy Docker Deployment

Run on the HAProxy node:

```text
10.9.0.70
```

Create directory:

```bash
sudo mkdir -p /opt/haproxy
cd /opt/haproxy
```

Create `/opt/haproxy/haproxy.cfg`:

```haproxy
global
    log stdout format raw local0
    maxconn 10000

defaults
    log global
    mode http
    option httplog
    option dontlognull
    option redispatch

    timeout connect 5s
    timeout client  120s
    timeout server  120s
    timeout http-request 10s
    timeout http-keep-alive 10s

frontend openbao_frontend
    bind *:8200
    mode http

    option forwardfor
    http-request set-header X-Forwarded-Proto http
    http-request set-header X-Forwarded-Port 8200

    default_backend openbao_active_backend

backend openbao_active_backend
    mode http
    balance first

    option httpchk GET /v1/sys/health
    http-check expect status 200

    default-server inter 2s fall 3 rise 2

    server bao1 10.9.0.71:8200 check
    server bao2 10.9.0.72:8200 check
    server bao3 10.9.0.73:8200 check

listen haproxy_stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
```

Create `/opt/haproxy/docker-compose.yml`:

```yaml
services:
  haproxy:
    image: haproxy:lts
    container_name: haproxy-openbao
    restart: unless-stopped
    ports:
      - "8200:8200"
      - "8404:8404"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
```

Start HAProxy:

```bash
cd /opt/haproxy
sudo docker compose up -d
```

Check HAProxy logs:

```bash
sudo docker logs -f haproxy-openbao
```

---

## 13. Single Entry Point

All clients, applications, and admins should use:

```text
http://10.9.0.70:8200
```

Example:

```bash
export BAO_ADDR=http://10.9.0.70:8200
```

Using the single entry point ensures clients always reach the active OpenBao node through HAProxy.

---

## 14. Failover Behavior

HAProxy checks every OpenBao backend using:

```text
GET /v1/sys/health
```

The HAProxy backend accepts only:

```text
HTTP 200
```

OpenBao health behavior:

| OpenBao Node State | HTTP Code | HAProxy Action |
|---|---:|---|
| Active leader | `200` | Used |
| Standby follower | `429` | Not used |
| Sealed | `503` | Not used |
| Uninitialized | `501` | Not used |

### What happens during leader failure?

If the active leader goes down:

1. Raft detects leader loss.
2. Remaining voters elect a new leader.
3. New leader returns HTTP `200`.
4. HAProxy routes traffic to the new leader automatically.

There may be a short failover delay of a few seconds.

---

## 15. Daily Operations

### Start OpenBao

```bash
cd /opt/openbao
sudo docker compose up -d
```

### Stop OpenBao

```bash
cd /opt/openbao
sudo docker compose stop openbao
```

### Restart OpenBao

```bash
cd /opt/openbao
sudo docker compose restart openbao
```

### View OpenBao Logs

```bash
sudo docker logs -f openbao
```

### Check OpenBao Status

```bash
sudo docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao bao status
```

### Start HAProxy

```bash
cd /opt/haproxy
sudo docker compose up -d
```

### Restart HAProxy

```bash
cd /opt/haproxy
sudo docker compose restart haproxy
```

### View HAProxy Logs

```bash
sudo docker logs -f haproxy-openbao
```

### Check HAProxy Stats

Open in browser:

```text
http://10.9.0.70:8404/stats
```

---

## 16. Backup Procedure

Raft snapshots should be taken regularly.

Create backup directory on an OpenBao node:

```bash
sudo mkdir -p /opt/openbao/backup
```

Take snapshot:

```bash
sudo docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator raft snapshot save /openbao/file/openbao-raft.snap
```

Copy snapshot to host:

```bash
sudo docker cp openbao:/openbao/file/openbao-raft.snap /opt/openbao/backup/openbao-raft-$(date +%F-%H%M).snap
```

Verify:

```bash
ls -lh /opt/openbao/backup/
sha256sum /opt/openbao/backup/*.snap
```

Recommended:

- Store snapshots outside the OpenBao nodes.
- Encrypt backup storage.
- Test restore in a separate environment.

---

## 17. Troubleshooting Notes

### 17.1 OpenBao Container Restart Loop

Check logs:

```bash
sudo docker logs -f openbao
```

### 17.2 Raft DB Path Error

If you see an error similar to:

```text
failed to open bolt file: open /openbao/file/raft/vault.db: no such file or directory
```

Use this storage path instead:

```hcl
storage "raft" {
  path = "/openbao/file"
}
```

### 17.3 Do Not Mount Config as Read-Only

Avoid:

```yaml
- ./config:/openbao/config:ro
```

Use:

```yaml
- ./config:/openbao/config
```

### 17.4 Node is Sealed After Restart

Unseal it again:

```bash
sudo docker exec -it -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator unseal
sudo docker exec -it -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator unseal
sudo docker exec -it -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator unseal
```

### 17.5 Avoid Accidental Data Loss

Do **not** run this on initialized nodes unless intentionally wiping data:

```bash
docker compose down -v
```

This deletes Docker volumes, including local Raft data.

Safe stop:

```bash
docker compose stop
```

Safe restart:

```bash
docker compose restart
```

---

## 18. Security Notes

### 18.1 `.env` Management Direction

The current environment still depends on manually maintained `.env` files on application servers.

Target direction:

```text
Application servers should gradually move from local static .env secrets
to centralized secret retrieval from OpenBao.
```

Recommended future approach:

- Store sensitive `.env` values in OpenBao.
- Keep only non-sensitive runtime variables locally when required.
- Use application-side secret retrieval or deployment-time injection.
- Apply OpenBao policies so each application can access only its own secrets.
- Rotate secrets centrally from OpenBao instead of manually editing every server.


Current setup intentionally uses:

```text
HTTP only
No TLS
No manual firewall configuration
Manual unseal
```

This is acceptable for a private lab or controlled internal environment.

For production, add:

- TLS certificates
- Firewall restrictions
- Auto-unseal
- Audit logging
- Snapshot automation
- Monitoring and alerting
- Least-privilege policies
- Root token rotation
- HAProxy high availability

---

## 19. Future Improvements

Recommended future architecture:

```text
                         Users / Apps / Admins
                                  |
                                  |
                              VIP: 10.9.0.70
                                  |
                 -----------------------------------
                 |                                 |
             HAProxy-1                         HAProxy-2
             10.9.0.68                         10.9.0.69
                 |                                 |
                 -----------------------------------
                                  |
              ------------------------------------------------
              |                      |                       |
            bao1                   bao2                    bao3
         10.9.0.71              10.9.0.72               10.9.0.73
```

Future improvements checklist:

- [ ] Add second HAProxy node
- [ ] Add Keepalived VIP
- [ ] Enable TLS
- [ ] Restrict network access
- [ ] Configure auto-unseal
- [ ] Automate Raft snapshots
- [ ] Forward audit logs to SIEM/log server
- [ ] Add Prometheus/Grafana monitoring
- [ ] Create OpenBao policies for applications
- [ ] Rotate and safely store root token

---

## ✅ Final Deployment Summary

```text
OpenBao Cluster Nodes:
  bao1 : 10.9.0.71
  bao2 : 10.9.0.72
  bao3 : 10.9.0.73

Load Balancer:
  HAProxy : 10.9.0.70

Single Entry Point:
  http://10.9.0.70:8200

HAProxy Stats:
  http://10.9.0.70:8404/stats

OpenBao Purpose:
  Centralized secret and .env variable management

OpenBao Storage:
  Raft Integrated Storage

Failure Tolerance:
  1 OpenBao node
```

🎉 The OpenBao HA cluster is running successfully with Docker, Raft, and HAProxy.
