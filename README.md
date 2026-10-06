# KopraGrade

A farmer takes a photo of dried copra. The app grades it as **Well-Dried**, **Moderately Dried** or
**Poorly Dried**, shows a **confidence score** and a **recommendation**, and keeps a history.
Buyers can view the gradings (read-only).

```
Flutter app (web / Android / iOS)
        |  HTTP + JSON  (JWT token)
        v
FastAPI  (ONE Python application, port 8000)
   |-- login, roles (farmer / buyer)
   |-- image check + preprocessing (Pillow + OpenCV)
   |-- MobileNetV2 model (TensorFlow/Keras), runs INSIDE FastAPI
   |-- saves photos to  uploaded_images/
   v
PostgreSQL  (database kopragrade_db, schema kopragrade)
```

## Technology stack

| Part | What is used |
|---|---|
| Frontend | Flutter (web + mobile), Dart 3, Riverpod 2.x (`flutter_riverpod`), Dio 5.8+, `image_picker`, `camera`, `shared_preferences` (login token), `intl` |
| Backend | FastAPI, Python, Uvicorn, REST API, SQLAlchemy + asyncpg, JWT (PyJWT), bcrypt, UploadFile, python-dotenv, CORS middleware |
| Database | PostgreSQL 16 / 18, schema `kopragrade`, 5 tables |
| Image processing | OpenCV + Pillow, on the server, photos in `uploaded_images/` |
| Machine learning | TensorFlow/Keras, MobileNetV2 transfer learning, scikit-learn for evaluation, runs inside FastAPI |
| Tools | Git, GitHub, VS Code, pgAdmin, pip, Flutter SDK, Postman |

## Folders

| Folder | What is inside |
|---|---|
| `database/` | `schema.sql` (the 5 tables) and `seed.sql` (the 3 quality classes) |
| `backend/` | The FastAPI application (`app/`), tests (`tests/`), `requirements.txt`, `.env.example`, `model/` (the trained model goes here) |
| `training/` | `train_model.py` (real training), `make_demo_model.py` (fake model for testing), `model_def.py` |
| `frontend/` | The Flutter app |
| `uploaded_images/` | Copra photos saved by the API |

## What was tested, and what was not

- **Tested for real:** the database setup on PostgreSQL 16, all API endpoints (35 automated tests),
  login/roles/JWT, photo upload and saving, rollback when something fails, the Keras model loading and
  predicting inside FastAPI, and the training script (on a tiny fake dataset, to prove it runs).
  Python 3.12, TensorFlow 2.21 (Keras 3), FastAPI, SQLAlchemy 2.1.
- **Not tested:** the **Flutter app** (Flutter could not be installed where this was built), and PostgreSQL **18**
  (16 was used). Expect to possibly fix a small thing on your first `flutter run`. If you see an error,
  copy the whole message and ask for help.
- **Not a trained model yet.** Until you train with your own copra photos, any model here is a demo and its
  answers are **not real**.

---

# Setup guide (step by step)

Do the steps in order. Commands are for **Windows (Command Prompt or VS Code terminal)** first;
Mac/Linux differences are written next to them.

## Step 0: Install the tools (one time)

1. **Python 3.12** (64-bit) from python.org. On Windows tick **"Add python.exe to PATH"** during install.
   Check: `python --version`
   > TensorFlow does not support the newest Python versions right away. Use **3.12** (3.11 also works).
2. **PostgreSQL 16 or 18** from postgresql.org. Remember the password you give to the `postgres` user.
   It also installs **pgAdmin**.
3. **Flutter SDK** from flutter.dev (it includes Dart 3). Run `flutter doctor` and fix what it complains about.
4. **Git** and **VS Code** (with the Flutter and Python extensions). **Postman** is optional, for testing the API.

## Step 1: Backend (FastAPI)

Open a terminal in the project folder, then:

```
cd backend
python -m venv .venv
.venv\Scripts\activate
```
(Mac/Linux: `source .venv/bin/activate`.) You should now see `(.venv)` at the start of the line.
**Every time you open a new terminal for the backend, activate it again.**

```
pip install -r requirements.txt
```
This downloads TensorFlow, so it can take several minutes. Wait until it finishes.

Create your settings file:
```
copy .env.example .env
```
(Mac/Linux: `cp .env.example .env`.) Open `backend/.env` in VS Code and change **two** things:

1. `DATABASE_URL`: replace `YOUR_PASSWORD` with your PostgreSQL password.
   If the password contains `@ : / # ?` write them as `%40 %3A %2F %23 %3F`.
2. `JWT_SECRET`: run this command and paste its output (a long random text):
   ```
   python -c "import secrets; print(secrets.token_hex(32))"
   ```
Do not use quotes. Do not share or upload `.env` (it is already in `.gitignore`).

## Step 2: Create the database

Still in `backend` with `(.venv)` active:
```
python -m app.db_setup
```
It prints `Database ready. Quality classes: Well-Dried, Moderately Dried, Poorly Dried`.
It creates the database, the schema `kopragrade` and the 5 tables. It is safe to run again.
In **pgAdmin** you can look: `kopragrade_db > Schemas > kopragrade > Tables`.

