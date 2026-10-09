# KopraGrade UI redesign: notes and test checklist

Only the Flutter frontend changed. Backend, model, API, database, services, providers' logic and
the existing tests are untouched.

## What changed
- `core/theme.dart`: palette (Forest #174D36, Fresh #2E8B57, White, Light Gray #F4F6F4, Dark Gray #333333,
  Soft Green #E6F2E8), typography scale, buttons, inputs, nav bar; grade colors + icons.
- `widgets/common.dart`: `KCard`, `BrandMark`, `NoticeBanner`, `StatePanel`, `GradeBadge`, `InitialAvatar`, logout dialog.
- `widgets/grading_tile.dart`, `widgets/auth_layout.dart`: shared history row and login/register frame.
- `screens/home_shell.dart`: sidebar (>= 900 px wide) / header + bottom navigation (phones).
- `screens/dashboard_screen.dart` (new): welcome, Scan Copra (phones) / Upload Image, real counts, recent list.
  Counts come from the existing `GET /api/history` (`total` per class); nothing is hardcoded.
- `screens/upload_screen.dart`: upload area, drag and drop (web), preview, replace / remove, Classify Image.
- `screens/scan_screen.dart`: new look, flashlight + camera switch (when supported). Capture logic unchanged.
- `screens/result_screen.dart`, `history_screen.dart`, `login_screen.dart`, `register_screen.dart`, `profile_screen.dart`.
- `core/file_drop*.dart`: web drag and drop using only `dart:js_interop` (no new package).
  If it ever breaks a web build, change the export in `core/file_drop.dart` to `file_drop_stub.dart`.
- `providers/home_providers.dart`: selected tab + dashboard data.
- `web/index.html`, `web/manifest.json`: name and theme colors.

## Not verified yet (no Flutter SDK was available when this was written)
Run `flutter pub get && flutter analyze && flutter test` first, then the checks below.

## Test checklist
Backend running + a trained model. Test as a **farmer** and as a **buyer**.
Widths: desktop (>= 1200), tablet (~800), phone (360).

1. Register (both roles), log in, wrong password error, log out (confirm dialog), session restore on reload.
2. Dashboard: counts match History totals; recent list shows <= 5 newest; empty state with a new account;
   server stopped -> error panel + Try again; pull to refresh.
3. Upload: Choose File; drag and drop (web); .gif / renamed .txt -> "Unsupported image"; > 5 MB -> too large;
   replace; remove; Classify Image shows "Processing image..."; non-copra photo -> backend 422 message shown;
   stop backend -> "Cannot reach the server".
4. Result: "Classification completed.", exact labels Well-Dried / Moderately Dried / Poorly Dried, confidence,
   date/time, Scan Again / Upload Another Image / View History all navigate correctly.
5. Scanner (real phone, HTTPS or localhost): permission prompt, deny -> blocked card -> Try again / Upload instead;
   frame + instructions; Capture; flashlight (rear camera, not in browsers); switch camera; result; Scan Again.
6. History: class chips, date range, search (loaded records), Load more, tap -> details, empty / no-match / error states.
7. Profile: edit name/contact, success banner, validation errors, log out.
8. No horizontal scroll at 360 px on every page; keyboard focus visible on desktop.

## Known notes
- Recommendation text comes from `backend/app/services/grading_rules.py`, which is marked DRAFT wording.
  Have it reviewed before presenting it as "verified criteria".
- Fresh Green (#2E8B57) with white text is about 4.2:1 contrast: fine for large/bold button labels,
  slightly under 4.5:1 for small text. Small green text uses Forest Green instead.
- The History search box only searches records already loaded (the API has no text search).
