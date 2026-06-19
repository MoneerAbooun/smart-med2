# smart_med

Smart Med is a Flutter app backed by Firebase Auth, Cloud Firestore, and a
small FastAPI service for medicine lookup, drug details, and interaction data.

## Backend URL

By default the Flutter app uses the deployed Back4App API:

```text
https://smartmed-km6mdeft.b4a.run
```

Override it when using a local backend:

```bash
flutter run --dart-define=SMART_MED_API_BASE_URL=http://192.168.1.50:8000
```

Use your machine's LAN IP when running a local backend on a physical phone.
