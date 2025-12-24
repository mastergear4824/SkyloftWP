# Skyloft WP

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/macOS-13.0+-brightgreen?style=flat-square" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-lightgrey?style=flat-square" alt="License">
</p>

<p align="center">
  <b>Stream any video as your macOS desktop wallpaper</b>
</p>

<p align="center">
  <b>English</b> | <a href="README.ko.md">한국어</a> | <a href="README.ja.md">日本語</a>
</p>

A macOS app that displays streaming videos from any website as your desktop wallpaper. Import videos from your Photos library or add custom streaming sources.

---

## ✨ Features

### 🎬 Streaming Connection
- **Custom Video Sources** - Add any streaming video URL you choose
- **Dual Fetch Modes**:
  - **Streaming Mode** - Event-based detection for auto-playing video sites
  - **Polling Mode** - Periodic scanning for static video pages
- **Buffer Mode (Default)** - Play videos directly without saving
- **Optional Auto-Save** - Save videos to library if desired
- **Network Status Monitoring** - Auto-reconnect when connection drops

### 📚 Library Management
- **Import from Photos** - Add videos from your Mac's Photos library
- **Import Local Files** - Drag & drop or select video files
- **SQLite Database** - Persistent video metadata storage
- **Auto Thumbnail Generation** - Extracts thumbnails automatically
- **Favorites & Play Count Tracking**
- **Hide Videos** - Hide unwanted videos from rotation
- **Smart Cleanup** - Automatically removes oldest videos when limit is exceeded

### 🖥️ Wallpaper Playback
- **Desktop-Level Window** - True wallpaper displayed below desktop icons
- **Multi-Monitor Support** - Independent video playback on each monitor
- **Continuous Playback** - Sequential/loop playback from library
- **Overlay Settings** - Adjust transparency, brightness, saturation, and blur

### 🌏 Localization
- English (en)
- 한국어 (ko)
- 日本語 (ja)

---

## 📖 User Guide

### 1️⃣ Library

Manage your video collection in a grid layout.

- **Add Videos**: Click "Add Videos" to import from local files
- **Photos Library**: Import videos directly from your Mac's Photos app
- **Drag & Drop**: Drag video files directly into the library
- **Thumbnail Preview**: Shows representative image for each video
- **Play Video**: Click to set as wallpaper
- **Right-Click Menu**: Set as wallpaper, Show in Finder, Hide, Delete

---

### 2️⃣ Streaming Settings

Configure custom video sources and auto-save settings.

| Option | Description |
|--------|-------------|
| **Connection Status** | Streaming connection state (Connected/Disconnected) |
| **Video Source** | Add your own streaming URLs |
| **Fetch Mode** | Streaming (event-based) or Polling (periodic) |
| **Save to Library** | When enabled, automatically saves new videos (**OFF by default**) |
| **Maximum Videos** | Max videos to keep in library |

**Adding a New Source:**
1. Click "Add Video Source"
2. Enter the website URL
3. Click "Fetch" to auto-detect the page title
4. Select Fetch Mode:
   - **Streaming**: For sites with auto-playing videos
   - **Polling**: For pages with multiple video links
5. Click "Add Source"

> ⚠️ **Disclaimer**: You are solely responsible for ensuring compliance with each website's Terms of Service.

---

### 3️⃣ Display Settings

Adjust visual effects for your wallpaper.

**Presets**: Default, Subtle, Dim, Ambient, Focus, Vivid, Cinema, Neon, Dreamy, Night, Warm, Retro, Cool, Soft

**Manual Adjustments**
- **Transparency**: Wallpaper opacity (0~100%)
- **Brightness**: Brightness adjustment (-100% ~ +100%)
- **Saturation**: Color saturation (0~200%)
- **Blur**: Blur effect (0~50)

---

### 4️⃣ General Settings

| Option | Description |
|--------|-------------|
| **Language** | App language selection |
| **Mute** | Mute video audio |
| **Launch at Login** | Start automatically when you log in |

---

## 📋 Requirements

- **macOS 13.0 (Ventura)** or later
- **Xcode 15.0** or later (for building)

---

## 🚀 Build

### Build with Xcode

1. Open `SkyloftWP.xcodeproj` in Xcode
2. Select the `SkyloftWP` scheme
3. Product > Build (⌘B)

### Build from Command Line

```bash
xcodebuild -project SkyloftWP.xcodeproj \
           -scheme SkyloftWP \
           -configuration Release \
           -derivedDataPath build
```

### Create DMG Distribution

```bash
./build-dmg.sh
```

---

## 📁 Data Storage Location

```
~/Library/Application Support/SkyloftWP/
├── config.json          # App settings
├── library.sqlite       # Video metadata DB
├── videos/              # Downloaded video files
├── thumbnails/          # Thumbnail images
└── Buffer/              # Buffer mode temp files
```

---

## ⚠️ Disclaimer

### User Responsibility

- **You are solely responsible** for the video sources you add
- **Ensure compliance** with each website's Terms of Service
- **Some sites may prohibit** automated access or scraping
- This app **does not endorse or verify** any third-party content

### Privacy

This application:
- **Does NOT collect** any personal data
- **Does NOT transmit** any data to external servers
- **Stores all data locally** on your device only
- **Does NOT include** any analytics or tracking

### Warranty Disclaimer

THIS SOFTWARE IS PROVIDED **"AS IS"**, WITHOUT WARRANTY OF ANY KIND.

---

## 📝 License

**CC BY-NC-SA 4.0** (Creative Commons Attribution-NonCommercial-ShareAlike 4.0)

| Term | Description |
|------|-------------|
| **Attribution (BY)** | Give appropriate credit |
| **NonCommercial (NC)** | No commercial use |
| **ShareAlike (SA)** | Same license for derivatives |

---

## 👨‍💻 Author

**Mastergear (Keunjin Kim)**  
🔗 [Facebook](https://www.facebook.com/keunjinkim00)

### ☕ Support

If you like this app, please consider buying me a coffee!

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/keunjin.kim)
