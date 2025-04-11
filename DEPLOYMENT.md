# Deployment

## Ubuntu Server 24.04

The recommendation is to rely on systemd for process management.

### Supporting infrastructure

Secure Postgres:

```bash
sudo ufw allow from 127.0.0.1 to any port 5432
sudo ufw deny 5432
```

Run `docker compose up -d`

### Phoenix App

Run `deploy.sh` within `phoenix-app`.

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
ExecStart=/home/<your-user>/rawpair/phoenix-app/start.sh
ExecStop=/home/<your-user>/rawpair/phoenix-app/_build/prod/rel/rawpair/bin/rawpair stop
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
