# AI Stream Wallpaper

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/macOS-13.0+-brightgreen?style=flat-square" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-lightgrey?style=flat-square" alt="License">
</p>

<p align="center">
  <b>AI 생성 영상을 macOS 데스크탑 배경화면으로</b>
</p>

<p align="center">
  <i>🎨 Midjourney 팬이 만든 비공식 애플리케이션</i>
</p>

<p align="center">
  <a href="README.md">English</a> | <b>한국어</b> | <a href="README.ja.md">日本語</a>
</p>

Midjourney TV의 실시간 AI 생성 영상을 배경화면으로 표시하고, 로컬 라이브러리에 자동 저장하여 오프라인에서도 감상할 수 있는 macOS 앱입니다.

> 💡 **참고**: 이 앱은 Midjourney TV를 위해 설계되었지만, **다른 스트리밍 비디오 서비스**에도 연결하여 Mac의 동적 배경화면으로 사용할 수 있습니다.

> ⚠️ **면책 조항**: 이 앱은 비공식 팬 제작 애플리케이션이며, Midjourney, Inc.와 어떤 방식으로도 제휴, 승인, 연결되어 있지 않습니다. 자세한 내용은 [면책 조항](#️-면책-조항) 섹션을 참조하세요.

---

## ✨ 주요 기능

### 🎬 스트리밍 연결
- **백그라운드 Midjourney TV 연결** - WebView를 통한 실시간 영상 스트리밍
- **커스텀 비디오 소스** - Midjourney TV 외의 스트리밍 URL 추가 가능
- **버퍼 모드 (기본값)** - ToS 준수를 위해 저장 없이 직접 재생
- **선택적 자동 저장** - 사용자가 원할 경우 라이브러리에 저장 가능
- **네트워크 상태 모니터링** - 연결 끊김 시 자동 재연결

### 📚 라이브러리 관리
- **SQLite 데이터베이스** - 영상 메타데이터 영구 저장
- **자동 썸네일 생성** - AVAssetImageGenerator로 썸네일 추출
- **즐겨찾기 및 재생 횟수 추적**
- **영상 숨김 (싫어요)** - 원치 않는 영상 순환에서 제외
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

<p align="center">
  <img src="capture/Library.png" width="700" alt="Library">
</p>

저장된 AI 생성 영상을 그리드 레이아웃으로 관리합니다.

- **썸네일 미리보기**: 각 영상의 대표 이미지 표시
- **영상 재생**: 클릭하여 배경화면으로 설정
- **우클릭 메뉴**: 
  - 배경화면으로 설정
  - 프롬프트 복사
  - Midjourney에서 열기
  - Finder에서 보기
  - 숨김 / 삭제

---

### 2️⃣ 스트리밍 설정

<p align="center">
  <img src="capture/Streaming.png" width="700" alt="Streaming">
</p>

Midjourney TV 연결 및 자동 저장 설정을 구성합니다.

| 옵션 | 설명 |
|------|------|
| **연결 상태** | 스트리밍 연결 상태 (연결됨/연결 안 됨) |
| **비디오 소스** | Midjourney TV (기본) 또는 커스텀 URL 추가 |
| **라이브러리에 저장** | 활성화 시 새 영상을 자동으로 라이브러리에 저장 (**기본 OFF**) |
| **최대 영상 수** | 라이브러리에 유지할 최대 영상 수 (초과 시 오래된 영상 자동 삭제) |

> 🛡️ **기본값: 버퍼 모드** - 서비스 약관 준수를 위해 자동 저장이 기본적으로 비활성화되어 있습니다. 영상은 저장 없이 직접 재생됩니다. 사용자가 원할 경우 저장을 활성화할 수 있습니다.

> 💡 **팁**: 스트리밍이 연결되면 앱이 백그라운드에서 비디오 소스를 모니터링하고 새 영상이 나타나면 자동으로 다운로드합니다.

> 🔗 **커스텀 소스**: 연속 비디오 콘텐츠를 제공하는 모든 스트리밍 비디오 서비스 URL을 추가할 수 있습니다. 이로 인해 Midjourney TV 외에도 다양한 비디오 배경화면 소스에 앱을 활용할 수 있습니다.

---

### 3️⃣ 디스플레이 설정

<p align="center">
  <img src="capture/Display.png" width="700" alt="Display">
</p>

배경화면의 시각적 효과를 조절합니다.

**프리셋**
| 프리셋 | 효과 |
|--------|------|
| Default | 원본 그대로 |
| Subtle | 약간 어둡게 |
| Dim | 어둡게 |
| Ambient | 분위기 있게 |
| Focus | 집중 모드 (블러 추가) |
| Vivid | 색상 강화 |
| Cinema | 시네마틱 |
| Neon | 네온 효과 |
| Dreamy | 몽환적 |
| Night | 야간 모드 |
| Warm | 따뜻한 톤 |
| Retro | 레트로 스타일 |
| Cool | 시원한 톤 |
| Soft | 부드럽게 |

**수동 조정**
- **투명도**: 배경화면 불투명도 (0~100%)
- **밝기**: 밝기 조절 (-100% ~ +100%)
- **채도**: 색상 채도 (0~200%)
- **블러**: 블러 효과 (0~50)

---

### 4️⃣ 일반 설정

<p align="center">
  <img src="capture/General.png" width="700" alt="General">
</p>

기본 앱 동작을 설정합니다.

| 옵션 | 설명 |
|------|------|
| **언어** | 앱 언어 선택 (English, 한국어, 日本語) |
| **음소거** | 영상 오디오 음소거 |
| **로그인 시 실행** | 로그인 시 자동 시작 |

---

### 5️⃣ 정보

<p align="center">
  <img src="capture/About.png" width="700" alt="About">
</p>

앱 정보 확인 및 라이브러리 관리.

- **개발자**: Mastergear (김근진)
- **연락처**: mastergear@aiclude.com
- **라이브러리 크기**: 영상 수, 사용된 저장 공간, 숨겨진 영상 수
- **관리**: 
  - 숨겨진 영상 복원
  - 전체 라이브러리 삭제

---

## 📋 요구 사항

- **macOS 13.0 (Ventura)** 이상
- **Xcode 15.0** 이상 (빌드 시)

---

## 🚀 빌드

### Xcode에서 빌드

1. `AIStreamWallpaper.xcodeproj`를 Xcode에서 엽니다
2. `AIStreamWallpaper` 스킴 선택
3. Product > Build (⌘B)

### 명령줄에서 빌드

```bash
xcodebuild -project AIStreamWallpaper.xcodeproj \
           -scheme AIStreamWallpaper \
           -configuration Release \
           -derivedDataPath build
```

빌드된 앱 위치: `build/Build/Products/Release/AIStreamWallpaper.app`

### DMG 배포판 생성

```bash
./build-dmg.sh
```

출력: `dist/AIStreamWallpaper.dmg`

---

## 📁 데이터 저장 위치

```
~/Library/Application Support/AIStreamWallpaper/
├── config.json          # 앱 설정
├── library.sqlite       # 영상 메타데이터 DB
├── videos/              # 다운로드된 영상 파일
│   └── {uuid}.mp4
├── thumbnails/          # 썸네일 이미지
│   └── {uuid}.jpg
└── Buffer/              # 버퍼 모드 임시 파일
```

---

## 🚀 자동 시작 설정

로그인 시 실행은 LaunchAgent를 통해 구현됩니다:

```
~/Library/LaunchAgents/com.aistreamwallpaper.plist
```

메뉴바 또는 설정에서 "로그인 시 실행"을 활성화하면 이 파일이 자동 생성됩니다.

---

## ⚠️ 면책 조항

### 팬 제작 애플리케이션

이 애플리케이션은 Midjourney의 놀라운 AI 생성 콘텐츠에 대한 감사의 마음으로 **Midjourney 사용자이자 팬**이 제작했습니다. Midjourney TV 영상을 데스크탑 배경화면으로 즐길 수 있도록 사용자 경험을 향상시키기 위해 설계되었습니다.

### 다목적 비디오 배경화면 도구

원래 Midjourney TV를 염두에 두고 설계되었지만, 이 애플리케이션은 macOS용 **범용 스트리밍 비디오 배경화면 도구**로 기능합니다. 사용자는 **호환되는 모든 스트리밍 비디오 서비스**에 연결하여 데스크탑 배경화면으로 사용할 수 있어, Midjourney TV와 독립적으로도 유용합니다.

### 해를 끼칠 의도 없음

이 애플리케이션은 다음을 **의도하지 않습니다**:
- Midjourney, Inc. 또는 그 서비스에 해를 끼치거나 손상을 입히는 것
- Midjourney의 지적 재산권을 침해하는 것
- 접근 제어나 서비스 약관을 우회하는 것
- Midjourney의 사업과 경쟁하거나 약화시키는 것

### Midjourney 정책 준수

개발자는 다음을 약속합니다:

1. **중단 요청**: Midjourney, Inc.가 이 애플리케이션의 중단을 요청하면 지체 없이 **즉시 배포를 중단**합니다.

2. **서비스 종료**: Midjourney TV 서비스가 중단되거나 크게 변경되면 이 애플리케이션의 배포도 즉시 중단됩니다.

3. **선의**: 이 애플리케이션은 Midjourney 애호가들의 개인적, 비상업적 사용을 위해 선의로 배포됩니다.

### 제휴 관계 없음

- 이것은 **비공식**, **팬 제작** 애플리케이션입니다
- Midjourney, Inc.와 **제휴, 승인, 연결되어 있지 않습니다**
- 모든 Midjourney 상표 및 콘텐츠는 해당 소유자에게 귀속됩니다
- "Midjourney"와 "Midjourney TV"는 Midjourney, Inc.의 상표입니다

### 다운로드 콘텐츠의 저작권

- Midjourney TV에서 다운로드한 모든 영상은 **원작자에게 저작권이 있습니다**
- 다운로드된 영상은 **개인적, 비상업적 용도로만** 사용해야 합니다
- 사용자는 다운로드된 콘텐츠를 **재배포, 판매, 상업적으로 이용해서는 안 됩니다**
- AI 생성 콘텐츠의 저작권은 Midjourney 서비스 약관에 따라 Midjourney 및/또는 사용자에게 귀속됩니다

### 사용자 책임

이 애플리케이션 사용자는 다음에 대해 책임이 있습니다:

1. **서비스 약관 준수**: 사용자는 Midjourney TV의 서비스 약관 및 연결하는 다른 스트리밍 서비스의 약관을 준수해야 합니다
2. **합법적 사용**: 사용자는 자신의 관할권에서 적용되는 법률을 준수하여 이 애플리케이션을 사용해야 합니다
3. **제3자 서비스**: Midjourney TV 이외의 서비스에 연결할 때 해당 서비스 약관 준수는 전적으로 사용자의 책임입니다
4. **콘텐츠 사용**: 사용자는 이 애플리케이션을 통해 얻은 콘텐츠의 사용 방법에 대해 책임이 있습니다

### Midjourney ToS 관련 중요 공지

[Midjourney 서비스 약관](https://docs.midjourney.com/hc/en-us/articles/32083055291277-Terms-of-Service)에 따르면 다음 제한이 적용됩니다:

> "서비스를 통해 자산에 접근, 상호작용 또는 생성하기 위해 **자동화 도구를 사용할 수 없습니다**."

**이 애플리케이션은 ToS 우려 사항을 다음과 같이 해결합니다:**
- ✅ **버퍼 모드가 기본으로 활성화됨** - 영상이 저장 없이 직접 재생됩니다
- ✅ **자동 저장이 기본으로 비활성화됨** - 사용자가 영상 저장을 명시적으로 선택해야 합니다
- ✅ 체계적인 데이터 수집이 아닌 **개인적인 시청 즐거움**을 위해 설계됨

**사용자는 다음을 인지해야 합니다:**
- 자동 저장을 활성화하면 사용자 자신의 재량과 위험 부담으로 하는 것입니다
- 이 애플리케이션은 공개적으로 이용 가능한 콘텐츠의 **개인적인 즐거움**을 위해 의도되었습니다

### 개인정보 보호

이 애플리케이션은:
- **어떤 개인 데이터도 수집하지 않습니다**
- **외부 서버로 데이터를 전송하지 않습니다** (사용자 지정 스트리밍 소스 연결 제외)
- **모든 데이터를 사용자 기기에만 로컬로 저장합니다**
- **분석이나 추적을 포함하지 않습니다**

### 보증 면책

이 소프트웨어는 상품성, 특정 목적에의 적합성 및 비침해에 대한 보증을 포함하되 이에 국한되지 않는 어떠한 종류의 명시적이거나 묵시적인 보증 없이 **"있는 그대로"** 제공됩니다.

어떠한 경우에도 저작자나 저작권 보유자는 계약, 불법 행위 또는 기타 행위로 인해 발생하는 소프트웨어 또는 소프트웨어 사용이나 기타 거래와 관련하여 발생하는 모든 청구, 손해 또는 기타 책임에 대해 책임지지 않습니다.

### 연락처

이 애플리케이션에 대한 문의:
- **개발자**: mastergear@aiclude.com
- **Midjourney**: 문의 사항이 있으시면 개발자에게 연락해 주시면 즉시 적절한 조치를 취하겠습니다.

---

## 📝 라이선스

**CC BY-NC-SA 4.0** (Creative Commons Attribution-NonCommercial-ShareAlike 4.0)

| 조건 | 설명 |
|------|------|
| **저작자 표시 (BY)** | 적절한 출처를 표시하고 변경 사항을 명시해야 합니다 |
| **비영리 (NC)** | 상업적 목적으로 사용할 수 없습니다 |
| **동일 조건 변경 허락 (SA)** | 소스를 수정하면 동일한 라이선스로 배포해야 합니다 |

> 📧 상업적 라이선스 문의: mastergear@aiclude.com

전체 라이선스 텍스트: [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode)

---

## 🙏 크레딧

- [Midjourney TV](https://www.midjourney.tv/) - AI 생성 영상 소스
- SwiftUI & AppKit - macOS 네이티브 UI
- AVFoundation - 비디오 재생 및 처리
- WebKit - 웹 콘텐츠 렌더링

---

## 👨‍💻 개발자

**Mastergear (김근진)**  
📧 mastergear@aiclude.com

