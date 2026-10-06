# KopraGrade: build and install the Android APK

## 0. Read this first (honest status)

- The project is **Flutter (frontend) + FastAPI (backend) + PostgreSQL + Keras model**. It was inspected, not changed in Dart code.
- The zip had **no `frontend/android/` folder**, so Flutter has to generate it once. `build_apk.bat` does this for you.
- The APK **could not be built for you here**: the Flutter and Android SDK downloads are blocked in my environment.
  So the APK must be built on **your computer** with the commands below. Nothing was compiled or run on Flutter by me.
- **The APK is only the app screen.** Login, grading, the model and the database all live in the **backend on your computer**.

## 1. Can the APK work without the computer? (answers to your 4 questions)

| Situation | Works? |
|---|---|
| Backend running on your computer, phone on the **same Wi-Fi** | **Yes** (this guide) |
| Backend running on your computer, phone on mobile data / other Wi-Fi | No (needs a public HTTPS address, see section 7) |
| **Computer turned off / backend not running** | **No.** The app opens but shows "Cannot reach the server" |
| Backend deployed on an online server (HTTPS) | **Yes**, from anywhere (see section 7) |

## 2. One-time tools on your computer

1. **Flutter SDK** (flutter.dev) and **Android Studio** (it installs the Android SDK).
2. In Android Studio: *More Actions > SDK Manager > SDK Tools* > tick **Android SDK Command-line Tools** > Apply.
3. In Command Prompt:
   ```
   flutter doctor --android-licenses
   flutter doctor
   ```
   Press `y` for every license. Fix anything marked with a red X for **Android toolchain**.
4. Your backend setup from `README.md` (Steps 1 to 4) must already work on your computer.

## 3. Start the backend so the phone can reach it

Your backend `.env` is **not** inside the cleaned zip (it holds your password and secret). Keep using your own `backend/.env`.
If you start fresh: copy `.env.example` to `.env`, set your PostgreSQL password and a new `JWT_SECRET`.

Double-click **`start_backend.bat`** (or run the same thing by hand):
```
cd backend
.venv\Scripts\activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
`--host 0.0.0.0` is what lets the phone in. Wait for `KopraGrade API is ready`. Leave the window open.

Find your computer's IP address:
```
ipconfig
```
Look under **Wireless LAN adapter Wi-Fi** for **IPv4 Address**, for example `192.168.1.10`.

Allow port 8000 through Windows Firewall (Command Prompt **as Administrator**, once):
```
netsh advfirewall firewall add rule name="KopraGrade API" dir=in action=allow protocol=TCP localport=8000 profile=private
```
Your Wi-Fi must be set to a **Private** network in Windows.

**Test before building:** on the phone browser (same Wi-Fi) open `http://192.168.1.10:8000/api/health`.
You must see `"status":"ok"`. If not, the app will not connect either; fix this first (see section 9).

## 4. Where the API address is set

- The app reads it from `frontend/lib/core/config.dart` (`API_BASE_URL`). **No code edit is needed.**
- You pass it when building. It is **baked into the APK**, so if your computer's IP changes you must rebuild.
- Without it, the Android default is `http://10.0.2.2:8000`, which only works on the **emulator**, not a real phone.
- Tip: in your router, reserve a fixed IP for your computer so the address does not change.

## 5. Build the APK

In the project folder (the one containing `build_apk.bat`):

```
build_apk.bat http://192.168.1.10:8000
```
(Replace with your own IP. Mac/Linux: `./build_apk.sh http://10.29.80.74:8000`.)

What it does: creates the Android folder once (`flutter create --platforms=android --org com.kopragrade --project-name kopragrade .`),
adds internet permission + `usesCleartextTraffic` for `http://` + the name "KopraGrade" to `AndroidManifest.xml`,
then runs `flutter clean`, `flutter pub get`, `flutter analyze`, and
`flutter build apk --release --dart-define=API_BASE_URL=<your address>`.

- App ID: `com.kopragrade.kopragrade`
- APK location (note: it is inside `frontend`, not the project root):
  ```
  frontend\build\app\outputs\flutter-apk\app-release.apk
  ```
- The first build can take 5 to 15 minutes and downloads Gradle files.
- Permissions: **INTERNET** and **CAMERA** (the Scan Copra screen asks for the camera the first time it opens; Upload Photo needs no permission).
  The camera is declared as not required, so the app still installs on a device without one.
- The APK is signed with Flutter's debug key. That is fine for installing on your own phone, not for Google Play.

## 6. Install on the phone

**Method 1: USB cable**
1. Phone: *Settings > About phone* > tap **Build number** 7 times (Developer options turn on).
2. *Settings > Developer options* > turn on **USB debugging**.
3. Connect the USB cable. Choose **File transfer** on the phone. Accept "Allow USB debugging".
4. Quick way: `flutter install` inside `frontend` installs it directly.
   Manual way: copy `app-release.apk` to the phone's **Download** folder.
5. On the phone open **Files > Download > app-release.apk**.
6. If Android asks, allow **Install unknown apps** for that Files/Chrome app, then press **Install**.
7. Open **KopraGrade**.

