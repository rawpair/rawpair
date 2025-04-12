# PHP Workspace Container

This folder defines the Docker environment used to run isolated, multi-version PHP workspaces for RawPair.

Each container is fully self-contained and includes, on top of the usual setup:

- PHP 8.0–8.3 with CLI + FPM
- Nginx (per-container, internal only)
- Web UI routing via external shared Nginx

## Features

- Switch PHP CLI version dynamically with `switch-php`
- Switch PHP-FPM runtime with `switch-phpfpm`
- Nginx config is regenerated automatically per PHP version
- Works entirely as non-root `devuser`
- Clean, extensible startup via `startup-check.sh` hook

---

## Included PHP Versions

This container installs the following PHP versions (via the Sury repo):

- PHP 8.0
- PHP 8.1
- PHP 8.2
- PHP 8.3

Each version includes both `cli` and `fpm`, plus essential extensions like `mbstring`.

---

## Runtime Tools

| Tool                       | Purpose                                      |
|----------------------------|----------------------------------------------|
| `switch-php <version>`     | Switch PHP CLI version (`php`)               |
| `switch-phpfpm <version>`  | Restart FPM and regenerate Nginx config      |
| `supervisord`              | Runs ttyd, nginx, vector, php-fpm            |
| `nginx`                    | Serves requests on internal port `10000`     |
| `PHP-FPM`                  | Swappable via Supervisor per version         |

---

## How It Works

- PHP CLI switching is handled by symlinking `$HOME/bin/php` to the desired binary
- PHP-FPM switching is handled by Supervisor (`supervisorctl`) and managed sockets
- Nginx reads a dynamic config from `/etc/nginx/sites-enabled/default.conf`
- The config is generated at runtime by `switch-phpfpm` using `envsubst`
- All services are managed under Supervisor (`rawpair.conf`)
- On container startup, `ttyd-wrapper.sh` runs `startup-check.sh` (if present) to ensure the default PHP FPM 8.3 version is activated

---

## Example Usage

### Switch to PHP 8.1:

```bash
switch-php 8.1
switch-phpfpm 8.1
```

### Validate CLI version:

```bash
php -v
```

### Check FPM socket:

```bash
ls -l /home/devuser/run/php8.1-fpm.sock
```

### Restart Nginx config:

```bash
switch-phpfpm 8.1
```

---

## Notes

- FPM sockets are located at: `/home/devuser/run/php<version>-fpm.sock`
- PHP-FPM processes are *not* started by default — `startup-check.sh` is used to initialize the selected version
- You can bind this container to a shared Docker network and proxy requests through an external Nginx instance using workspace slugs

---

## External Reverse Proxy Example

Reverse proxying from the main Nginx container (outside) to this container:

```nginx
location /workspaces/php/ {
    proxy_pass http://workspace-php:10000/;
}
```

The document path is `/home/devuser/app`.
