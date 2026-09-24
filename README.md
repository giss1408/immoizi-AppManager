# Immoizi App Manager

Flutter mobile frontend for landlords and property managers.

## Features

- Landlord property portfolio through `myLandlordProperties`
- Lease, rent payment, and maintenance overview
- Compact operational metrics for mobile dashboards
- French-first mobile interface
- Configurable GraphQL endpoint and bearer token from the app screen

## Run

```bash
flutter pub get
flutter run
```

Default endpoint:

```text
http://127.0.0.1:8000/graphql
```

The backend must provide an authenticated bearer token for landlord or manager users.