## Step 3: Get a model

The API needs a model file to grade photos. Pick **one**:

**A) Quick demo model (to test the whole app today).** Results are NOT real.
```
cd ..\training
python make_demo_model.py
cd ..\backend
```
The first run downloads the MobileNetV2 weights (needs internet).

**B) Real model (when you have your copra photos).** Arrange the photos like this inside `training/`:
```
training/dataset/train/Well-Dried/...jpg
training/dataset/train/Moderately Dried/...jpg
training/dataset/train/Poorly Dried/...jpg
training/dataset/val/...   (same three folders)
training/dataset/test/...  (same three folders)
```
Keep all photos of the same copra sample inside the same split (train, val or test).
Then:
```
cd ..\training
python train_model.py
cd ..\backend
```
At the end it prints a confusion matrix and a report (scikit-learn). Mistaking Well-Dried for Poorly Dried
(or the reverse) is the worst mistake, so check those cells. It saves the model into `backend/model/`.

> Without a model file the API still starts. Login and history work, but grading answers
> "The grading model is not available" and `/api/health` explains why.

## Step 4: Start the API

In `backend`:
```
uvicorn app.main:app --reload
```
Look for `KopraGrade API is ready`. Then open in your browser:
- http://localhost:8000/api/health shows `"status":"ok"` and `"model_loaded":true`
- http://localhost:8000/docs is a page where you can try every endpoint

Leave this terminal running. (Stop with `Ctrl + C`.)

## Step 5: Start the Flutter app

Open a **second** terminal:
```
cd frontend
flutter create --platforms=web,android,ios .
flutter pub get
flutter run -d chrome
```
- `flutter create ... .` (note the dot) is needed **once**: it adds the platform folders and keeps our code.
- For an **Android emulator**: `flutter run`. The emulator reaches your computer at `10.0.2.2` (already the default).
- For a **real phone** on the same Wi-Fi, use your computer's IP address:
  `flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000`
  Windows Firewall must allow port 8000, and the backend must listen on all addresses:
  `uvicorn app.main:app --host 0.0.0.0 --port 8000`

**Android:** while the API uses plain `http://`, add `android:usesCleartextTraffic="true"` to the `<application>` tag in
`frontend/android/app/src/main/AndroidManifest.xml`, and add
`<uses-permission android:name="android.permission.INTERNET"/>` above it (needed for release builds).

**iOS:** add `NSCameraUsageDescription` (needed by **Scan Copra**) and `NSPhotoLibraryUsageDescription` (each with a short text) to `ios/Runner/Info.plist`.

**Android:** `tools/prepare_android.py` (run by `build_apk`) adds the `CAMERA` permission that **Scan Copra** needs. If you build by hand, add `<uses-permission android:name="android.permission.CAMERA"/>` too.

## Step 6: Try it

1. Create a **Farmer** account and log in.
2. On the **Grade** tab choose a photo (JPG or PNG, max 5 MB) and press **Grade this copra**.
3. You see the grade, confidence and recommendation. The **History** tab lists your gradings.
4. Create a **Buyer** account (use another email). Buyers see everyone's gradings but cannot grade.

## Scan Copra (phones) and Upload Photo (everywhere)

The **Grade** tab changes with the device:

| Device | Buttons |
|---|---|
| Phone (Android / iPhone, app or mobile browser) | **Scan Copra** and **Upload Photo** |
| PC / laptop (Windows, macOS, Linux browser or desktop app) | **Upload Photo** only. The scanner is not built at all. |

**Scan Copra** opens the live camera with a frame. When the camera is held steady for about a second, it takes
**one** photo and sends it to the same `POST /api/classification/predict` as Upload Photo, so the same model, the same
`LOW_CONFIDENCE_THRESHOLD` / `REJECT_BELOW_CONFIDENCE` rules and the same history are used. The **Capture** button is
always there if automatic capture does not trigger. The "hold steady" check only decides *when* to take the photo; it
does not grade anything. A photo the backend rejects ("No copra detected") saves nothing, and the scanner waits for the
camera to move before trying again. Only one request runs at a time, and the camera is released when you leave the
screen, put the app in the background or open a result.

Notes: on the **web** the camera only works on `https://` or `localhost`, and browsers cannot stream frames here, so
you use the Capture button. Automatic capture needs the Android/iPhone app.

## Step 7: Run the automated tests (optional)

In `backend`:
```
pip install -r requirements-dev.txt
set TEST_DATABASE_URL=postgresql+asyncpg://postgres:YOUR_PASSWORD@localhost:5432/kopragrade_test
pytest
```
(Mac/Linux: `export TEST_DATABASE_URL=...`.) The test database is created automatically.
Never point it at your real database. For the Flutter side: `cd frontend` then `flutter test`.

---

# REST API

