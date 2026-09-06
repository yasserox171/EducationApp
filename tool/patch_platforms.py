#!/usr/bin/env python3
"""تطبيق التعديلات التي يحتاجها التطبيق على ملفات المنصّات المولَّدة.

يُستدعى من tool/bootstrap.sh بعد `flutter create`، وهو idempotent:
تشغيله مرّتين لا يكرّر أي تعديل.

التعديلات:
  • Android: صلاحية INTERNET، ورفع minSdk إلى 23
    (يطلبها flutter_secure_storage مع encryptedSharedPreferences).
  • iOS: وصف استعمال مكتبة الصور (اختيار الفيديو من طرف الأستاذ)،
    ورفع الحد الأدنى للنسخة إلى 12.0.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIN_SDK = 23
IOS_MIN_VERSION = "12.0"


def info(message: str) -> None:
    print(f"  · {message}")


def warn(message: str) -> None:
    print(f"  ! {message}", file=sys.stderr)


def patch_android_manifest() -> None:
    path = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not path.exists():
        warn(f"غير موجود: {path.relative_to(ROOT)}")
        return

    content = path.read_text(encoding="utf-8")
    permission = '<uses-permission android:name="android.permission.INTERNET"/>'

    if "android.permission.INTERNET" in content:
        info("AndroidManifest: صلاحية الإنترنت موجودة مسبقًا")
        return

    updated, count = re.subn(
        r"(\n\s*)<application",
        rf"\n    {permission}\1<application",
        content,
        count=1,
    )
    if count == 0:
        warn("AndroidManifest: لم يُعثر على وسم <application> — أضف الصلاحية يدويًا")
        return

    path.write_text(updated, encoding="utf-8")
    info("AndroidManifest: أُضيفت صلاحية الإنترنت")


def patch_android_min_sdk() -> None:
    candidates = [
        ROOT / "android/app/build.gradle.kts",
        ROOT / "android/app/build.gradle",
    ]
    path = next((p for p in candidates if p.exists()), None)
    if path is None:
        warn("لم يُعثر على android/app/build.gradle[.kts]")
        return

    content = path.read_text(encoding="utf-8")
    if re.search(rf"minSdk(Version)?\s*=?\s*{MIN_SDK}\b", content):
        info(f"build.gradle: minSdk = {MIN_SDK} مضبوط مسبقًا")
        return

    updated, count = re.subn(
        r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion",
        lambda m: f"minSdk{m.group(1) or ''} = {MIN_SDK}"
        if path.suffix == ".kts"
        else f"minSdk{m.group(1) or ''} {MIN_SDK}",
        content,
        count=1,
    )
    if count == 0:
        warn(f"build.gradle: اضبط minSdk على {MIN_SDK} يدويًا")
        return

    path.write_text(updated, encoding="utf-8")
    info(f"build.gradle: minSdk = {MIN_SDK}")


def patch_ios_plist() -> None:
    path = ROOT / "ios/Runner/Info.plist"
    if not path.exists():
        warn(f"غير موجود: {path.relative_to(ROOT)}")
        return

    content = path.read_text(encoding="utf-8")
    entries = {
        "NSPhotoLibraryUsageDescription": "يحتاج التطبيق الوصول إلى مكتبة الوسائط لاختيار فيديو الدرس.",
        "NSDocumentsFolderUsageDescription": "يحتاج التطبيق الوصول إلى الملفات لاختيار فيديو الدرس.",
    }

    added = []
    for key, value in entries.items():
        if f"<key>{key}</key>" in content:
            continue
        content = content.replace(
            "</dict>\n</plist>",
            f"\t<key>{key}</key>\n\t<string>{value}</string>\n</dict>\n</plist>",
            1,
        )
        added.append(key)

    if not added:
        info("Info.plist: الأذونات موجودة مسبقًا")
        return

    path.write_text(content, encoding="utf-8")
    info(f"Info.plist: أُضيف {', '.join(added)}")


def patch_ios_podfile() -> None:
    path = ROOT / "ios/Podfile"
    if not path.exists():
        info("Podfile غير موجود بعد (يُولَّد عند أول بناء لـ iOS)")
        return

    content = path.read_text(encoding="utf-8")
    if f"platform :ios, '{IOS_MIN_VERSION}'" in content:
        info(f"Podfile: iOS {IOS_MIN_VERSION} مضبوط مسبقًا")
        return

    updated, count = re.subn(
        r"#?\s*platform :ios, '[\d.]+'",
        f"platform :ios, '{IOS_MIN_VERSION}'",
        content,
        count=1,
    )
    if count == 0:
        warn(f"Podfile: اضبط platform :ios على {IOS_MIN_VERSION} يدويًا")
        return

    path.write_text(updated, encoding="utf-8")
    info(f"Podfile: platform :ios, '{IOS_MIN_VERSION}'")


def main() -> int:
    print("▸ تطبيق تعديلات المنصّات:")
    patch_android_manifest()
    patch_android_min_sdk()
    patch_ios_plist()
    patch_ios_podfile()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
