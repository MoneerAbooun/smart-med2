# Deploy Smart Med on Back4App Containers

This repository's Back4App container deploys the FastAPI backend in
`smart_med_api/`. The Flutter app remains the Android, iOS, or web client.

## 1. Push the deployment files

Commit and push the root `Dockerfile`, `.dockerignore`, and API changes to the
GitHub branch connected to Back4App.

Do not commit a Firebase service-account JSON file or a local `.env` file.

## 2. Configure the Back4App container

In the Back4App Containers app settings, use:

- **Branch:** the branch containing the Dockerfile
- **Root directory:** the repository root (leave the default root value)
- **Auto deploy:** optional

Add this environment variable:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: the complete contents of the Firebase
  service-account JSON file

The JSON can be formatted on one line. Keep the `\n` sequences inside the
`private_key` value intact. Back4App stores this value outside the repository.

Do not set `GOOGLE_APPLICATION_CREDENTIALS` in Back4App; that variable is only
for a credential file that exists on disk. The container listens on `PORT` when
Back4App supplies it and otherwise uses port `8080`.

## 3. Deploy and verify

Choose **Deploy latest commit**. After the deployment succeeds, open:

```text
https://smartmed-km6mdeft.b4a.run/health
```

The expected response is:

```json
{"status":"ok"}
```

Interactive API documentation is available at:

```text
https://smartmed-km6mdeft.b4a.run/docs
```

## 4. Connect the Flutter app

Use the exact HTTPS URL shown by Back4App, without a trailing slash:

```powershell
cd smart_med
flutter run
```

For a release APK:

```powershell
flutter build apk --release
```

The deployed API URL is the app's default. To use a local API temporarily:

```powershell
flutter run --dart-define=SMART_MED_API_BASE_URL=http://192.168.1.50:8000
```

## Image-storage limitation

Uploaded profile and medication images currently use the container filesystem.
Container files can disappear after a restart or redeployment. Before relying
on these uploads in production, move them to persistent object storage such as
Firebase Storage.
