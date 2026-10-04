# Deploying the ForReal backend

This covers the settings that decide whether a deployment is safe to expose. For running the
backend locally, see [README.md](README.md).

## Production settings

Everything comes from environment variables (see `.env.example`).

| Variable | Production value |
| --- | --- |
| `DEBUG` | `0` |
| `SECRET_KEY` | Long and random. The process refuses to start without it |
| `REF_HASH_PEPPER` | Separate from `SECRET_KEY`. Set once and never change it |
| `ALLOWED_HOSTS` | The real host names |
| `OTP_SENDER` | Dotted path to a class that sends the code by SMS |
| `OTP_ECHO_IN_RESPONSE` | `0` |
| `TESTER_PHONES` | Empty |
| `NOMINATIM_USER_AGENT` | App name and a real contact |

Serve behind HTTPS.

### Start-up checks

With `DEBUG=0` the process refuses to start when sign-in would be unsafe:

- `OTP_ECHO_IN_RESPONSE=1` without `TESTER_PHONES`. Anyone could sign in as any phone number.
- The console OTP sender without `TESTER_PHONES`, under its own name or as a subclass. No code
  would ever reach a user.
- An `OTP_SENDER` that cannot be imported, without `TESTER_PHONES`.
- `TESTER_PHONES` with more than 10 numbers, or with an entry that is not E.164.

The rules live in `config/startup.py`.

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
