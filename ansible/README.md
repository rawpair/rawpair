# ansible playbooks

## Install ansible locally

`sudo apt install ansible`

## Set up secure remote SSH access (optional)

`ansible-playbook -i hosts.ini secure-remote-ssh-access.yml -e "vps ansible_host=<ip.address> ansible_port=22 new_user=<your-user> ansible_user=root new_user_ssh_key='<ssh-public-key>'" --ask-become-pass`

## postgres

Run `sudo apt install -y python3-psycopg2 acl ufw` on target machine

**Ensure the designated OS user can 'become' postgres without entering the sudo password.**

`ansible-playbook -i hosts.ini postgres.yml`

## docker

Supports both Ubuntu and Debian systems - in theory. Only tested on Bookworm so far.

`ansible-playbook -i hosts.ini docker.yml -e "vps ansible_host=<ip.address> ansible_port=22 user=<your-user> ansible_user=<your-user>" --ask-become-pass`

## cloudflared

Install cloudflared:

`ansible-playbook -i hosts.ini cloudflared-install.yml -e "vps ansible_host=<ip.address> ansible_port=22 user=<your-user> ansible_user=<your-user>" --ask-become-pass`

Login manually via CLI: `cloudflared login`. This cannot be automated.

Make a note of the generated `.json` file in `~/.cloudflared`

Create the tunnel: `cloudflared tunnel create <tunnel-name>`

Create `~/.cloudflared/config.yml` with this content:

```yaml
tunnel: <tunnel-name>
credentials-file: /home/<your-user>/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: rawpair.<domain-name>
    service: http://localhost:4000

  - hostname: terminal.<domain-name>
    service: http://localhost:8080

  - hostname: grafana.<domain-name>
    service: http://localhost:3000

  - service: http_status:404
```

You're free to change the ports, provided you remember to set the ENV vars accordingly.

Create tunnel route dns entries:

- `cloudflared tunnel route dns <tunnel-name> rawpair.<domain-name>`
- `cloudflared tunnel route dns <tunnel-name> grafana.<domain-name>`
- `cloudflared tunnel route dns <tunnel-name> terminal.<domain-name>`

This will create CNAME entries. If they already exist then they must be deleted first.

You can now proceed with the second playbook:

`ansible-playbook -i hosts.ini cloudflared-config.yml -e "vps ansible_host=<ip.address> ansible_port=22 user=<your-user> ansible_user=<your-user> tunnel_name=<tunnel-name>" --ask-become-pass`

## asdf, erlang, elixir

`ansible-playbook -i hosts.ini asdf-erlang-elixir.yml -e "vps ansible_host=<ip.address> ansible_port=22 user=<your-user> ansible_user=<your-user> " --ask-become-pass`

Ensure you source `~/.bashrc` then install Hex: `mix local.hex --force`

## rawpair

`ansible-playbook -i hosts.ini rawpair.yml -e "vps ansible_host=<ip.address> ansible_port=22 user=<your-user> ansible_user=<your-user> database_url='postgres://<dbuser>:<dbpass>@<dbhost>/<dbname>' terminal_host=terminal.<domain-name> rawpair_host=rawpair.<domain-name> grafana_host=grafana.<domain-name> secret_key_base='<secret_key_base>'" --ask-become-pass`



