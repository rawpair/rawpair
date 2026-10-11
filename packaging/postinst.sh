#!/bin/sh
set -eu
[ "${1:-}" = configure ] || exit 0
install -d -o root -g root -m 0755 /etc/rawpair /var/lib/rawpair
# Write before account creation so interrupted configure can safely retry.
printf '%s\n' rawpair-native-v1 > /var/lib/rawpair/package-owner
chmod 0600 /var/lib/rawpair/package-owner
for account in rawpair rawpair-collab; do
  if ! getent passwd "$account" >/dev/null; then
    if getent group "$account" >/dev/null; then
      useradd --system --gid "$account" --home-dir "/var/lib/$account" --shell /usr/sbin/nologin "$account"
    else
      useradd --system --user-group --home-dir "/var/lib/$account" --shell /usr/sbin/nologin "$account"
    fi
  fi
done
# Refuse a replaced service identity rather than adopting an unrelated account.
python3 - <<'PYTHON'
import grp, json, os, pwd, tempfile
from pathlib import Path
path = Path('/var/lib/rawpair/service-accounts.json')
accounts = {}
for name in ('rawpair', 'rawpair-collab'):
    user = pwd.getpwnam(name)
    if not 0 < user.pw_uid < 1000 or not 0 < user.pw_gid < 1000 or user.pw_dir != '/var/lib/' + name or user.pw_shell != '/usr/sbin/nologin' or grp.getgrgid(user.pw_gid).gr_name != name:
        raise SystemExit('Service identity differs from installer ownership; restore it before configuring packages')
    if any(name in group.gr_mem and group.gr_gid != user.pw_gid for group in grp.getgrall()):
        raise SystemExit('Service accounts must not have supplementary groups')
    accounts[name] = [user.pw_uid, user.pw_gid, user.pw_dir, user.pw_shell]
if path.exists():
    if json.loads(path.read_text()) != accounts:
        raise SystemExit('Service UID/GID ownership changed; restore the original accounts')
else:
    descriptor, temporary = tempfile.mkstemp(prefix='.service-accounts-', dir=path.parent)
    with os.fdopen(descriptor, 'w') as stream:
        json.dump(accounts, stream)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)
    directory = os.open(path.parent, os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
PYTHON
install -d -o rawpair -g rawpair -m 0700 /var/lib/rawpair/tmp
install -d -o rawpair-collab -g rawpair-collab -m 0700 /var/lib/rawpair-collaboration
# Prevent configured units restarting after a reboot before upgrade validation.
install -o root -g root -m 0600 /dev/null /var/lib/rawpair/setup-required
if [ -d /run/systemd/system ]; then
  systemctl daemon-reload
  systemctl stop rawpair-host.service rawpair-collaboration.service
fi
printf '%s\n' 'RawPair installed and stopped. Complete configuration with: sudo rawpair setup'
