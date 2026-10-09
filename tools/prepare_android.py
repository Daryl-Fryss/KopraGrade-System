"""Patches the Flutter-generated Android project so KopraGrade works on a real phone
Safe to run many times. Usage: python tools/prepare_android.py http://192.168.1.10:8000
"""
import re
import sys
from pathlib import Path

frontend = Path(__file__).resolve().parent.parent / "frontend"
manifest = frontend / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
api_url = sys.argv[1] if len(sys.argv) > 1 else ""

if not manifest.exists():
    sys.exit("AndroidManifest.xml not found. Run 'flutter create --platforms=android .' inside frontend first.")

text = original = manifest.read_text(encoding="utf-8")

# 1) Internet permission (release builds do not get it automatically)
if "android.permission.INTERNET" not in text:
    text = text.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)

# 1b) Camera permission for the live Scan Copra screen (the app asks the user at runtime).
#     required="false" keeps the app installable on devices without a camera: Upload Photo still works.
if "android.permission.CAMERA" not in text:
    text = text.replace(
        "<application",
        '<uses-permission android:name="android.permission.CAMERA"/>\n'
        '    <uses-feature android:name="android.hardware.camera" android:required="false"/>\n'
        "    <application",
        1,
    )

# 2) Plain http:// needs cleartext traffic. Not needed when the URL is https://
if api_url.startswith("http://") and "usesCleartextTraffic" not in text:
    text = text.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)

# 3) Name shown under the app icon
text = re.sub(r'android:label="[^"]*"', 'android:label="KopraGrade"', text, count=1)

if text != original:
    manifest.write_text(text, encoding="utf-8")
    print("AndroidManifest.xml updated.")
else:
    print("AndroidManifest.xml already up to date.")

# 3b) Workaround for the camera plugin on Gradle 9: the plugin's Java compile cannot find
#     androidx.concurrent.futures.CallbackToFutureAdapter ("class file ... not found").
#     Giving that one plugin the missing library fixes it. Works in both build.gradle.kts and build.gradle.
#     Safe to remove once camera_android_camerax ships its own fix.
MARKER = "KopraGrade: camera plugin fix"
FIX = f"""

// {MARKER}
subprojects {{
    if (project.name == "camera_android_camerax") {{
        project.pluginManager.withPlugin("com.android.library") {{
            project.dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }}
    }}
}}
"""
root_build = None
for name in ("build.gradle.kts", "build.gradle"):
    candidate = frontend / "android" / name
    if candidate.exists():
        root_build = candidate
        break
if root_build is None:
    print("WARNING: android/build.gradle(.kts) not found, camera build fix not applied.")
else:
    gradle_text = root_build.read_text(encoding="utf-8")
    if MARKER in gradle_text:
        print(f"{root_build.name} already has the camera build fix.")
    else:
        root_build.write_text(gradle_text.rstrip() + FIX, encoding="utf-8")
        print(f"{root_build.name} updated (camera build fix added).")

# 4) The sample test that 'flutter create' adds refers to a class that does not exist here
sample = frontend / "test" / "widget_test.dart"
if sample.exists() and "MyApp" in sample.read_text(encoding="utf-8"):
    sample.unlink()
    print("Removed the auto-generated test/widget_test.dart (it does not match this app).")