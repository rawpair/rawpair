# Deployment

## Ubuntu Server 24.04

The recommendation is to rely on systemd for process management.

### Supporting infrastructure

The recommendation is not to rely on containerized postgres in production.

#### Launch supportinc containers

Run `docker compose -f docker-compose.no-postgres.yml up -d` for supporting infrastructure, **without** postgres.

Run `docker compose -f docker-compose.yml up -d` for supporting infrastructure, **including** postgres.

##### systemd service

Create new file `/etc/systemd/system/rawpair-infra.service`

```ini
[Unit]
Description=RawPair Supporting Infrastructure
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/<your-user>/rawpair
ExecStart=/usr/bin/docker compose -f docker-compose.no-postgres.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.no-postgres.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now rawpair-infra
```

### Phoenix App

Run `deploy.sh` within `phoenix-app`.

### Postgres

Postgres can be quite fragile, all it takes is an unclean reboot (happens more frequently than one might think on a cheap VPS) and the data might get corrupted.

The recommendation is to use a fully managed postgres database. If that is not an option avoid at least containerized postgres.

#### .env file

Copy the contents of `phoenix-app/.env.example`, paste them into `phoenix-app/.env`. Amend as necessary.

#### systemd service

Create new file `/etc/systemd/system/rawpair.service`

```ini
[Unit]
Description=RawPair Phoenix App
After=network.target

[Service]
User=<your-user>
WorkingDirectory=/home/<your-user>/rawpair/phoenix-app/_build/prod/rel/rawpair
ExecStart=/bin/bash /home/<your-user>/rawpair/phoenix-app/start.sh
ExecStop=/bin/bash /home/<your-user>/rawpair/phoenix-app/stop.sh
Restart=always
Environment=PHX_SERVER=true
Environment=MIX_ENV=prod

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now rawpair
```

### Firewall

Secure Postgres:

```bash
sudo ufw allow from 127.0.0.1 to any port 5432
sudo ufw deny 5432
```

## Enable CloudFlare tunneling (Optional but strongly recommended)

**Please Note**: I am not affiliated to CloudFlare - their free plan will work just fine.

For this to work, CloudFlare needs to manage your domain's DNS.

### Installing cloudflared

If you haven't yet installed cloudflared, follow these instructions for Ubuntu 24.04: https://pkg.cloudflare.com/index.html#ubuntu-noble

#### Login

`cloudflared login`

#### Create tunnel

`cloudflared tunnel create rawpair`

#### Create DNS entries

- `cloudflared tunnel route dns rawpair rawpair.<your-domain>`
- `cloudflared tunnel route dns rawpair terminal.<your-domain>`
- `cloudflared tunnel route dns rawpair grafana.<your-domain>`

#### Add a systemd service for the cloudflared tunnel

Create new file `/etc/systemd/system/cloudflared-rawpair.service`

```ini
[Unit]
Description=Cloudflare Tunnel for RawPair
After=network.target

[Service]
Type=simple
User=<your-user>
ExecStart=/usr/local/bin/cloudflared tunnel run rawpair
Restart=always
RestartSec=5
Environment=HOME=/home/<your-user>

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflared-rawpair
```

## Ansible playbooks

The [./ansible/README.md](included Ansible playbooks) allow you to reliably set up the RawPair infrastructure, including Docker, Phoenix, UFW rules, and Cloudflare Tunnels.

Sensitive values such as `SECRET_KEY_BASE` and `DATABASE_URL` should not be stored directly in playbooks. Instead, use [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) to encrypt these secrets. You can reference them using vars_files within the playbook. This enables the creation of secure `.env` files at deploy time without exposing sensitive information in plaintext.
