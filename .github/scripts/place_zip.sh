#!/usr/bin/env bash
# استفاده:  place_zip.sh <فایل.zip> <ریشه‌ی ریپو> [yes]   (yes = پوشه‌ی .github داخل zip هم کپی شود)
#
# zip رو باز می‌کنه و فایل‌ها رو «سرِ جای درست» می‌ذاره، مهم نیست داخل zip چه ساختاری باشه:
#   • کل پروژه (با/بدون پوشه‌ی اصلیِ Flutm-main/...)  → روی ریشه‌ی ریپو
#   • فقط چند فایل داخل lib/…                         → همون مسیر lib/ در ریپو
#   • هر چیز دیگه                                      → کنار خود zip (روش قبلی)
# و پوشه‌های اضافیِ کنار lib (map/ screens/ state/ … و main.dart) که قبلاً اشتباه ساخته شدن پاک میشن.
set -euo pipefail

z="$1"; root="$(cd "$2" && pwd)"; allow_wf="${3:-no}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

unzip -q -o "$z" -d "$tmp"
rm -rf "$tmp/__MACOSX"
find "$tmp" -name .DS_Store -delete
[ "$allow_wf" = "yes" ] || find "$tmp" -type d -name .github -prune -exec rm -rf {} +

# نزدیک‌ترین pubspec.yaml (ریشه‌ی پروژه) تا عمق ۳؛ اگه نبود نزدیک‌ترین پوشه‌ی lib
shortest() { sort -n | head -1 | cut -d' ' -f2-; }
src=""
p="$(find "$tmp" -maxdepth 3 -type f -name pubspec.yaml -printf '%d %p\n' | shortest || true)"
if [ -n "$p" ]; then
  src="$(dirname "$p")"
else
  l="$(find "$tmp" -maxdepth 3 -type d -name lib -printf '%d %p\n' | shortest || true)"
  [ -n "$l" ] && src="$(dirname "$l")"
fi

if [ -n "$src" ]; then
  dest="$root"
  echo "   پروژه/lib پیدا شد (${src#$tmp/}) → ریشه‌ی ریپو"
else
  # روش قبلی: اگه همه‌چیز داخل یک پوشه‌ی اصلی بود همون برداشته میشه
  dest="$root/$(dirname "$z")"
  shopt -s nullglob dotglob
  entries=( "$tmp"/* )
  if [ ${#entries[@]} -eq 1 ] && [ -d "${entries[0]}" ]; then src="${entries[0]}"; else src="$tmp"; fi
  echo "   ساختار پروژه پیدا نشد → کنار خود zip"
fi

mkdir -p "$dest"
cp -a "$src"/. "$dest"/

# پاک‌کردن کپی‌های اضافیِ کنار lib (فقط اگه اسمشون عیناً اسم یکی از آیتم‌های lib باشه)
if [ -d "$root/lib" ]; then
  keep=" lib web assets test android ios windows linux macos build .github .git "
  for e in "$root"/lib/*; do
    n="$(basename "$e")"
    case "$keep" in *" $n "*) continue ;; esac
    if [ -e "$root/$n" ]; then echo "   حذف کپی اضافی: $n"; rm -rf "$root/$n"; fi
  done
fi
