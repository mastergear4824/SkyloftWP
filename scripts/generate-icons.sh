#!/bin/bash
# macOS 앱 아이콘 생성 스크립트
# 
# 사용법:
#   ./scripts/generate-icons.sh path/to/icon_1024x1024.png
#
# 1024×1024 PNG 이미지를 입력하면 모든 필요한 크기의 아이콘을 생성합니다.
# 생성된 아이콘은 AIStreamWallpaper/Resources/Assets.xcassets/AppIcon.appiconset/ 에 저장됩니다.

set -e

# 입력 검증
if [ -z "$1" ]; then
    echo "❌ 사용법: $0 <1024x1024 PNG 파일>"
    echo ""
    echo "예시:"
    echo "  $0 ~/Desktop/my_icon.png"
    exit 1
fi

INPUT="$1"

if [ ! -f "$INPUT" ]; then
    echo "❌ 파일을 찾을 수 없습니다: $INPUT"
    exit 1
fi

# 스크립트 위치 기준으로 프로젝트 루트 찾기
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 출력 디렉토리
ASSETS_DIR="$PROJECT_ROOT/AIStreamWallpaper/Resources/Assets.xcassets"
OUTPUT_DIR="$ASSETS_DIR/AppIcon.appiconset"

# 디렉토리 생성
mkdir -p "$OUTPUT_DIR"

echo "🎨 macOS 앱 아이콘 생성 중..."
echo "   입력: $INPUT"
echo "   출력: $OUTPUT_DIR"
echo ""

# 각 크기별 아이콘 생성
sips -z 16 16     "$INPUT" --out "$OUTPUT_DIR/icon_16x16.png" > /dev/null
sips -z 32 32     "$INPUT" --out "$OUTPUT_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$INPUT" --out "$OUTPUT_DIR/icon_32x32.png" > /dev/null
sips -z 64 64     "$INPUT" --out "$OUTPUT_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$INPUT" --out "$OUTPUT_DIR/icon_128x128.png" > /dev/null
sips -z 256 256   "$INPUT" --out "$OUTPUT_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$INPUT" --out "$OUTPUT_DIR/icon_256x256.png" > /dev/null
sips -z 512 512   "$INPUT" --out "$OUTPUT_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$INPUT" --out "$OUTPUT_DIR/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$INPUT" --out "$OUTPUT_DIR/icon_512x512@2x.png" > /dev/null

echo "   ✓ icon_16x16.png (16×16)"
echo "   ✓ icon_16x16@2x.png (32×32)"
echo "   ✓ icon_32x32.png (32×32)"
echo "   ✓ icon_32x32@2x.png (64×64)"
echo "   ✓ icon_128x128.png (128×128)"
echo "   ✓ icon_128x128@2x.png (256×256)"
echo "   ✓ icon_256x256.png (256×256)"
echo "   ✓ icon_256x256@2x.png (512×512)"
echo "   ✓ icon_512x512.png (512×512)"
echo "   ✓ icon_512x512@2x.png (1024×1024)"

# Contents.json 생성
cat > "$OUTPUT_DIR/Contents.json" << 'CONTENTS_JSON'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
CONTENTS_JSON

echo ""
echo "✅ 아이콘 생성 완료!"
echo ""
echo "📋 다음 단계:"
echo "   1. Xcode에서 프로젝트 열기"
echo "   2. AIStreamWallpaper/Resources/Assets.xcassets 폴더를 프로젝트에 드래그"
echo "   3. Target → Build Settings → Asset Catalog Compiler → App Icon → AppIcon 확인"
echo "   4. 빌드 (⌘B)"

