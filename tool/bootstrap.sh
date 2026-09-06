#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# تهيئة المشروع بعد الاستنساخ من المستودع.
#
# مجلدا android/ و ios/ غير مرفوعين إلى المستودع (ملفات مولَّدة بالكامل).
# هذا السكربت يولّدهما بـ `flutter create` ثم يطبّق التعديلات التي يحتاجها
# التطبيق (صلاحية الإنترنت، أذونات iOS، رفع minSdk).
#
#   ./tool/bootstrap.sh
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORG="${ORG:-com.centre.education}"
PROJECT_NAME="education_app"

cd "$PROJECT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "خطأ: Flutter غير مثبَّت أو غير موجود في PATH." >&2
  echo "ثبّته من https://docs.flutter.dev/get-started/install ثم أعد المحاولة." >&2
  exit 1
fi

echo "▸ إصدار Flutter:"
flutter --version | head -1

# 1) ملف الإعدادات المحلي -----------------------------------------------------
if [ ! -f .env ]; then
  cp .env.example .env
  echo "▸ أُنشئ ملف .env من .env.example — ضع فيه قيمة BASE_URL."
else
  echo "▸ ملف .env موجود مسبقًا (لم يُمسّ)."
fi

# 2) توليد مجلدي المنصّات ------------------------------------------------------
NEEDS_ANDROID=0
NEEDS_IOS=0
[ -d android ] || NEEDS_ANDROID=1
[ -d ios ] || NEEDS_IOS=1

if [ "$NEEDS_ANDROID" -eq 1 ] || [ "$NEEDS_IOS" -eq 1 ]; then
  SHELL_DIR="$(mktemp -d)"
  trap 'rm -rf "$SHELL_DIR"' EXIT

  echo "▸ توليد ملفات المنصّات في مجلد مؤقّت…"
  flutter create \
    --org "$ORG" \
    --project-name "$PROJECT_NAME" \
    --platforms=android,ios \
    --no-pub \
    "$SHELL_DIR/shell" >/dev/null

  if [ "$NEEDS_ANDROID" -eq 1 ]; then
    cp -R "$SHELL_DIR/shell/android" ./android
    echo "▸ أُضيف مجلد android/"
  fi
  if [ "$NEEDS_IOS" -eq 1 ]; then
    cp -R "$SHELL_DIR/shell/ios" ./ios
    echo "▸ أُضيف مجلد ios/"
  fi
else
  echo "▸ مجلدا android/ و ios/ موجودان — تخطّي التوليد."
fi

# 3) تعديلات المنصّات المطلوبة ------------------------------------------------
python3 tool/patch_platforms.py

# 4) الحزم --------------------------------------------------------------------
echo "▸ جلب الحزم…"
flutter pub get

echo
echo "تمّت التهيئة. الخطوات التالية:"
echo "  1. ضع BASE_URL في ملف .env"
echo "  2. flutter run"
