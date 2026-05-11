# 🛡️ OpenBao HA Cluster with HAProxy & Docker

A clean, user-friendly deployment guide for running a **3-node OpenBao HA cluster** with **Raft Integrated Storage** and a **single HAProxy load balancer entry point** using **Docker Compose** on Ubuntu Server.

> Current setup is designed for an internal/private environment. TLS and firewall hardening are intentionally skipped for now.

---

## 📌 Table of Contents

- [1. Architecture Overview](#1-architecture-overview)
- [2. Server Inventory](#2-server-inventory)
- [3. What This Setup Provides](#3-what-this-setup-provides)
- [4. Port Usage](#4-port-usage)
- [5. Docker Installation](#5-docker-installation)
- [6. Directory Layout](#6-directory-layout)
- [7. OpenBao Docker Deployment](#7-openbao-docker-deployment)
- [8. OpenBao Node Configurations](#8-openbao-node-configurations)
- [9. Initialize and Unseal OpenBao](#9-initialize-and-unseal-openbao)
- [10. Verify Raft Cluster Health](#10-verify-raft-cluster-health)
- [11. HAProxy Docker Deployment](#11-haproxy-docker-deployment)
- [12. Single Entry Point](#12-single-entry-point)
- [13. Failover Behavior](#13-failover-behavior)
- [14. Daily Operations](#14-daily-operations)
- [15. Backup Procedure](#15-backup-procedure)
- [16. Troubleshooting Notes](#16-troubleshooting-notes)
- [17. Security Notes](#17-security-notes)
- [18. Future Improvements](#18-future-improvements)

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

## 6. Directory Layout

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

## 7. OpenBao Docker Deployment

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

## 8. OpenBao Node Configurations

> Important: each node has a different `cluster_addr` and `node_id`.

---

### 8.1 `bao1` Configuration

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

### 8.2 `bao2` Configuration

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

### 8.3 `bao3` Configuration

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

## 9. Initialize and Unseal OpenBao

### 9.1 Initialize Cluster

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

### 9.2 Unseal a Node

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

## 10. Verify Raft Cluster Health

### 10.1 List Raft Peers

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

### 10.2 Check Autopilot State

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

## 11. HAProxy Docker Deployment

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

## 12. Single Entry Point

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

## 13. Failover Behavior

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

## 14. Daily Operations

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

## 15. Backup Procedure

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

## 16. Troubleshooting Notes

### 16.1 OpenBao Container Restart Loop

Check logs:

```bash
sudo docker logs -f openbao
```

### 16.2 Raft DB Path Error

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

### 16.3 Do Not Mount Config as Read-Only

Avoid:

```yaml
- ./config:/openbao/config:ro
```

Use:

```yaml
- ./config:/openbao/config
```

### 16.4 Node is Sealed After Restart

Unseal it again:

```bash
sudo docker exec -it -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator unseal
sudo docker exec -it -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator unseal
sudo docker exec -it -e BAO_ADDR=http://127.0.0.1:8200 openbao bao operator unseal
```

### 16.5 Avoid Accidental Data Loss

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

## 17. Security Notes

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

## 18. Future Improvements

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

OpenBao Storage:
  Raft Integrated Storage

Failure Tolerance:
  1 OpenBao node
```

🎉 The OpenBao HA cluster is running successfully with Docker, Raft, and HAProxy.
