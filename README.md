# ForReal

ForReal records what people actually pay for, starting from the payment messages their bank
already sends them, and turns that into private spending history for the user and, with consent,
anonymous neighbourhood rankings of shops and items.

| Folder | What | Status |
| --- | --- | --- |
| [`backend/`](backend/README.md) | Django REST API: accounts, consents, payees and shops, transactions, item tagging, parser templates, localities | Phase 1, with the Phase 2 location endpoint |
| [`app/`](app/README.md) | Android app (Flutter, with a Kotlin SMS module): capture, sync, prompts, tagging | Phase 2 |

## How the two fit together

1. The app downloads **parser templates** from the backend. They name the bank SMS senders and
   carry the regular expressions that read a payment message.
2. On the phone, a small Kotlin receiver keeps messages from those bank senders only and hands them
   to Dart, which parses them. **The message text and the exact amount never leave the phone.**
3. The app uploads the payee name, the date, the part of the day and an amount band to
   `POST /api/v1/transactions/batch/`. The backend refuses rows that carry an amount, message text,
   a balance, account digits or a VPA.
4. The backend answers with what to ask the user: which shop was that, or what did you buy. The app
   asks in a notification, and the answers go back through the payee and item endpoints.
5. With the location consent, a rounded location (about 110 m) identifies the shop and names the
   area. Area names come from OpenStreetMap.

## Quick start

Backend:

```bash
cd backend
cp .env.example .env
docker compose up --build        # API on http://localhost:8000/api/v1/
```

App, against that backend from the Android emulator:

```bash
cd app
flutter pub get
flutter run                      # default API_BASE_URL is http://10.0.2.2:8000
```

From a physical phone, pass the computer's LAN address and add it to the backend's
`ALLOWED_HOSTS`; see [app/README.md](app/README.md#run-against-a-local-backend-from-a-physical-phone).

## Checks

```bash
cd backend && DEBUG=1 python manage.py test apps && python manage.py makemigrations --check --dry-run
cd app && flutter analyze && flutter test && flutter build apk --debug
cd app/android && ./gradlew :app:testDebugUnitTest
```

## Privacy rules both sides enforce

- Raw SMS text and exact amounts stay on the device.
- Only messages from bank senders named in the parser templates are read, stored or parsed.
- Nothing is captured or uploaded before the `private_analytics` consent, and withdrawing it
  deletes the user's payments on the server and on the phone.
- Location is approximate and foreground-only, stored only under the `location` consent.
- No analytics or crash-reporting SDKs.

Area names © OpenStreetMap contributors (ODbL). The app must show this wherever locality names appear.