All bodies are JSON except the photo upload. **Every error looks like `{ "error": "message" }`.**
Send `Authorization: Bearer <token>` on everything except register, login and health.

| Method | Endpoint | Who | Purpose |
|---|---|---|---|
| POST | `/api/auth/register` | anyone | `name, email, password (8+), role (farmer/buyer)` -> 201 + user |
| POST | `/api/auth/login` | anyone | `email, password` -> `token` + user |
| POST | `/api/classification/predict` | **farmer only** | multipart field `image` (JPG/PNG, max 5 MB) -> 201 + grading |
| GET | `/api/gradings/{id}` | farmer (own) / buyer (any) | one grading |
| GET | `/api/history` | farmer (own) / buyer (all) | list; filters `grade`, `from`, `to` (YYYY-MM-DD), `limit`, `offset` |
| GET | `/api/users/me` | logged in | current profile |
| PUT | `/api/users/me` | logged in | update `name`, `contact` |
| GET | `/api/health` | anyone | server and model check |

Status codes: 400 invalid input, 401 not logged in, 403 wrong role or someone else's grading, 404 not found,
409 email already used, 413 image too large, 415 not a real JPG/PNG, 422 unreadable image,
503 model not available (nothing is saved).

**Testing with Postman:** 1) POST `/api/auth/login` with a JSON body and copy the `token`.
2) For the next requests open the **Authorization** tab, choose **Bearer Token**, paste it.
3) For the upload choose **Body > form-data**, add a key named `image`, change its type to **File**, pick a photo.

## How one grading flows

1. The farmer picks a photo. The app checks type, size and the file header.
2. `POST /api/classification/predict`: FastAPI checks the token and the **farmer** role, and checks the file again.
3. **Preprocessing:** Pillow opens the photo, fixes phone rotation and converts to RGB; OpenCV resizes to 224 x 224.
4. **MobileNetV2 inference** (inside FastAPI) gives a probability for each class.
5. The best class is the **quality classification**; its probability (0-100) is the **confidence score**.
6. In **one transaction** the API saves `copra_samples` (code like `COPRA-2026-001`), `copra_images`
   (the path `uploaded_images/<random>.jpg`) and `classification_results`. If anything fails, nothing is saved
   and the photo is deleted.
7. The app opens the result screen. Confidence under 70 is flagged **"needs review"**.

The **recommendation** text is made by the API from the grade each time. It is **not stored in the database**.

## Database

Schema `kopragrade` with exactly 5 tables: `users`, `copra_samples`, `copra_images`, `quality_classes`,
`classification_results`. The `password` column stores a **bcrypt hash**, never the real password.
The SQL is in `database/schema.sql`.

## Settings you may want to change (`backend/.env`)

| Setting | Meaning |
|---|---|
| `LOW_CONFIDENCE_THRESHOLD` | Below this confidence (0-100) a result is flagged "needs review" (default 70) |
| `REJECT_BELOW_CONFIDENCE` | Below this confidence (0-100) the photo is rejected with "No copra detected" and nothing is saved (default 50, 0 = off) |
| `MAX_UPLOAD_MB` | Largest photo accepted (default 5; the Flutter app uses the same 5 MB in `lib/core/config.dart`) |
| `CORS_ORIGINS` | `*` while developing. For a real website list its address, for example `https://myapp.example.com` |
| `JWT_EXPIRE_MINUTES` | How long a login lasts (default 1440 = 1 day) |
| `APP_TIMEZONE` | Used for the history date filter (default `Asia/Manila`) |

## Common problems

| Message or problem | What to do |
|---|---|
| `Missing required setting JWT_SECRET` | You did not create `backend/.env`, or JWT_SECRET is still the example text (Step 1). |
| `wrong PostgreSQL user or password` | Fix the password in `DATABASE_URL`. |
| `cannot reach PostgreSQL` | PostgreSQL is not running, or the port in `DATABASE_URL` is wrong (default 5432). |
| `pip install` fails on tensorflow | Check `python --version` is 3.12 (or 3.11) and 64-bit. |
| `The grading model is not available` | Do Step 3, then restart the API. Check `/api/health`. |
| Flutter: "Cannot reach the server" | Is `uvicorn` running? Android emulator must use `10.0.2.2`; a phone needs your PC IP (Step 5). |
| Photos do not show in the app | Open the `image_url` from the result in a browser (`http://localhost:8000/images/<file>`) to check the API serves it. |
| Everything is graded with low confidence | You are using the demo model. Train a real one (Step 3B). |

## Decisions to review with your instructor

- **Class descriptions** (`database/seed.sql`) and **recommendation wording**
  (`backend/app/services/grading_rules.py`) are drafts. Have someone who knows copra grading check them.
- **Buyers can view every farmer's gradings** (read-only). Change it in `backend/app/routers/history.py` and
  `gradings.py` if your rules differ.
- **Photo addresses are public but unguessable** (random file names), so the app can display them.
- The `users` table has extra columns (`name`, `email`, `role`, `contact`) needed for login and profiles.
