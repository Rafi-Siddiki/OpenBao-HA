# 🔐 OpenBao UI-First Guide for Beginners
## 👥 Users, Policies, Machine Access, Secret Management, and OpenBao Agent

> This guide is written for people with **zero prior OpenBao knowledge**.
>
> It is **UI-first**:
> - Use the **OpenBao Web UI** wherever possible
> - Use the **OpenBao Browser CLI in the Web UI** only for:
>   - creating an AppRole role
>   - reading the `role_id`
>   - generating the `secret_id`
>
> This guide also shows how to move an app from a local `.env` file to:
>
> **OpenBao + AppRole + OpenBao Agent + template-rendered `.env`**

---

## 🧭 Table of Contents

| # | Section | Purpose |
|---:|---|---|
| 1 | [🧱 What OpenBao is](#what-openbao-is) | Understand why OpenBao is useful |
| 2 | [🧠 Simple words you need to know](#simple-words-you-need-to-know) | Learn the basic terms |
| 3 | [🏗️ What we are building](#what-we-are-building) | Understand the full flow |
| 4 | [✅ Recommended design](#recommended-design) | Follow a clean app/user structure |
| 5 | [🚪 Part 1 - First login and admin basics](#part-1---first-login-and-admin-basics) | Login using the initial admin/root token |
| 6 | [👤 Part 2 - Create a normal human user in the UI](#part-2---create-a-normal-human-user-in-the-ui) | Create userpass-based human access |
| 7 | [📜 Part 3 - Create policies](#part-3---create-policies) | Create human and machine policies |
| 8 | [🗄️ Part 4 - Create the secrets engine in the UI](#part-4---create-the-secrets-engine-in-the-ui) | Enable KV v2 at `apps/` |
| 9 | [🔑 Part 5 - Store app secrets in the UI](#part-5---store-app-secrets-in-the-ui) | Store app environment variables |
| 10 | [🤖 Part 6 - Create an AppRole with the Web UI Browser CLI](#part-6---create-an-approle-with-the-web-ui-browser-cli) | Create machine identity |
| 11 | [🧪 Part 7 - Test machine access](#part-7---test-machine-access) | Verify AppRole access |
| 12 | [📦 Part 8 - Install OpenBao Agent on the app server](#part-8---install-openbao-agent-on-the-app-server) | Install the `bao` binary and folders |
| 13 | [📝 Part 9 - Configure Agent to render a generic `.env`](#part-9---configure-agent-to-render-a-generic-env) | Render OpenBao secrets into `.env` |
| 14 | [⚙️ Part 10 - Configure systemd](#part-10---configure-systemd) | Run Agent as a restart-safe service |
| 15 | [🔁 Part 11 - Day-to-day secret management](#part-11---day-to-day-secret-management) | Manage secrets from the UI |
| 16 | [➕ Part 12 - Add another app](#part-12---add-another-app) | Repeat the process safely for new apps |
| 17 | [🧯 Troubleshooting](#troubleshooting) | Fix common issues |
| 18 | [🛡️ Security best practices](#security-best-practices) | Keep access safer |
| 19 | [⚡ Quick reference](#quick-reference) | Copy useful commands quickly |

---

## 🧭 Quick setup map

| Phase | Main action | Done in | Important output |
|---|---|---|---|
| 1 | Create human user | OpenBao UI | Normal user can log in |
| 2 | Create secret engine | OpenBao UI | `apps/` KV v2 mount |
| 3 | Store app secrets | OpenBao UI | `apps/flask-keycloak` |
| 4 | Create app policy | OpenBao UI | `flask-app-read` |
| 5 | Create AppRole | Browser CLI | `role_id` and `secret_id` |
| 6 | Configure Agent | App server | `/opt/flask-app/.env` rendered |
| 7 | Configure systemd | App server | Agent survives restart |
| 8 | Add new apps | UI + server | Separate secret path, template, config, and service |

> ✅ **Main goal:** after setup, app secrets should be managed from the OpenBao UI, and the app server should receive them automatically through OpenBao Agent.


## 🧱 What OpenBao is

OpenBao is a central place to store secrets.

Instead of keeping sensitive values in many local `.env` files on many servers, you keep them in OpenBao and let users or apps fetch them securely.

Examples of secrets:

| Secret type | Example |
|---|---|
| Database password | `DB_PASSWORD=StrongPassword` |
| API key | `API_KEY=abc123` |
| Client secret | `CLIENT_SECRET=your-client-secret` |
| Flask secret | `SECRET_KEY=your_very_secret_random_string_here` |
| App config | `CLIENT_ID`, `KEYCLOAK_URL`, `REALM_NAME` |
| Service token | Tokens used by apps or integrations |

---

## 🧠 Simple words you need to know

| Term | Simple meaning | Example |
|---|---|---|
| Secret | Sensitive value | `CLIENT_SECRET=abc123` |
| Secret path | Where the secret is stored | `apps/flask-keycloak` |
| Auth method | Login method | Userpass or AppRole |
| Policy | Permission rule | Read only `apps/data/flask-keycloak` |
| Token | Temporary access badge | OpenBao login token |
| AppRole | Machine/app identity | `flask-keycloak-role` |
| OpenBao Agent | Server-side helper | Renders `/opt/flask-app/.env` |

---

### Secret
A sensitive value.

Example:

```text
CLIENT_SECRET=abc123
```

### Secret path
Where the secret lives in OpenBao.

Example:

```text
apps/flask-keycloak
```

Think of it like a secure file location.

### Auth method
The login method.

Examples:

- **Username & Password** for people
- **AppRole** for apps/machines

### Policy
The permission rule.

It answers:

- what can this user do?
- what can this app do?
- which path can it access?

### Token
The access badge OpenBao gives after login.

### AppRole
A machine/app identity.

It uses:

- `role_id` = app username
- `secret_id` = app password

### OpenBao Agent
A helper process on the app server that:

- logs in to OpenBao
- renews tokens
- reads secrets
- renders them into files such as `.env`

---

## 🏗️ What we are building

For one Flask app, we want this:

```text
OpenBao UI
  ->
secret path: apps/flask-keycloak
  ->
policy: flask-app-read
  ->
AppRole: flask-keycloak-role
  ->
OpenBao Agent on app server
  ->
rendered file: /opt/flask-app/.env
  ->
Flask app reads the file
```

For human admins, we want this:

```text
Username & Password user
  ->
policy attached to that user
  ->
OpenBao UI access
```

### 🧩 Component responsibility table

| Component | Responsibility |
|---|---|
| OpenBao UI | Create users, policies, secrets, and manage day-to-day secret values |
| KV v2 `apps/` engine | Stores app secrets under paths like `apps/flask-keycloak` |
| Policy | Controls what a human user or app can access |
| AppRole | Allows the app/server to authenticate without a human password |
| OpenBao Agent | Logs in using AppRole, renews token, reads secrets, and renders `.env` |
| systemd | Keeps OpenBao Agent running and restart-safe |

---

## ✅ Recommended design

Use this rule:

| Access type | Recommended design | Why |
|---|---|---|
| People | One human user per person | Easier audit and access control |
| People | Use **Username & Password** | Simple UI login for humans |
| People | Assign only needed policies | Reduces accidental access |
| Apps | One app = one secret path | Keeps secrets isolated |
| Apps | One app = one policy | Simple permission management |
| Apps | One app = one AppRole | Easy rotation and separation |
| Apps | One app server = one Agent config | Clear troubleshooting and ownership |

### Example
For a Flask app:

- secret path: `apps/flask-keycloak`
- policy: `flask-app-read`
- AppRole: `flask-keycloak-role`

For another app:

- secret path: `apps/billing-api`
- policy: `billing-app-read`
- AppRole: `billing-api-role`

### 🏷️ Naming standard

| Object | Naming pattern | Example |
|---|---|---|
| Secret path | `apps/<app-name>` | `apps/flask-keycloak` |
| Read policy | `<app-name>-read` | `flask-app-read` |
| AppRole | `<app-name>-role` | `flask-keycloak-role` |
| Template | `<app-name>.env.ctmpl` | `flask.env.ctmpl` |
| Same-server service | `openbao-agent-<app-name>.service` | `openbao-agent-billing-api.service` |
| Same-server runtime directory | `openbao-agent-<app-name>` | `openbao-agent-billing-api` |

---

# 🚪 Part 1 - First login and admin basics

## 🔑 Step 1. Log in to OpenBao

Use the initial admin/root token only for first setup.

### UI steps
1. Open the OpenBao Web UI
2. Select the default namespace if needed
3. Sign in with the root/admin token

> Do **not** use the root token for daily work if you can avoid it.


### Screenshot

<p align="center">
  <img src="../images/01-openbao-login.png" alt="OpenBao login screen with token login selected" width="850">
</p>

<p align="center">
  <b>OpenBao login screen with token login selected</b>
</p>

---

# 👤 Part 2 - Create a normal human user in the UI

Use **Username & Password** for human access.

## 👤 Step 2. Enable Username & Password auth

### UI steps
1. Go to **Access**
2. Open **Authentication methods**
3. Click **Enable an Authentication Method**
4. Select **Username & Password**
5. Keep the default path if you want
6. Save

### Screenshot

<p align="center">
  <img src="../images/02-enable-userpass.png" alt="Enable Username and Password authentication method" width="850">
</p>

<p align="center">
  <b>Enable Username & Password authentication method</b>
</p>

## 📜 Step 3. Create a policy for human secret management

We will create a human policy named:

```text
apps-manager
```

This policy will allow a user to manage secrets under the `apps/` mount.

### Policy content

```hcl
path "apps/data/*" {
  capabilities = ["create", "read", "update", "patch", "delete"]
}

path "apps/metadata/*" {
  capabilities = ["read", "list"]
}
```

### UI steps
1. Go to **Policies**
2. Click **Create policy**
3. Name it `apps-manager`
4. Paste the policy text
5. Save

### Screenshot

<p align="center">
  <img src="../images/03-create-apps-manager-policy.png" alt="Create apps-manager policy" width="850">
</p>

<p align="center">
  <b>Create apps-manager policy</b>
</p>

## 👥 Step 4. Create the human user

Example username:

```text
rafi
```

### UI steps
1. Go to **Access**
2. Open **Authentication methods**
3. Open the **Username & Password** method
4. Open **Users**
5. Click **Create user**
6. Set:
   - username: `rafi`
   - password: choose a strong password
7. Expand the **Tokens** section
8. In **Generated Token's Policies**, add:

```text
apps-manager
```

9. Save

### Screenshots

<p align="center">
  <img src="../images/04-create-user.png" alt="Create user page" width="850">
</p>

<p align="center">
  <b>Create human user</b>
</p>

<p align="center">
  <img src="../images/05-user-token-policy.png" alt="Generated token policies section" width="850">
</p>

<p align="center">
  <b>Add apps-manager policy to the generated token policies</b>
</p>

## 🧪 Step 5. Test the human user

### UI steps
1. Log out
2. Log back in using **Username & Password**
3. Use the user you created

If login works, your normal human access is ready.

---

# 📜 Part 3 - Create policies

Policies decide what users and apps can do.

## 3.1 Human admin policy example

Example policy name:

```text
apps-manager
```

### Policy

```hcl
path "apps/data/*" {
  capabilities = ["create", "read", "update", "patch", "delete"]
}

path "apps/metadata/*" {
  capabilities = ["read", "list"]
}
```

## 3.2 Machine read-only policy example

Example policy name:

```text
flask-app-read
```

### Policy

```hcl
path "apps/data/flask-keycloak" {
  capabilities = ["read"]
}

path "apps/metadata/flask-keycloak" {
  capabilities = ["read"]
}
```

### UI steps
1. Go to **Policies**
2. Click **Create policy**
3. Name it `flask-app-read`
4. Paste the policy
5. Save

### Screenshot

<p align="center">
  <img src="../images/06-create-flask-app-read-policy.png" alt="Create flask-app-read policy" width="850">
</p>

<p align="center">
  <b>Create flask-app-read policy</b>
</p>

---

# 🗄️ Part 4 - Create the secrets engine in the UI

We will create a KV v2 secrets engine named:

```text
apps
```

## 🗄️ Step 6. Enable the secrets engine

### UI steps
1. Go to **Secrets engines**
2. Click **Enable new engine**
3. Choose **KV**
4. Choose **Version 2**
5. Set the path to:

```text
apps
```

6. Save

### Screenshot

<p align="center">
  <img src="../images/07-enable-kv-v2-apps.png" alt="Enable KV version 2 secrets engine at apps path" width="850">
</p>

<p align="center">
  <b>Enable KV version 2 secrets engine at apps path</b>
</p>

---

# 🔑 Part 5 - Store app secrets in the UI

We will store the Flask app values at:

```text
apps/flask-keycloak
```

## 🔐 Step 7. Create the app secret

### UI steps
1. Go to **Secrets engines**
2. Open `apps/`
3. Click **Create secret**
4. Use path:

```text
flask-keycloak
```

5. Add keys and values

### Example keys

```json
{
  "SECRET_KEY": "your_very_secret_random_string_here",
  "DEBUG": "True",
  "KEYCLOAK_URL": "http://10.9.0.71",
  "REALM_NAME": "electronic-shop",
  "CLIENT_ID": "flask-app",
  "CLIENT_SECRET": "your-client-secret"
}
```

6. Save

### Screenshots

<p align="center">
  <img src="../images/08-create-flask-keycloak-secret.png" alt="Create flask-keycloak secret under apps secrets engine" width="850">
</p>

<p align="center">
  <b>Create flask-keycloak secret under apps secrets engine</b>
</p>

---

# 🤖 Part 6 - Create an AppRole with the Web UI Browser CLI

This is the only part where we will use CLI.

## 🤖 Step 8. Enable AppRole in the UI

### UI steps
1. Go to **Access**
2. Open **Authentication methods**
3. Click **Enable an Authentication Method**
4. Select **AppRole**
5. Keep the default path:

```text
approle
```

6. Save

### Screenshot

<p align="center">
  <img src="../images/09-enable-approle.png" alt="Enable AppRole authentication method" width="850">
</p>

<p align="center">
  <b>Enable AppRole authentication method</b>
</p>

## 💻 Step 9. Open the Browser CLI

In the Web UI, open the built-in CLI panel.

### Screenshot

<p align="center">
  <img src="../images/10-browser-cli-open.png" alt="OpenBao Browser CLI panel" width="850">
</p>

<p align="center">
  <b>OpenBao Browser CLI panel</b>
</p>

## 🧾 Step 10. Create the AppRole

Use this command in the Web UI Browser CLI:

```bash
bao write auth/approle/role/flask-keycloak-role token_policies="flask-app-read"
```

## 🆔 Step 11. Read the `role_id`

```bash
bao read auth/approle/role/flask-keycloak-role/role-id
```

## 🔑 Step 12. Generate the `secret_id`

```bash
bao write -f auth/approle/role/flask-keycloak-role/secret-id
```

### Screenshots

<p align="center">
  <img src="../images/11-create-approle.png" alt="Create AppRole using Browser CLI" width="850">
</p>

<p align="center">
  <b>Create AppRole using Browser CLI</b>
</p>

<p align="center">
  <img src="../images/12-role-id-output.png" alt="Read AppRole role ID" width="850">
</p>

<p align="center">
  <b>Read AppRole role_id</b>
</p>

<p align="center">
  <img src="../images/13-secret-id-output.png" alt="Generate AppRole secret ID" width="850">
</p>

<p align="center">
  <b>Generate AppRole secret_id</b>
</p>

## 📋 Step 13. Optional: list AppRoles

```bash
bao list auth/approle/role
```

## 🔎 Step 14. Optional: inspect one AppRole

```bash
bao read auth/approle/role/flask-keycloak-role
```

---

# 🧪 Part 7 - Test machine access

## 🤖 Step 15. Log in as the app

Use the Browser CLI or a normal terminal:

```bash
bao write auth/approle/login   role_id="YOUR_ROLE_ID"   secret_id="YOUR_SECRET_ID"
```

This returns a `client_token`.

## 🧪 Step 16. Test reading the secret
**(After installing OpenBao Agent in a linux machine part 8 Step 17)**

With a full terminal CLI: 

```bash
export BAO_ADDR="http://10.9.0.70:8200"
export BAO_TOKEN="YOUR_CLIENT_TOKEN"

bao kv get -mount=apps flask-keycloak
```

If the read works, the machine identity is working correctly.

### Screenshot

<p align="center">
  <img src="../images/14-agent-running.png" alt="OpenBao Agent running successfully" width="850">
</p>

<p align="center">
  <b>OpenBao Agent running successfully</b>
</p>

---

# 📦 Part 8 - Install OpenBao Agent on the app server

## 📥 Step 17. Install the `bao` binary

On the app server:

```bash
cd /tmp

VERSION="2.5.0"
wget "https://github.com/openbao/openbao/releases/download/v${VERSION}/bao_${VERSION}_linux_x86_64.tar.gz"

tar -xzf "bao_${VERSION}_linux_x86_64.tar.gz"

sudo mv bao /usr/local/bin/bao
sudo chmod 755 /usr/local/bin/bao
```

Verify:

```bash
which bao
bao -h
bao version
```

## 📁 Step 18. Create Agent directories

```bash
sudo mkdir -p /etc/openbao-agent.d/approle

sudo chmod 700 /etc/openbao-agent.d
sudo chmod 700 /etc/openbao-agent.d/approle
```

> ⚠️ **Restart-safe note**
>
> Do not manually create `/run/openbao-agent` for permanent use.
> `/run` is temporary and is cleared after every reboot.
> systemd will create `/run/openbao-agent` automatically using `RuntimeDirectory=openbao-agent` in the service file.

## 🗝️ Step 19. Save AppRole credentials in files

Create:

```bash
sudo tee /etc/openbao-agent.d/approle/role_id >/dev/null <<'EOF'
YOUR_ROLE_ID_HERE
EOF
```

Create:

```bash
sudo tee /etc/openbao-agent.d/approle/secret_id >/dev/null <<'EOF'
YOUR_SECRET_ID_HERE
EOF
```

Permissions:

```bash
sudo chmod 600 /etc/openbao-agent.d/approle/role_id
sudo chmod 600 /etc/openbao-agent.d/approle/secret_id
```

---

# 📝 Part 9 - Configure Agent to render a generic `.env`

## 📝 Step 20. Create the generic template

Create:

```bash
sudo tee /etc/openbao-agent.d/flask.env.ctmpl >/dev/null <<'EOF'
{{- with secret "apps/flask-keycloak" -}}
{{- range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{- end }}
{{- end }}
EOF

sudo chmod 600 /etc/openbao-agent.d/flask.env.ctmpl
```

### 🔍 Template value that must match

| Template line | Must match |
|---|---|
| `{{- with secret "apps/flask-keycloak" -}}` | The OpenBao secret path created in Part 5 |
| `.Data.data` | KV v2 data location |
| `{{ $k }}={{ $v }}` | Generic key-value output for `.env` |

> ✅ For a new app, this template file must point to the new app's secret path.

## ⚙️ Step 21. Create the Agent config

Create:

```bash
sudo tee /etc/openbao-agent.d/agent.hcl >/dev/null <<'EOF'
pid_file = "/run/openbao-agent/agent.pid"

vault {
  address = "http://10.9.0.70:8200"
}

auto_auth {
  method {
    type       = "approle"
    mount_path = "auth/approle"

    config = {
      role_id_file_path                   = "/etc/openbao-agent.d/approle/role_id"
      secret_id_file_path                 = "/etc/openbao-agent.d/approle/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"
    config = {
      path = "/run/openbao-agent/token"
    }
  }
}

template_config {
  exit_on_retry_failure         = true
  static_secret_render_interval = "1m"
}

template {
  # Change this template path according to your application
  source               = "/etc/openbao-agent.d/flask.env.ctmpl"

  # Change this destination path to your application's .env file location
  destination          = "/opt/flask-app/.env"

  create_dest_dirs     = true
  error_on_missing_key = true
}
EOF

sudo chmod 600 /etc/openbao-agent.d/agent.hcl
```

### 🧩 Agent config values that must match

| Config field | Current value | Must match |
|---|---|---|
| `vault.address` | `http://10.9.0.70:8200` | OpenBao/HAProxy address |
| `role_id_file_path` | `/etc/openbao-agent.d/approle/role_id` | AppRole `role_id` file |
| `secret_id_file_path` | `/etc/openbao-agent.d/approle/secret_id` | AppRole `secret_id` file |
| token sink path | `/run/openbao-agent/token` | systemd `RuntimeDirectory` |
| `template.source` | `/etc/openbao-agent.d/flask.env.ctmpl` | Template file |
| `template.destination` | `/opt/flask-app/.env` | App `.env` location |

---

# ⚙️ Part 10 - Configure systemd

## 🛠️ Step 22. Create `openbao-agent.service`

Create:

```bash
sudo tee /etc/systemd/system/openbao-agent.service >/dev/null <<'EOF'
[Unit]
Description=OpenBao Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=HOME=/root
RuntimeDirectory=openbao-agent
RuntimeDirectoryMode=0750
ExecStart=/usr/local/bin/bao agent -config=/etc/openbao-agent.d/agent.hcl
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 🧠 Important systemd lines

| Line | Purpose |
|---|---|
| `Environment=HOME=/root` | Prevents `$HOME is not defined` errors |
| `RuntimeDirectory=openbao-agent` | Creates `/run/openbao-agent` automatically |
| `RuntimeDirectoryMode=0750` | Sets safer runtime directory permissions |
| `Restart=always` | Restarts Agent if it exits |
| `RestartSec=5` | Waits 5 seconds before restart |
| `WantedBy=multi-user.target` | Allows service to start automatically during boot |

> ✅ This is the part that keeps the Agent working after machine restarts.

## 🚀 Step 23. Reload and start services

```bash
sudo systemctl daemon-reload

sudo systemctl enable openbao-agent.service

sudo systemctl start openbao-agent.service
```

## ✅ Step 24. Verify

Check Agent:

```bash
sudo systemctl status openbao-agent.service --no-pager
sudo journalctl -u openbao-agent.service -n 50 --no-pager
```


Check rendered `.env`:

```bash
sudo ls -l /opt/flask-app/.env
sudo cat /opt/flask-app/.env
```

## 🔁 Step 25. Test after reboot

Because `/run` is temporary, always verify that OpenBao Agent works after a reboot.

Reboot the app server:

```bash
sudo reboot
```

After the server comes back, check:

```bash
sudo systemctl status openbao-agent.service --no-pager
sudo journalctl -b -u openbao-agent.service -n 50 --no-pager
sudo ls -ld /run/openbao-agent
sudo ls -l /run/openbao-agent
```

Expected result:

```text
Active: active (running)
authentication successful
token written: path=/run/openbao-agent/token
rendered "/etc/openbao-agent.d/flask.env.ctmpl" => "/opt/flask-app/.env"
```

If `/run/openbao-agent` exists after service start, the restart-safe configuration is working.


---

# 🔁 Part 11 - Day-to-day secret management

Once setup is complete, your daily work should be almost entirely in the **OpenBao UI**.

## Change a value

### UI steps
1. Open `apps/flask-keycloak`
2. Edit a key
3. Save

Result:
- Agent re-renders `.env`


## Add a new variable

### UI steps
1. Open `apps/flask-keycloak`
2. Add a new key
3. Save

Result:
- Agent re-renders `.env`
- the new variable appears automatically


### Important rule

Do **not** manually edit `/opt/flask-app/.env`.

OpenBao Agent owns that file now.

---

# ➕ Part 12 - Add another app

> 🎯 **Goal:** add a new application without breaking the existing Flask app.
>
> The new app must get its own secret path, policy, AppRole, template, Agent config, and systemd service when it runs on the same server.

If you have another app, repeat the same design.

The most important thing is: **do not only create a new AppRole**.  
For every new app, you must also change the secret path, policy, template file, Agent config, AppRole credential files, and sometimes the systemd service name.

---

## 12.1 What changes for every new app

Use this checklist before adding any new application.

| Item | Current Flask app example | New app example |
|---|---|---|
| Secret path in OpenBao | `apps/flask-keycloak` | `apps/billing-api` |
| Policy name | `flask-app-read` | `billing-app-read` |
| AppRole name | `flask-keycloak-role` | `billing-api-role` |
| Template file | `/etc/openbao-agent.d/flask.env.ctmpl` | `/etc/openbao-agent.d/billing-api.env.ctmpl` |
| Template secret path | `apps/flask-keycloak` | `apps/billing-api` |
| Rendered `.env` destination | `/opt/flask-app/.env` | `/opt/billing-api/.env` |
| AppRole credential directory | `/etc/openbao-agent.d/approle/` | `/etc/openbao-agent.d/billing-api/approle/` |
| Agent config | `/etc/openbao-agent.d/agent.hcl` | `/etc/openbao-agent.d/billing-api/agent.hcl` |
| Runtime directory | `/run/openbao-agent` | `/run/openbao-agent-billing-api` |
| systemd service | `openbao-agent.service` | `openbao-agent-billing-api.service` |

---

## 12.2 Important decision: same server or different server?

| Scenario | Can reuse file names? | Recommended approach |
|---|---:|---|
| New app on a different server | ✅ Yes | Reuse simple names like `agent.hcl` and `openbao-agent.service`, but change values inside |
| Multiple apps on the same server | ❌ No | Use separate directories, templates, runtime directories, and service names |

### Case A: New app is on a different server

This is the simplest case.

You can reuse the same file names on the new server:

```text
/etc/openbao-agent.d/agent.hcl
/etc/openbao-agent.d/flask.env.ctmpl
/etc/systemd/system/openbao-agent.service
```

But you must change the values inside them:

- secret path
- template content
- `.env` destination path
- AppRole `role_id`
- AppRole `secret_id`
- policy name
- AppRole name

### Case B: Multiple apps are on the same server

Use separate directories and separate services.

Example:

```text
/etc/openbao-agent.d/flask-keycloak/
/etc/openbao-agent.d/billing-api/
```

And separate services:

```text
openbao-agent-flask-keycloak.service
openbao-agent-billing-api.service
```

This avoids one app overwriting another app's `.env` file.

---

## 12.3 Example: add a new Billing app

For this example:

| Item | Value |
|---|---|
| App name | Billing API |
| OpenBao secret path | `apps/billing-api` |
| Policy name | `billing-app-read` |
| AppRole name | `billing-api-role` |
| App server `.env` file | `/opt/billing-api/.env` |
| Template file | `/etc/openbao-agent.d/billing-api/billing-api.env.ctmpl` |
| Agent config | `/etc/openbao-agent.d/billing-api/agent.hcl` |
| systemd service | `openbao-agent-billing-api.service` |

---

## 12.4 Create the new app secret in the UI

### UI steps

1. Go to **Secrets engines**
2. Open `apps/`
3. Click **Create secret**
4. Use path:

```text
billing-api
```

5. Add the app's environment variables.

Example:

```json
{
  "APP_ENV": "production",
  "DATABASE_URL": "mysql://user:password@db-server:3306/billing",
  "API_KEY": "your-api-key",
  "SECRET_KEY": "your-secret-key"
}
```

6. Save.

The full OpenBao path becomes:

```text
apps/billing-api
```

---

## 12.5 Create a new read-only policy for the app

Policy name:

```text
billing-app-read
```

Policy content:

```hcl
path "apps/data/billing-api" {
  capabilities = ["read"]
}

path "apps/metadata/billing-api" {
  capabilities = ["read"]
}
```

### UI steps

1. Go to **Policies**
2. Click **Create policy**
3. Name it:

```text
billing-app-read
```

4. Paste the policy
5. Save

---

## 12.6 Create the new AppRole

Use the OpenBao Web UI Browser CLI.

Create the AppRole:

```bash
bao write auth/approle/role/billing-api-role token_policies="billing-app-read"
```

Read the `role_id`:

```bash
bao read auth/approle/role/billing-api-role/role-id
```

Generate the `secret_id`:

```bash
bao write -f auth/approle/role/billing-api-role/secret-id
```

Save both values securely. You will need them on the app server.

---

## 12.7 Create new Agent directories on the app server

For a same-server multi-app setup, create a separate directory for this app:

```bash
sudo mkdir -p /etc/openbao-agent.d/billing-api/approle

sudo chmod 700 /etc/openbao-agent.d/billing-api
sudo chmod 700 /etc/openbao-agent.d/billing-api/approle
```

---

## 12.8 Save the new AppRole credentials

Create the `role_id` file:

```bash
sudo tee /etc/openbao-agent.d/billing-api/approle/role_id >/dev/null <<'EOF'
YOUR_BILLING_API_ROLE_ID_HERE
EOF
```

Create the `secret_id` file:

```bash
sudo tee /etc/openbao-agent.d/billing-api/approle/secret_id >/dev/null <<'EOF'
YOUR_BILLING_API_SECRET_ID_HERE
EOF
```

Set safe permissions:

```bash
sudo chmod 600 /etc/openbao-agent.d/billing-api/approle/role_id
sudo chmod 600 /etc/openbao-agent.d/billing-api/approle/secret_id
```

---

## 12.9 Create the new `.env.ctmpl` template

This is the part that must be changed for every new app.

For the Flask app, you used:

```text
apps/flask-keycloak
```

For the Billing app, the template must use:

```text
apps/billing-api
```

Create the Billing app template:

```bash
sudo tee /etc/openbao-agent.d/billing-api/billing-api.env.ctmpl >/dev/null <<'EOF'
{{- with secret "apps/billing-api" -}}
{{- range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{- end }}
{{- end }}
EOF

sudo chmod 600 /etc/openbao-agent.d/billing-api/billing-api.env.ctmpl
```

### Very important

This line must match the OpenBao secret path:

```text
{{- with secret "apps/billing-api" -}}
```

If this still says the old app path, for example:

```text
{{- with secret "apps/flask-keycloak" -}}
```

then the new app will receive the wrong secrets or the template may fail.

---

## 12.10 Create the new Agent config

Create:

```bash
sudo tee /etc/openbao-agent.d/billing-api/agent.hcl >/dev/null <<'EOF'
pid_file = "/run/openbao-agent-billing-api/agent.pid"

vault {
  address = "http://10.9.0.70:8200"
}

auto_auth {
  method {
    type       = "approle"
    mount_path = "auth/approle"

    config = {
      role_id_file_path                   = "/etc/openbao-agent.d/billing-api/approle/role_id"
      secret_id_file_path                 = "/etc/openbao-agent.d/billing-api/approle/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink {
    type = "file"
    config = {
      path = "/run/openbao-agent-billing-api/token"
    }
  }
}

template_config {
  exit_on_retry_failure         = true
  static_secret_render_interval = "1m"
}

template {
  source               = "/etc/openbao-agent.d/billing-api/billing-api.env.ctmpl"
  destination          = "/opt/billing-api/.env"
  create_dest_dirs     = true
  error_on_missing_key = true
}
EOF

sudo chmod 600 /etc/openbao-agent.d/billing-api/agent.hcl
```

### Things that changed from the first app

| Field | What changed |
|---|---|
| `pid_file` | changed to `/run/openbao-agent-billing-api/agent.pid` |
| `role_id_file_path` | changed to Billing app's `role_id` path |
| `secret_id_file_path` | changed to Billing app's `secret_id` path |
| token sink path | changed to `/run/openbao-agent-billing-api/token` |
| template source | changed to Billing app's `.env.ctmpl` file |
| template destination | changed to Billing app's `.env` file |

---

## 12.11 Create the new systemd service

Create a separate service for the new app:

```bash
sudo tee /etc/systemd/system/openbao-agent-billing-api.service >/dev/null <<'EOF'
[Unit]
Description=OpenBao Agent - Billing API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=HOME=/root
RuntimeDirectory=openbao-agent-billing-api
RuntimeDirectoryMode=0750
ExecStart=/usr/local/bin/bao agent -config=/etc/openbao-agent.d/billing-api/agent.hcl
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Why `RuntimeDirectory` must be different

For the first app, we used:

```ini
RuntimeDirectory=openbao-agent
```

For the Billing app, we use:

```ini
RuntimeDirectory=openbao-agent-billing-api
```

This creates:

```text
/run/openbao-agent-billing-api
```

after every restart.

This keeps the token and PID file separate from the first app.

---

## 12.12 Start and verify the new Agent

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable the service:

```bash
sudo systemctl enable openbao-agent-billing-api.service
```

Start the service:

```bash
sudo systemctl start openbao-agent-billing-api.service
```

Check status:

```bash
sudo systemctl status openbao-agent-billing-api.service --no-pager
```

Check logs:

```bash
sudo journalctl -u openbao-agent-billing-api.service -n 50 --no-pager
```

Check the rendered `.env` file:

```bash
sudo ls -l /opt/billing-api/.env
sudo cat /opt/billing-api/.env
```

Expected logs should show:

```text
authentication successful
token written: path=/run/openbao-agent-billing-api/token
rendered "/etc/openbao-agent.d/billing-api/billing-api.env.ctmpl" => "/opt/billing-api/.env"
```

---

## 12.13 Test the new app after reboot

Reboot the server:

```bash
sudo reboot
```

After the server comes back:

```bash
sudo systemctl status openbao-agent-billing-api.service --no-pager
sudo journalctl -b -u openbao-agent-billing-api.service -n 50 --no-pager
sudo ls -ld /run/openbao-agent-billing-api
sudo ls -l /run/openbao-agent-billing-api
```

Expected result:

```text
Active: active (running)
authentication successful
token written: path=/run/openbao-agent-billing-api/token
rendered "/etc/openbao-agent.d/billing-api/billing-api.env.ctmpl" => "/opt/billing-api/.env"
```

---

## 12.14 New app checklist

Before calling the setup complete, confirm every item below.

| Check | Status |
|---|---|
| Secret exists in OpenBao UI under the correct path | ☐ |
| Policy points to the correct `apps/data/APP_NAME` path | ☐ |
| AppRole uses the correct policy | ☐ |
| New `role_id` is saved on the app server | ☐ |
| New `secret_id` is saved on the app server | ☐ |
| `.env.ctmpl` uses the correct secret path | ☐ |
| `agent.hcl` points to the correct template file | ☐ |
| `agent.hcl` points to the correct destination `.env` | ☐ |
| systemd service points to the correct `agent.hcl` | ☐ |
| `RuntimeDirectory` is unique for this Agent service | ☐ |
| service is enabled | ☐ |
| service works after reboot | ☐ |
| app reads the rendered `.env` file correctly | ☐ |

## Important rule

Use:

- one app = one policy
- one app = one AppRole
- one app = one secret path
- one app on the same server = one separate Agent config
- one app on the same server = one separate systemd service

---

## 🧯 Troubleshooting

### 1. Agent worked before reboot but failed after reboot

Error example:

```text
error creating file sink: error opening temp file in dir /run/openbao-agent
no such file or directory
```

Reason:

```text
/run is temporary and is cleared after reboot.
```

Fix:

Make sure the systemd service has:

```ini
RuntimeDirectory=openbao-agent
RuntimeDirectoryMode=0750
```

Then run:

```bash
sudo systemctl daemon-reload
sudo systemctl restart openbao-agent.service
sudo systemctl status openbao-agent.service --no-pager
```

### 2. Userpass login works but access is limited
That means the user’s policy is too narrow.
Update the policy assigned to that user.

### 3. AppRole page in the UI has no "create user"
That is normal.
AppRole is for machines, so you create a **role**, not a human user.

### 4. Agent fails with `$HOME is not defined`
Add this to `openbao-agent.service`:

```ini
Environment=HOME=/root
```

### 5. Watcher enters a restart loop
Do not use `PathExists=` in the path unit.
Use only:

```ini
PathChanged=/opt/flask-app/.env
```

### 6. New keys do not show up in `.env`
Make sure you are using the **generic template**, not a hardcoded template.

### 7. App still uses old values
Check:
- Agent is running
- `.env` timestamp changed
- watcher restarted the app
- app actually reads `.env` on startup

### 8. Flask debug mode does not change
If your code hardcodes `debug=True`, changing `DEBUG` in OpenBao will not change runtime behavior until code is fixed.


### 9. New app renders the old app secrets

This usually means the new app's `.env.ctmpl` still points to the old secret path.

Check the template:

```bash
sudo cat /etc/openbao-agent.d/billing-api/billing-api.env.ctmpl
```

For the Billing app, it must contain:

```text
{{- with secret "apps/billing-api" -}}
```

It should not contain the old app path:

```text
{{- with secret "apps/flask-keycloak" -}}
```

Also check the Agent config:

```bash
sudo cat /etc/openbao-agent.d/billing-api/agent.hcl
```

Confirm these values are correct:

- `role_id_file_path`
- `secret_id_file_path`
- `source`
- `destination`
- token sink path under `/run`
- `pid_file`

Restart the correct service:

```bash
sudo systemctl restart openbao-agent-billing-api.service
sudo journalctl -u openbao-agent-billing-api.service -n 50 --no-pager
```


---

## 🛡️ Security best practices

### Do not use the root token for daily work
Create human users for UI usage.

### Use one AppRole per app
Do not share AppRoles across unrelated apps.

### Use one secret path per app
Examples:

- `apps/flask-keycloak`
- `apps/billing-api`
- `apps/worker-service`

### Use least privilege
Human users should get only what they need.
Apps should usually be read-only.

### Rotate `secret_id` if exposed
If you showed it in chat, logs, or screenshots, generate a new one.

---

## ⚡ Quick reference

| Task | Command area |
|---|---|
| Create human user | Userpass auth |
| Create AppRole | AppRole auth |
| Get `role_id` | AppRole role ID endpoint |
| Generate `secret_id` | AppRole secret ID endpoint |
| Login as app | AppRole login |
| Read app secret | KV v2 secret read |

### Create human user (CLI example)

```bash
write auth/userpass/users/rafi   password="StrongPassword123"   token_policies="apps-manager"
```

### Create AppRole

```bash
write auth/approle/role/flask-keycloak-role token_policies="flask-app-read"
```

### Get role ID

```bash
read auth/approle/role/flask-keycloak-role/role-id
```

### Generate secret ID

```bash
write -f auth/approle/role/flask-keycloak-role/secret-id
```

### AppRole login

```bash
write auth/approle/login   role_id="YOUR_ROLE_ID"   secret_id="YOUR_SECRET_ID"
```

### Read the secret

```bash
export BAO_ADDR="http://10.9.0.70:8200"
export BAO_TOKEN="YOUR_CLIENT_TOKEN"

bao kv get -mount=apps flask-keycloak
```

---

## 🎯 Final recommendation

For production and long-term maintainability, use this standard:

| Area | Standard |
|---|---|
| Human access | Use the **OpenBao UI** |
| Human login | Use **Username & Password** |
| Authorization | Use **Policies** |
| App/machine login | Use **AppRole** |
| AppRole setup | Use the **Web UI Browser CLI** only where needed |
| Secret delivery | Use **OpenBao Agent** |
| `.env` generation | Use the **generic template** |
| Multiple apps on same server | Use **separate Agent configs and services** |

That gives you centralized secret management with minimal application changes and a beginner-friendly operating model.
