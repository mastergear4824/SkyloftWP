# Skyloft WP

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/macOS-13.0+-brightgreen?style=flat-square" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-lightgrey?style=flat-square" alt="License">
</p>

<p align="center">
  <b>あらゆるストリーミング動画をmacOSデスクトップ壁紙に</b>
</p>

<p align="center">
  <a href="README.md">English</a> | <a href="README.ko.md">한국어</a> | <b>日本語</b>
</p>

ウェブサイトのストリーミング動画をデスクトップ壁紙として表示するmacOSアプリです。写真ライブラリから動画をインポートしたり、カスタムストリーミングソースを追加できます。

---

## ✨ 主な機能

### 🎬 ストリーミング接続
- **カスタムビデオソース** - 好きなストリーミングURLを追加
- **2つの取得モード**:
  - **ストリーミングモード** - 自動再生サイト用イベントベース検出
  - **ポーリングモード** - 静的ページ用定期スキャン
- **バッファモード（デフォルト）** - 保存なしで直接再生
- **オプションの自動保存** - 希望すればライブラリに保存
- **ネットワーク状態監視** - 接続切断時の自動再接続

### 📚 ライブラリ管理
- **写真アプリからインポート** - Mac写真ライブラリの動画を追加
- **ローカルファイルインポート** - ドラッグ&ドロップまたはファイル選択
- **SQLiteデータベース** - 動画メタデータの永続保存
- **自動サムネイル生成** - 自動でサムネイル抽出
- **お気に入りと再生回数追跡**
- **動画非表示** - 不要な動画を除外
- **スマートクリーンアップ** - 制限超過時に古い動画を自動削除

### 🖥️ 壁紙再生
- **デスクトップレベルウィンドウ** - アイコンの下に表示される真の壁紙
- **マルチモニターサポート** - 各モニターで独立した動画再生
- **連続再生** - ライブラリから順次/ループ再生
- **オーバーレイ設定** - 透明度、明るさ、彩度、ブラーの調整

### 🌏 多言語対応
- English (en)
- 한국어 (ko)
- 日本語 (ja)

---

## 📖 使用ガイド

### 1️⃣ ライブラリ

グリッドレイアウトで動画コレクションを管理します。

- **動画追加**: 「Add Videos」をクリックしてローカルファイルをインポート
- **写真ライブラリ**: Mac写真アプリから直接動画をインポート
- **ドラッグ&ドロップ**: 動画ファイルをライブラリに直接ドラッグ
- **サムネイルプレビュー**: 各動画の代表画像を表示
- **動画再生**: クリックして壁紙に設定
- **右クリックメニュー**: 壁紙に設定、Finderで表示、非表示、削除

---

### 2️⃣ ストリーミング設定

カスタムビデオソースと自動保存設定を構成します。

| オプション | 説明 |
|------------|------|
| **接続状態** | ストリーミング接続状態（接続済み/未接続） |
| **ビデオソース** | カスタムストリーミングURLを追加 |
| **取得モード** | ストリーミング（イベントベース）またはポーリング（定期的） |
| **ライブラリに保存** | 有効にすると新しい動画を自動保存（**デフォルトOFF**） |
| **最大動画数** | ライブラリに保持する最大動画数 |

**新しいソースの追加方法:**
1. 「Add Video Source」をクリック
2. ウェブサイトURLを入力
3. 「Fetch」をクリックしてページタイトルを自動検出
4. 取得モードを選択:
   - **Streaming**: 自動再生動画サイト用
   - **Polling**: 複数の動画リンクがあるページ用
5. 「Add Source」をクリック

> ⚠️ **免責事項**: 各ウェブサイトの利用規約の遵守は完全にユーザーの責任です。

---

### 3️⃣ ディスプレイ設定

壁紙の視覚効果を調整します。

**プリセット**: Default, Subtle, Dim, Ambient, Focus, Vivid, Cinema, Neon, Dreamy, Night, Warm, Retro, Cool, Soft

**手動調整**
- **透明度**: 壁紙の不透明度 (0~100%)
- **明るさ**: 明るさ調整 (-100% ~ +100%)
- **彩度**: 色の彩度 (0~200%)
- **ブラー**: ブラー効果 (0~50)

---

### 4️⃣ 一般設定

| オプション | 説明 |
|------------|------|
| **言語** | アプリ言語選択 |
| **ミュート** | 動画オーディオをミュート |
| **ログイン時に起動** | ログイン時に自動起動 |

---

## 📋 必要条件

- **macOS 13.0 (Ventura)** 以降
- **Xcode 15.0** 以降（ビルド時）

---

## 🚀 ビルド

### Xcodeでビルド

1. `SkyloftWP.xcodeproj`をXcodeで開く
2. `SkyloftWP`スキームを選択
3. Product > Build (⌘B)

### コマンドラインでビルド

```bash
xcodebuild -project SkyloftWP.xcodeproj \
           -scheme SkyloftWP \
           -configuration Release \
           -derivedDataPath build
```

### DMG配布版の作成

```bash
./build-dmg.sh
```

---

## 📁 データ保存場所

```
~/Library/Application Support/SkyloftWP/
├── config.json          # アプリ設定
├── library.sqlite       # 動画メタデータDB
├── videos/              # ダウンロードした動画ファイル
├── thumbnails/          # サムネイル画像
└── Buffer/              # バッファモード一時ファイル
```

---

## ⚠️ 免責事項

### ユーザーの責任

- 追加するビデオソースは**完全にユーザーの責任**です
- 各ウェブサイトの**利用規約を遵守**してください
- 一部のサイトは**自動アクセスやスクレイピングを禁止**している場合があります
- このアプリは**サードパーティコンテンツを保証または検証しません**

### プライバシー

このアプリケーションは：
- **いかなる個人データも収集しません**
- **外部サーバーにデータを送信しません**
- **すべてのデータをデバイスにローカル保存のみします**
- **分析やトラッキングを含みません**

### 保証の免責

このソフトウェアはいかなる種類の保証もなく**「現状のまま」**提供されます。

---

## 📝 ライセンス

**CC BY-NC-SA 4.0** (Creative Commons Attribution-NonCommercial-ShareAlike 4.0)

| 条件 | 説明 |
|------|------|
| **帰属表示 (BY)** | 適切なクレジットを表示 |
| **非営利 (NC)** | 商業利用不可 |
| **継承 (SA)** | 派生物も同じライセンス |

---

## 👨‍💻 開発者

**Mastergear (Keunjin Kim)**  
🔗 [Facebook](https://www.facebook.com/keunjinkim00)

### ☕ サポート

このアプリが気に入ったら、コーヒーを一杯おごってください！

<a href="https://www.buymeacoffee.com/keunjin.kim"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=&slug=keunjin.kim&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" /></a>
