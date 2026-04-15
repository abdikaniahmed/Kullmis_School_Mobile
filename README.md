# kullmis_school_mobile

Flutter shell for the Kullmis School Laravel API.

## What changed

- Laravel `api/login` now issues a Sanctum bearer token for mobile clients.
- Laravel `api/logout` now revokes the current token.
- Flutter now has a login screen, token persistence, current-user bootstrap, and a school dashboard shell.

## Backend requirements

Run the Laravel app first:

```powershell
php artisan serve
```

If you use logos or other public files, also run:

```powershell
php artisan storage:link
```

## Flutter setup

Fetch packages:

```powershell
flutter pub get
```

Run the app and point it to Laravel with `--dart-define`.

Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

iOS simulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Real device on the same network:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR-LAN-IP:8000/api
```

## Notes

- The mobile app authenticates with bearer tokens, not Laravel session cookies.
- `school/dashboard` is only available for roles allowed by the Laravel API. A successful login without dashboard data usually means the role authenticated but does not have access to that endpoint.
- `NSAllowsArbitraryLoads` was enabled in iOS only to simplify local development over HTTP. Tighten that before production.
