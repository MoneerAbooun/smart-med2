# smart_med

Smart Med is a Flutter app backed by Firebase Auth, Cloud Firestore, and a
small FastAPI service for medicine lookup, drug details, and interaction data.

## Backend URL

By default the Flutter app uses:

- Android emulator: `http://10.0.2.2:8000`
- Other platforms: `http://127.0.0.1:8000`

Override it when needed:

```bash
flutter run --dart-define=SMART_MED_API_BASE_URL=http://192.168.1.50:8000
```

Use your machine's LAN IP when running the app on a physical phone.
