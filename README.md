# ForReal backend

Phase 1 of the ForReal MVP: the backend that collects payments, resolves payees to
real shops, and tags what was bought. No analytics, search or rankings yet; those
are Phase 4 and are built on the data this collects.

Django 5.2, Django REST Framework, PostgreSQL 16 with PostGIS and pg_trgm, Celery with Redis.

## Run it

With Docker:

```bash
cp .env.example .env
docker compose up --build
```

Without Docker (needs PostgreSQL with PostGIS, and GDAL installed):

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
createuser -s forreal && createdb -O forreal forreal    # password: forreal
export DEBUG=1
python manage.py migrate
python manage.py createsuperuser      # phone + password, for /admin/
python manage.py runserver
```

Tests (71, need a PostGIS database the user may create databases on):

```bash
DEBUG=1 python manage.py test apps
```

The API is at `http://localhost:8000/api/v1/`, the admin at `/admin/`.

## Layout

| App | Holds |
| --- | --- |
| `accounts` | User (phone sign-in), Device, OTP, export and delete |
| `consents` | Per-purpose consent with full history and withdrawal effects |
| `geo` | Locality |
| `merchants` | Category, Payee, Merchant, PayeeMerchantLink, crowd matching |
| `transactions` | Transaction, batch ingest, de-duplication |
| `tagging` | Item catalogue, TransactionItem, TagWeight, suggestions |
| `parsers` | Per-bank SMS templates the app downloads |
| `common` | Shared helpers and the test base class |

Business rules live in each app's `services.py`; views only validate and call them.
Tunable thresholds are in `config/settings.py` under "Product rules".

## API

All endpoints are under `/api/v1/` and need `Authorization: Bearer <access>` except the OTP ones.

| Method and path | Purpose |
| --- | --- |
| `POST auth/otp/request/` | Send a code to `{phone}` |
| `POST auth/otp/verify/` | `{phone, code}` → access and refresh tokens; creates the user on first sign-in |
| `POST auth/token/refresh/` | New access token |
| `GET, PATCH, DELETE me/` | Profile; DELETE erases the account and all its data |
| `GET me/export/` | Everything held about the user |
| `PUT me/device/` | Register install and push token |
| `GET, POST consents/` | Current state; grant or withdraw `{purpose, granted, notice_version}` |
| `GET consents/history/` | Every change, oldest first |
| `GET parser-templates/?version=` | SMS templates; `changed: false` when the app is up to date |
| `POST transactions/batch/` | Ingest up to 200 parsed payments |
| `GET transactions/`, `GET transactions/{id}/` | The user's own payments (cursor paginated) |
| `GET payees/pending/` | Payees not yet labelled shop or person |
| `GET payees/{id}/suggestions/?lat=&lng=` | Shops other users confirmed for this payee nearby |
| `POST payees/{id}/resolve/` | `{kind: person}` or `{kind: merchant, merchant_id}` or `{kind: merchant, new_merchant: {name, category, is_online}}`, plus optional `lat`, `lng` |
| `GET merchants/search/?q=&lat=&lng=` | Fuzzy shop search |
| `GET categories/`, `GET items/?category=&q=` | Pickers for the app |
| `GET transactions/{id}/suggestions/` | Item guesses and whether to prompt |
| `PUT transactions/{id}/items/` | `{items: [{item_id or name, quantity}]}` replaces the tags |
| `POST transactions/{id}/items/confirm/` | The one-tap "Yes" |

### Ingest row

```json
{
  "client_txn_id": "7f1f2c1e-0000-4000-8000-000000000001",
  "payee_name": "RAMESH  KUMAR",
  "occurred_on": "2026-08-02",
  "day_part": "evening",
  "amount_band": "200_500",
  "source": "sms",
  "ref": "400012345678",
  "lat": 28.628, "lng": 77.365
}
```

Each result carries `status` (`created`, `duplicate`, `merged`), the stored transaction, `ask`
(`payee`, `items` or `null`: what the notification should ask) and `payee_suggestions`.

## Rules the code enforces

- **Nothing but payment facts.** Ingest rejects rows containing `amount`, `raw_text`, `balance`,
  account fields or `vpa`. The server stores an amount band, never the amount.
- **Reference numbers** are stored as an HMAC and used only to merge the same payment across lanes.
- **Location** is rounded to 3 decimals (about 110 m) and stored only while the user holds the
  `location` consent. Withdrawing it erases stored locations.
- **Consent** is append-only history. `community_rankings` and `location` need `private_analytics`;
  `show_name` and `merchant_insights` need `community_rankings`. Withdrawing a parent withdraws its
  children. Withdrawing `private_analytics` deletes the user's payments and payee answers.
- **Shared data** comes only from `Transaction.objects.shareable()`: confirmed shops, paid by users
  who hold the community consent right now. Payments to people are never shareable.
- **Crowd matching** suggests a shop for a payee only after `CROWD_MIN_CONFIRMATIONS` (2) consenting
  users confirmed it within `CROWD_MATCH_RADIUS_M` (500 m), or anywhere for online merchants.
- **Tags** store origin and confidence. Suggestions use user-confirmed tags only, so AI guesses never
  train AI. A replaced guess is kept, marked rejected, so weights can be tuned against real answers.
- **Prompts stop** after `AUTO_TAG_AFTER_CONFIRMATIONS` (3) confirmations of the same item at a payee.

## Known limits, on purpose

- One answer per user per payee name. A user who pays two different people with the same name
  cannot label them separately yet.
- The LLM fallback for item guesses (`ai_llm`) is not built; suggestions stop at the category default.
- Person-or-merchant inference (FR-9) and the daily prompt cap (app side) come later.
- OTP delivery is a console logger. Plug a real SMS provider in through `OTP_SENDER`.
- No localities are seeded. Add them in the admin; without them `locality` stays empty.
- Amount bands are the four from the product doc and are still an open question there.

## Before real users

Set `DEBUG=0`, a long random `SECRET_KEY`, a separate `REF_HASH_PEPPER`, `OTP_ECHO_IN_RESPONSE=0`,
real `ALLOWED_HOSTS`, and serve behind HTTPS.
