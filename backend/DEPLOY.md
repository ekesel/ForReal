# Deploying the ForReal backend

A runbook for one Ubuntu 24.04 server running the production Docker Compose stack. For running
the backend locally, see [README.md](README.md).

Contents: [what runs](#what-runs) · [settings](#production-settings) · [server prep](#1-server-prep) ·
[first deploy](#2-first-deploy) · [updates](#3-updates) · [rollback](#4-rollback) ·
[backups](#5-backups) · [closed testing](#closed-testing) · [post-deploy checklist](#post-deploy-checklist)

## What runs

`docker-compose.prod.yml` starts five containers:

| Service | What it does | Reachable from outside |
| --- | --- | --- |
| `caddy` | HTTPS for `DOMAIN` with an automatic certificate, redirects HTTP to HTTPS, serves static files, proxies the rest to `web` | Yes: 80 and 443 |
| `web` | gunicorn. Runs `migrate` and `collectstatic` every time it starts | No |
| `worker` | Celery worker with beat (geocoding, hourly purge of expired codes) | No |
| `db` | PostgreSQL 16 with PostGIS | No |
| `redis` | Celery broker | No |

Only `caddy` publishes ports. This matters because ports published by Docker bypass `ufw`: a
`ports:` entry on `db` or `redis` would be open to the internet whatever the firewall says.

Data lives in named volumes: `forreal_pgdata` (the database), `forreal_caddy_data` (certificates),
`forreal_static` (collected static files, rebuilt on every start) and `forreal_caddy_config`.
Container logs rotate at 5 files of 10 MB per service.

The development `docker-compose.yml` must never be used on a server: it publishes the database
with a known password.

## Production settings

Everything comes from `backend/.env` on the server. `.env.prod.example` lists every variable with
comments. The ones that decide whether the deployment is safe:

| Variable | Production value |
| --- | --- |
| `DEBUG` | `0` |
| `DOMAIN` | The public host name. Caddy gets the certificate for it |
| `ALLOWED_HOSTS` | The same host name |
| `CSRF_TRUSTED_ORIGINS` | `https://` plus the host name. The admin login fails without it |
| `ADMIN_PATH` | Anything other than `admin/` |
| `SECRET_KEY` | 50 or more random characters |
| `REF_HASH_PEPPER` | Random, different from `SECRET_KEY`. Set once and never change it |
| `POSTGRES_PASSWORD` | Random hex. Compose builds `DATABASE_URL` from it |
| `OTP_SENDER` | Dotted path to a class that sends the code by SMS (see [closed testing](#closed-testing)) |
| `OTP_ECHO_IN_RESPONSE` | `0` |
| `TESTER_PHONES` | Empty, except during closed testing |
| `NOMINATIM_USER_AGENT` | App name and a real contact |

With `DEBUG=0` Django also redirects HTTP to HTTPS, sends HSTS (`SECURE_HSTS_SECONDS`, one year
by default) and marks its cookies secure. It trusts the `X-Forwarded-Proto` header, which Caddy
sets itself; `web` must therefore never be reachable except through Caddy.

### Start-up checks

With `DEBUG=0` the process refuses to start when:

- `SECRET_KEY` is missing or shorter than 50 characters.
- `REF_HASH_PEPPER` is missing or equal to `SECRET_KEY`.
- `ALLOWED_HOSTS` or `DATABASE_URL` is missing.
- `OTP_ECHO_IN_RESPONSE=1` without `TESTER_PHONES`. Anyone could sign in as any phone number.
- The console OTP sender without `TESTER_PHONES`, under its own name or as a subclass. No code
  would ever reach a user.
- An `OTP_SENDER` that cannot be imported, without `TESTER_PHONES`.
- `TESTER_PHONES` with more than 10 numbers, or with an entry that is not E.164.

The rules live in `config/startup.py`. A refusal shows up as `web` restarting in a loop; the
reason is in `docker compose -f docker-compose.prod.yml logs web`.

## 1. Server prep

Run as root on a fresh Ubuntu 24.04 server. The deploy user is `forreal`.

```bash
# Updates
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# Deploy user with your SSH key and sudo
adduser --disabled-password --gecos "" forreal
usermod -aG sudo forreal
install -d -m 700 -o forreal -g forreal /home/forreal/.ssh
install -m 600 -o forreal -g forreal /root/.ssh/authorized_keys /home/forreal/.ssh/authorized_keys
echo 'forreal ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/forreal && chmod 440 /etc/sudoers.d/forreal
visudo -cf /etc/sudoers.d/forreal

# Docker and the compose plugin, from Docker's own repository
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker forreal

# Firewall: SSH, HTTP, HTTPS only
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 443/udp
ufw --force enable

# Automatic security updates
apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades
```

`forreal` has no password, so its sudo is passwordless and the SSH key is the only way in.
Membership of the `docker` group is equivalent to root on this machine.

**Lock down SSH only after proving the new login works.** Keep the root session open, and in a
second terminal run:

```bash
ssh forreal@SERVER 'sudo -n true && docker ps && echo ok'
```

Only when that prints `ok`, back in the root session:

```bash
printf 'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' > /etc/ssh/sshd_config.d/00-hardening.conf
sshd -t && systemctl reload ssh
sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication) '
```

The file name starts with `00-` because sshd keeps the first value it reads, and cloud images ship
a `50-cloud-init.conf`. All three lines of the last command must say `no`. Test once more from a
new terminal (`ssh forreal@SERVER`) before closing the root session.

## 2. First deploy

As `forreal`:

```bash
git clone https://github.com/ekesel/ForReal.git ~/ForReal
cd ~/ForReal/backend
git rev-parse HEAD                      # record the deployed commit

cp .env.prod.example .env && chmod 600 .env

# Generate the three secrets straight into .env, without printing them
python3 - <<'PY'
import pathlib, re, secrets
env = pathlib.Path(".env")
text = env.read_text()
for name, value in {
    "SECRET_KEY": secrets.token_urlsafe(50),
    "REF_HASH_PEPPER": secrets.token_urlsafe(50),
    "POSTGRES_PASSWORD": secrets.token_hex(32),
}.items():
    text = re.sub(rf"^{name}=.*$", f"{name}={value}", text, flags=re.M)
env.write_text(text)
PY

nano .env        # DOMAIN, ALLOWED_HOSTS, CSRF_TRUSTED_ORIGINS, ADMIN_PATH, TESTER_PHONES, NOMINATIM_USER_AGENT

docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f caddy      # until "certificate obtained successfully"
```

The host name must already resolve to the server and ports 80 and 443 must be open, or the
certificate cannot be issued. Let's Encrypt limits how many certificates a registered domain gets
per week; on a shared domain such as `sslip.io` that limit is shared with everyone else, so a
rate-limit error there is not something a retry fixes.

Create the admin user (the login is a phone number):

```bash
docker compose -f docker-compose.prod.yml exec web python manage.py createsuperuser
```

The admin is at `https://DOMAIN/ADMIN_PATH`. Then install the backup cron ([Backups](#5-backups))
and run the [post-deploy checklist](#post-deploy-checklist).

`POSTGRES_PASSWORD` is used when the database volume is first created. Changing it in `.env`
later does not change the password inside the database, and `web` will fail to connect.

## 3. Updates

```bash
cd ~/ForReal/backend
git rev-parse HEAD                      # note it: this is what you roll back to
./scripts/backup.sh                     # always, before an update
git pull --ff-only
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs --tail 50 web
```

`web` applies new migrations when it starts. `.env` is not in git and is untouched by a pull; when
a release adds a variable, compare with `.env.prod.example` and add it before `up`. Changing only
`.env` (for example `TESTER_PHONES`) needs `docker compose -f docker-compose.prod.yml up -d`, which
recreates the containers that read it.

## 4. Rollback

To the commit noted before the update:

```bash
cd ~/ForReal/backend
git checkout <previous-commit>
docker compose -f docker-compose.prod.yml up -d --build
```

This rolls back code only. If the update applied database migrations, the old code may not work
with the new schema. Either reverse them **before** checking out the old commit, while the new
code is still running:

```bash
docker compose -f docker-compose.prod.yml exec web python manage.py showmigrations
docker compose -f docker-compose.prod.yml exec web python manage.py migrate <app> <last-migration-of-the-old-release>
```

or restore the backup taken before the update ([Restore](#restore)), which also discards
everything written since. Afterwards `git checkout main` returns to the branch for the next update.

## 5. Backups

`scripts/backup.sh` dumps the database from the `db` container in PostgreSQL's compressed custom
format, checks that the dump is readable, and deletes dumps older than 14 days. Dumps go to
`~/backups` (`BACKUP_DIR` overrides it; `KEEP_DAYS` changes the 14).

Install the daily cron as `forreal`:

```bash
mkdir -p ~/backups && chmod 700 ~/backups
( crontab -l 2>/dev/null | grep -v scripts/backup.sh; echo '30 2 * * * /home/forreal/ForReal/backend/scripts/backup.sh >> /home/forreal/backups/backup.log 2>&1' ) | crontab -
crontab -l
~/ForReal/backend/scripts/backup.sh     # run one now
```

The dumps stay on the same server. They protect against a bad migration or a mistake, not against
losing the server; copy them elsewhere for that. A dump contains everything in the database, so
treat it like the database. `.env` is not in the dump: keep a copy of `REF_HASH_PEPPER` somewhere
safe, because a restored database is only useful with the same pepper.

### Restore

Prove a dump restores, into a scratch database that is dropped afterwards:

```bash
cd ~/ForReal/backend
DUMP=$(ls -t ~/backups/forreal-*.dump | head -1)
C="docker compose -f docker-compose.prod.yml"
$C exec -T db dropdb -U forreal --if-exists restore_check
$C exec -T db createdb -U forreal restore_check
$C exec -T db pg_restore -U forreal -d restore_check --no-owner < "$DUMP"
$C exec -T db psql -U forreal -d restore_check -c "select count(*) from django_migrations"
$C exec -T db dropdb -U forreal restore_check
```

The count must match the live database (`-d forreal` in the same `psql` command).

Restore for real, replacing the live database:

```bash
$C stop web worker
$C exec -T db dropdb -U forreal forreal
$C exec -T db createdb -U forreal forreal
$C exec -T db pg_restore -U forreal -d forreal --no-owner < "$DUMP"
$C start web worker
```

## Closed testing

Closed testing lets a handful of named people use a deployed backend before an SMS provider is
set up. It is a temporary mode, not a way to launch.

Set `TESTER_PHONES` to a comma-separated list of E.164 numbers, at most 10:

```
DEBUG=0
TESTER_PHONES=+919876543210,+919812345678
```

While it is set:

- **Only listed numbers can sign in.** `auth/otp/request/` and `auth/otp/verify/` answer any other
  number with 403 and `{"code": "not_invited", ...}`. No challenge is created and nothing is sent.
  This includes people who already have an account.
- **No SMS is sent**, whatever `OTP_SENDER` is. The code is returned in the response as
  `debug_code`, and the app fills it in.
- **The console sender and the echo are allowed** with `DEBUG=0`. Without `TESTER_PHONES` they stop
  the process from starting.
- **The usual limits still apply**: 5 code requests per phone per hour, 5 wrong attempts per code,
  and the per-IP throttle.
- **Every process logs a warning at start-up** saying closed-testing sign-in is active and how many
  numbers are listed.

What it does not do: sessions that already exist keep working. A person who signed in before the
list was set, and is not on it, stays signed in until their refresh token expires (60 days) or
their account is disabled in the admin.

Why it is safe only for a small, known group: the code comes back to whoever asks for it, so
knowing a listed number is enough to sign in as that person. Share the list with nobody outside it.

### Before any wider release

Closed testing **must be removed** before anyone outside the list uses the app:

1. Configure a real SMS sender in `OTP_SENDER`.
2. Remove `TESTER_PHONES`.
3. Set `OTP_ECHO_IN_RESPONSE=0`.
4. Restart and confirm the start-up log no longer shows the closed-testing warning, and that
   `auth/otp/request/` no longer returns `debug_code`.

Removing `TESTER_PHONES` while the console sender or the echo is still configured stops the process
from starting, on purpose: it cannot fall back to an open deployment where codes are echoed.

## Post-deploy checklist

Run after the first deploy and after any change to `.env`. `H` is the host name.

| # | Check | How | Pass |
| --- | --- | --- | --- |
| 1 | Health over HTTPS | `curl -sS https://H/health/` | `{"status": "ok"}` with a valid certificate |
| 2 | HTTP redirects | `curl -sI http://H/health/` | `308` with `Location: https://H/health/` |
| 3 | Unlisted number refused | `curl -sS -X POST https://H/api/v1/auth/otp/request/ -H 'Content-Type: application/json' -d '{"phone":"+919000000000"}'` | 403, `"code": "not_invited"` |
| 4 | Listed number echoed | The same with a number from `TESTER_PHONES` | 200 with `debug_code` |
| 5 | Admin moved | `curl -sI https://H/admin/` and `curl -sI https://H/ADMIN_PATH/login/` | 404, then 200 |
| 6 | Admin has its CSS | `curl -sI https://H/static/admin/css/base.css` | 200, `text/css` |
| 7 | Database and Redis closed | From another machine: `nc -vz -w 5 H 5432` and `nc -vz -w 5 H 6379` | Both fail |
| 8 | Geocoding works | `docker compose -f docker-compose.prod.yml logs worker \| grep assign_locality` after a payment with a location is synced, or run `python manage.py backfill_localities` in `web` | A task `succeeded`, and the locality appears in the admin |
| 9 | Start-up refusals not triggered | `docker compose -f docker-compose.prod.yml ps` and `logs web \| grep -i "refusing\|StartupError"` | All services `Up`, `web` healthy, no match |
| 10 | Closed-testing warning present | `logs web \| grep "CLOSED-TESTING"` | Present while `TESTER_PHONES` is set, absent after it is removed |
| 11 | Backup works | `scripts/backup.sh`, then the scratch restore above | A dump in `~/backups`, counts match |
