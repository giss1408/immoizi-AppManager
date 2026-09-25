# Immoizi App Manager

Flutter mobile frontend for landlords and property managers.

## Features

- Landlord property portfolio through `myLandlordProperties`
- Lease, rent payment, and maintenance overview
- Compact operational metrics for mobile dashboards
- French-first mobile interface
- Configurable GraphQL endpoint and bearer token from the app screen

## Run

Shared code lives in the sibling `immoizi-core` package (path dependency `../immoizi-core`), so check it out next to this repo.

```bash
flutter pub get
flutter run
```

### Configuration

Set at build time with `--dart-define`:

| Key | Default | Purpose |
| --- | --- | --- |
| `IMMOIZI_ENDPOINT` | `http://127.0.0.1:8000/graphql` | GraphQL endpoint |
| `IMMOIZI_DEMO_USERNAME` | empty | Pre-fills the login form (development only) |
| `IMMOIZI_DEMO_PASSWORD` | empty | Pre-fills the login form (development only) |

```bash
flutter run \
  --dart-define=IMMOIZI_DEMO_USERNAME=landlord_demo \
  --dart-define=IMMOIZI_DEMO_PASSWORD=...
```

On a USB-connected Android phone, `adb reverse tcp:8000 tcp:8000` makes the default `127.0.0.1` endpoint reach the backend on your computer.

### Session

After signing in, the bearer token is kept in the platform keystore (`flutter_secure_storage`), so the app stays signed in across restarts until the token expires (7 days on the backend). Logging out deletes the token and the cached dashboard.

## Test

```bash
flutter test
```