**Method 2: send the file**
- **Google Drive:** upload the APK, open Drive on the phone, tap the file > Download, then open it.
- **Bluetooth:** send the file to the phone, accept it, open it from notifications.
- **Messenger/Telegram/email:** send as a **file/document**, download it on the phone, open it.
Then allow unknown sources and press Install, as above.

## 7. Using it away from home (deployed HTTPS backend)

Put the backend (FastAPI + PostgreSQL + `backend/model` + a **persistent** `uploaded_images/` folder) on an online server
that gives you an address like `https://api.yourdomain.com`, then rebuild:
```
build_apk.bat https://api.yourdomain.com
```
With `https://` the cleartext setting is not added. Also set `CORS_ORIGINS` and use a new `JWT_SECRET` on the server.
The model uses TensorFlow, so the server needs enough memory (plan for at least 2 GB RAM).
A quick temporary option is a tunnel tool (Cloudflare Tunnel or ngrok) that gives your computer's port 8000 an HTTPS address;
your computer must still be on.

## 8. Testing checklist

- [ ] Phone browser opens `http://YOUR_IP:8000/api/health` and shows `"model_loaded":true`
- [ ] App opens, no "Cannot reach the server"
- [ ] Register a **Farmer** account, then log in
- [ ] Close and reopen the app: still logged in
- [ ] Grade tab > **Gallery** > pick a JPG/PNG > **Grade this copra** > result shows grade, confidence, photo
- [ ] Grade tab > **Scan Copra** > allow the camera > hold over copra > a result opens > **Scan Again** works
- [ ] History tab lists the grading and the photo thumbnail shows
- [ ] Profile: change name, save
- [ ] Register a **Buyer** account: sees all gradings, cannot grade
- [ ] Log out and log in again

## 9. If something fails

| Problem | Fix |
|---|---|
| Phone browser cannot open `/api/health` | Backend started with `--host 0.0.0.0`? Firewall rule added? Same Wi-Fi? Router "AP/client isolation" off? Guest Wi-Fi often blocks this. |
| App says "Cannot reach the server" | Wrong IP built into the APK, or backend not running. Rebuild with the right IP. |
| Photos do not display | Open the photo URL in the phone browser; it must come from the same address. |
| `flutter analyze` shows errors | Copy the whole message and ask for help. The Flutter code was never compiled before. |
| Build says Android licenses not accepted | `flutter doctor --android-licenses` |
| Grades look random | The bundled model is a **demo model**. Train a real one (README Step 3B). |

## 10. Remaining limits (why it is not fully standalone)

1. The backend, PostgreSQL and the model run on a computer/server. The APK cannot grade copra by itself.
2. The API address is fixed inside each build. Changing it means rebuilding (an in-app "server address" setting could be added if you want).
3. `http://` is not encrypted; use HTTPS for anything beyond local testing.
4. Debug-signed APK: sideloading only.
5. The Flutter code and the build were not compiled or tested by me.
6. The `JWT_SECRET` that was in your old `.env.example` was a real secret. Create a new one:
   `python -c "import secrets; print(secrets.token_hex(32))"` and put it in your `backend/.env`.

## 11. What was changed and removed

**Added:** `build_apk.bat`, `build_apk.sh`, `start_backend.bat`, `tools/prepare_android.py`, this guide.
**Edited:** `backend/.env.example` only (real-looking JWT secret and sample password replaced by placeholders).
**One Dart fix:** `frontend/lib/screens/history_screen.dart` now imports `../providers/history_controller.dart`.

**Left out of the cleaned zip (all regenerated by tools, none referenced by the code):**
| Removed | Why it is safe |
|---|---|
| `backend/.venv/` (about 98% of the zip size) | Virtual environment; recreate with `python -m venv .venv` + `pip install -r requirements.txt`. Windows-specific, so it should not be shared. |
| `**/__pycache__/` | Python bytecode cache, rebuilt automatically |
| `frontend/.dart_tool/` | Generated by `flutter pub get` |
| `backend/.env` | Holds your password and secret; keep your own copy. Not deleted from your computer |

**Kept on purpose:** all source, `pubspec.yaml`/`pubspec.lock`, `backend/model/*` (needed for grading), `database/`, `training/`
(scripts and empty dataset folders), `backend/tests` and `frontend/test` (used by `pytest` / `flutter test`).
All 5 Flutter dependencies are used in the code, so none were removed.

## 12. Project structure

```
kopragrade/
├── backend/
│   ├── app/ (main.py, config.py, routers/, services/, models.py, schemas.py ...)
│   ├── model/ (kopragrade_model.keras, class_names.json)
│   ├── tests/
│   ├── .env.example   (create your own .env)
│   └── requirements.txt
├── database/ (schema.sql, seed.sql)
├── frontend/
│   ├── lib/ (core/config.dart, screens/, services/, providers/ ...)
│   ├── test/
│   ├── pubspec.yaml
│   └── android/   <- created by build_apk.bat on first run
├── tools/prepare_android.py
├── training/
├── uploaded_images/
├── build_apk.bat / build_apk.sh
├── start_backend.bat
├── ANDROID_APK_GUIDE.md
└── README.md
```
