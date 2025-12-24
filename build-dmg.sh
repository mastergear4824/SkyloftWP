#!/bin/bash

# Skyloft WP - DMG 빌드 스크립트
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="SkyloftWP"
VOLUME_NAME="Skyloft WP"

BG_WIDTH=540
BG_HEIGHT=360
ICON_SIZE=100
APP_X=135
APPS_X=405
ICON_Y=160

echo "🔨 Building $APP_NAME..."

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DIST_DIR/DerivedData" \
  BUILD_DIR="$DIST_DIR/Build" \
  clean build

APP_PATH="$DIST_DIR/Build/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found"
    exit 1
fi

# 스크린세이버 빌드 및 앱 번들에 복사
echo "📺 Building Screen Saver..."
"$PROJECT_DIR/scripts/build-screensaver.sh"

mkdir -p "$APP_PATH/Contents/Resources/ScreenSaver"
cp -R "$PROJECT_DIR/build/ScreenSaver/SkyloftWPSaver.saver" "$APP_PATH/Contents/Resources/ScreenSaver/"
echo "✅ Screen Saver included in app bundle"

echo "🎨 Creating DMG..."

DMG_TEMP="$DIST_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP/.background"

# 배경 이미지 생성 (➤➤ 스타일 화살표)
python3 << PYTHON_SCRIPT
import struct
import zlib

width, height = $BG_WIDTH, $BG_HEIGHT

def png_chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)

sig = b"\x89PNG\r\n\x1a\n"
ihdr = png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))

raw = b""
cx, cy = width // 2, height // 2

def in_triangle(px, py, tip_x, tip_y, size):
    """채워진 삼각형 ➤ 체크 (오른쪽을 가리킴)"""
    # 삼각형: 꼭짓점(tip_x, tip_y), 왼쪽 위(tip_x-size, tip_y-size/2), 왼쪽 아래(tip_x-size, tip_y+size/2)
    # 점이 삼각형 안에 있는지 확인
    left_x = tip_x - size
    top_y = tip_y - size * 0.6
    bottom_y = tip_y + size * 0.6
    
    if px < left_x or px > tip_x:
        return False
    
    # x 위치에 따른 y 범위 계산
    progress = (px - left_x) / size  # 0 ~ 1
    allowed_half_height = (1 - progress) * size * 0.6
    
    return abs(py - tip_y) <= allowed_half_height

for y in range(height):
    raw += b"\x00"
    for x in range(width):
        # 청록 그라데이션
        t = (x/width * 0.3 + y/height * 0.7)
        r = int(170 - 90*t)
        g = int(210 - 55*t)
        b = int(205 - 40*t)
        
        # ➤➤ 이중 삼각형 화살표
        arrow_alpha = 0
        arrow_size = 16
        gap = 20  # 두 화살표 간격
        
        # 첫 번째 ➤
        if in_triangle(x, y, cx - gap//2, cy, arrow_size):
            arrow_alpha = 210
        
        # 두 번째 ➤
        if in_triangle(x, y, cx + gap//2 + arrow_size, cy, arrow_size):
            arrow_alpha = 210
        
        if arrow_alpha > 0:
            bl = arrow_alpha / 255 * 0.85
            r = int(r*(1-bl) + 255*bl)
            g = int(g*(1-bl) + 255*bl)
            b = int(b*(1-bl) + 255*bl)
        
        raw += bytes([max(0,min(255,r)), max(0,min(255,g)), max(0,min(255,b)), 255])

idat = png_chunk(b"IDAT", zlib.compress(raw, 9))
iend = png_chunk(b"IEND", b"")

with open("$DMG_TEMP/.background/bg.png", "wb") as f:
    f.write(sig + ihdr + idat + iend)
print("   ✓ Background with ➤➤ arrows created")
PYTHON_SCRIPT

cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

DMG_RW="$DIST_DIR/rw.dmg"
DMG_FINAL="$DIST_DIR/SkyloftWP.dmg"
rm -f "$DMG_RW" "$DMG_FINAL"

hdiutil create -volname "$VOLUME_NAME" -srcfolder "$DMG_TEMP" -ov -format UDRW -size 25m "$DMG_RW"

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" | awk '/APFS|HFS/ {print $1; exit}')
sleep 2

echo "   Applying style..."

# 마운트된 볼륨 경로
VOL_PATH="/Volumes/$VOLUME_NAME"

# AppleScript로 Finder 설정 적용 (여러 번 반복하여 확실하게)
for i in 1 2; do
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        delay 2
        
        set theWindow to container window
        tell theWindow
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set bounds to {100, 100, $((100 + BG_WIDTH)), $((100 + BG_HEIGHT + 22))}
        end tell
        
        set opts to icon view options of theWindow
        set icon size of opts to $ICON_SIZE
        set text size of opts to 12
        set arrangement of opts to not arranged
        set background picture of opts to file ".background:bg.png"
        
        set position of item "$APP_NAME.app" to {$APP_X, $ICON_Y}
        set position of item "Applications" to {$APPS_X, $ICON_Y}
        
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF
sleep 2
done

# 사이드바 숨김을 위한 추가 처리 - .DS_Store에 직접 설정
# (Finder 기본 설정에 의존하지 않고 DMG 자체 설정)
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        delay 1
        tell container window
            set toolbar visible to false
            set statusbar visible to false
        end tell
        delay 1
        close
    end tell
end tell
EOF
sleep 1

# .DS_Store 강제 플러시
sync
sleep 1

# .background 폴더 숨김 처리
if [ -d "$VOL_PATH/.background" ]; then
    SetFile -a V "$VOL_PATH/.background" 2>/dev/null || true
fi

# Finder 캐시 플러시
osascript -e 'tell application "Finder" to update disk "'"$VOLUME_NAME"'"'
sleep 2
sync
sleep 2

hdiutil detach "$DEVICE" -force
sleep 2

hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$DMG_RW"
rm -rf "$DMG_TEMP"

# 배포 디렉토리로 복사
DIST_OUTPUT_DIR="/Users/mastergear/toy/midtv-fan-bg/SkyloftWP-dist"
mkdir -p "$DIST_OUTPUT_DIR"
cp "$DMG_FINAL" "$DIST_OUTPUT_DIR/"

echo ""
echo "✅ Done: $DMG_FINAL ($(ls -lh "$DMG_FINAL" | awk '{print $5}'))"
echo "📦 Copied to: $DIST_OUTPUT_DIR/SkyloftWP.dmg"
