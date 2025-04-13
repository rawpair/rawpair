# ansible playbooks

## Install ansible locally

`sudo apt install ansible`

## postgres

`ansible-playbook -i hosts.ini postgres.yml`

## docker

`ansible-playbook -i hosts.ini docker.yml -e "user=your-user"`

## cloudflared

`ansible-playbook -i hosts.ini cloudflared.yml -e "user=your-user domain=your-domain.com"`

## rawpair

`ansible-playbook -i hosts.ini rawpair.yml -e "user=your-user rawpair_dir=/home/your-user/rawpair"`

