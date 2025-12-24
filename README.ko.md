# Skyloft WP

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/macOS-13.0+-brightgreen?style=flat-square" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-lightgrey?style=flat-square" alt="License">
</p>

<p align="center">
  <b>모든 스트리밍 영상을 macOS 데스크탑 배경화면으로</b>
</p>

<p align="center">
  <a href="README.md">English</a> | <b>한국어</b> | <a href="README.ja.md">日本語</a>
</p>

웹사이트의 스트리밍 영상을 데스크탑 배경화면으로 표시하는 macOS 앱입니다. 사진 라이브러리에서 영상을 가져오거나 사용자 지정 스트리밍 소스를 추가할 수 있습니다.

---

## ✨ 주요 기능

### 🎬 스트리밍 연결
- **사용자 지정 비디오 소스** - 원하는 스트리밍 URL 추가
- **두 가지 수집 방식**:
  - **스트리밍 모드** - 자동 재생 사이트용 이벤트 기반 감지
  - **폴링 모드** - 정적 페이지용 주기적 스캔
- **버퍼 모드 (기본값)** - 저장 없이 직접 재생
- **선택적 자동 저장** - 원하면 라이브러리에 저장
- **네트워크 상태 모니터링** - 연결 끊김 시 자동 재연결

### 📚 라이브러리 관리
- **사진 앱에서 가져오기** - Mac 사진 라이브러리의 영상 추가
- **로컬 파일 가져오기** - 드래그 앤 드롭 또는 파일 선택
- **SQLite 데이터베이스** - 영상 메타데이터 영구 저장
- **자동 썸네일 생성** - 자동으로 썸네일 추출
- **즐겨찾기 및 재생 횟수 추적**
- **영상 숨김** - 원치 않는 영상 제외
- **스마트 정리** - 한도 초과 시 오래된 영상 자동 삭제

### 🖥️ 배경화면 재생
- **데스크탑 레벨 윈도우** - 아이콘 아래에 표시되는 진정한 배경화면
- **다중 모니터 지원** - 각 모니터에서 독립적인 영상 재생
- **연속 재생** - 라이브러리에서 순차/반복 재생
- **오버레이 설정** - 투명도, 밝기, 채도, 블러 조절

### 🌏 다국어 지원
- English (en)
- 한국어 (ko)
- 日本語 (ja)

---

## 📖 사용 가이드

### 1️⃣ 라이브러리

그리드 레이아웃으로 영상 컬렉션을 관리합니다.

- **영상 추가**: "Add Videos" 클릭하여 로컬 파일 가져오기
- **사진 라이브러리**: Mac 사진 앱에서 직접 영상 가져오기
- **드래그 앤 드롭**: 영상 파일을 라이브러리에 직접 드래그
- **썸네일 미리보기**: 각 영상의 대표 이미지 표시
- **영상 재생**: 클릭하여 배경화면으로 설정
- **우클릭 메뉴**: 배경화면 설정, Finder에서 보기, 숨김, 삭제

---

### 2️⃣ 스트리밍 설정

사용자 지정 비디오 소스 및 자동 저장 설정을 구성합니다.

| 옵션 | 설명 |
|------|------|
| **연결 상태** | 스트리밍 연결 상태 (연결됨/연결 안 됨) |
| **비디오 소스** | 사용자 지정 스트리밍 URL 추가 |
| **수집 방식** | 스트리밍 (이벤트 기반) 또는 폴링 (주기적) |
| **라이브러리에 저장** | 활성화 시 새 영상 자동 저장 (**기본 OFF**) |
| **최대 영상 수** | 라이브러리에 유지할 최대 영상 수 |

**새 소스 추가 방법:**
1. "Add Video Source" 클릭
2. 웹사이트 URL 입력
3. "Fetch" 클릭하여 페이지 제목 자동 감지
4. 수집 방식 선택:
   - **Streaming**: 자동 재생 영상 사이트용
   - **Polling**: 여러 영상 링크가 있는 페이지용
5. "Add Source" 클릭

> ⚠️ **면책 조항**: 각 웹사이트의 서비스 약관 준수는 전적으로 사용자의 책임입니다.

---

### 3️⃣ 디스플레이 설정

배경화면의 시각적 효과를 조절합니다.

**프리셋**: Default, Subtle, Dim, Ambient, Focus, Vivid, Cinema, Neon, Dreamy, Night, Warm, Retro, Cool, Soft

**수동 조정**
- **투명도**: 배경화면 불투명도 (0~100%)
- **밝기**: 밝기 조절 (-100% ~ +100%)
- **채도**: 색상 채도 (0~200%)
- **블러**: 블러 효과 (0~50)

---

### 4️⃣ 일반 설정

| 옵션 | 설명 |
|------|------|
| **언어** | 앱 언어 선택 |
| **음소거** | 영상 오디오 음소거 |
| **로그인 시 실행** | 로그인 시 자동 시작 |

---

## 📋 요구 사항

- **macOS 13.0 (Ventura)** 이상
- **Xcode 15.0** 이상 (빌드 시)

---

## 🚀 빌드

### Xcode에서 빌드

1. `SkyloftWP.xcodeproj`를 Xcode에서 엽니다
2. `SkyloftWP` 스킴 선택
3. Product > Build (⌘B)

### 명령줄에서 빌드

```bash
xcodebuild -project SkyloftWP.xcodeproj \
           -scheme SkyloftWP \
           -configuration Release \
           -derivedDataPath build
```

### DMG 배포판 생성

```bash
./build-dmg.sh
```

---

## 📁 데이터 저장 위치

```
~/Library/Application Support/SkyloftWP/
├── config.json          # 앱 설정
├── library.sqlite       # 영상 메타데이터 DB
├── videos/              # 다운로드된 영상 파일
├── thumbnails/          # 썸네일 이미지
└── Buffer/              # 버퍼 모드 임시 파일
```

---

## ⚠️ 면책 조항

### 사용자 책임

- 추가하는 비디오 소스는 **전적으로 사용자의 책임**입니다
- 각 웹사이트의 **서비스 약관을 준수**하세요
- 일부 사이트는 **자동화된 접근이나 스크래핑을 금지**할 수 있습니다
- 이 앱은 **제3자 콘텐츠를 보증하거나 검증하지 않습니다**

### 개인정보 보호

이 애플리케이션은:
- **어떤 개인 데이터도 수집하지 않습니다**
- **외부 서버로 데이터를 전송하지 않습니다**
- **모든 데이터를 사용자 기기에만 로컬로 저장합니다**
- **분석이나 추적을 포함하지 않습니다**

### 보증 면책

이 소프트웨어는 어떠한 종류의 보증 없이 **"있는 그대로"** 제공됩니다.

---

## 📝 라이선스

**CC BY-NC-SA 4.0** (Creative Commons Attribution-NonCommercial-ShareAlike 4.0)

| 조건 | 설명 |
|------|------|
| **저작자 표시 (BY)** | 적절한 출처 표시 |
| **비영리 (NC)** | 상업적 사용 불가 |
| **동일 조건 변경 허락 (SA)** | 파생 저작물도 동일 라이선스 |

---

## 👨‍💻 개발자

**Mastergear (김근진)**  
🔗 [Facebook](https://www.facebook.com/keunjinkim00)

### ☕ 후원

이 앱이 마음에 드셨다면 커피 한 잔 사주세요!

<a href="https://www.buymeacoffee.com/keunjin.kim"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=keunjin.kim&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" /></a>
