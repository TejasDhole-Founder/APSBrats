# APS Brat Frontend

Flutter frontend scaffold inside `APSBrats/frontend` with:
- Clean Architecture folder layout under `lib/core` + `lib/features`
- Riverpod + go_router baseline
- Reusable UI components and centralized theme/constants
- Dio client with JWT header injection
- Dev/Staging/Prod entrypoints

## Run

```bash
flutter pub get
flutter run -t lib/main_dev.dart --dart-define=BASE_URL=http://localhost:8080/api
```

For staging/prod:

```bash
flutter run -t lib/main_staging.dart --dart-define=BASE_URL=https://staging.apsbrat.in/api
flutter run -t lib/main_prod.dart --dart-define=BASE_URL=https://api.apsbrat.in/api
```

## Notes

- Web viewport meta is configured in `web/index.html`.
- If you see Windows symlink warnings, enable Developer Mode:
  `start ms-settings:developers`
