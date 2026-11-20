# tsubomi-kit

tsubomi のアプリ（Profilink・TouchRotator ほか）が共通で使う部品です。アプリではなく、各アプリの中に組み込むライブラリです。

## 入っているもの

| 部品 | 内容 |
|---|---|
| `TsubomiKitCore` | UI を持たない部分。アプリ同士の知らせの形、🌸 を出す担当の決め方、🌸 を押したときに開くか閉じるかの判断。Foundation だけに依存し、Linux でもテストできます |
| `TsubomiMenuBar` | メニューバーのアイコンとガラスのパネル（Profilink・TouchRotator の `StatusItemController` を共通にしたもの）と、アイコンを 1 つにまとめる仕組み。macOS 13 以降 |

## メニューバーのアイコンを 1 つにまとめる

機能はそれぞれのアプリのまま、メニューバーのアイコンだけを 🌸 1 つにまとめます。

```
Profilink    ┐
TouchRotator ├─ Mac のアプリ間通知で「起動しています」と知らせ合う
ほかのアプリ  ┘
      ↓
いちばん先に起動したアプリが 🌸 を出し、ほかはアイコンを隠す
      ↓
🌸 を押す → 最後に開いたアプリが、自分のパネルを 🌸 の下に出す
          → パネルの上の切り替えで、ほかのアプリのパネルに移る
```

- **追加のアプリは要りません。** どのアプリも同じ決め方で担当を選ぶので、相談しなくても 🌸 の担当は 1 つに決まります
- **担当のアプリを終了すると**、残ったアプリが 🌸 を引き継ぎます。1 つだけになったら、そのアプリのアイコンに戻ります
- **一度だけ聞きます。** tsubomi のアプリが 2 つ以上起動したら、パネルの上に「メニューバーのアイコンをまとめますか？」を出します。答えはすべての tsubomi のアプリで共通です（`~/Library/Preferences/works.tsubomi.shared.plist`）
- **アプリごとに外せます。** 設定 › tsubomi で外したアプリは、まとめているあいだも自分のアイコンを出します。外したアプリはほかのアプリに「アイコンを出していない」と名乗るので、外す仕組みを知らない前の版とも食い違いません
- **ライセンスには関係しません。** 各アプリは自分のライセンスを自分で確認し、パネルの中身も自分で描きます
- **起動していないアプリ**も、一度起動したことがあれば切り替えに薄く出し、押すと起動してパネルを出します
- アプリの設定でメニューバーのアイコンを隠しているアプリは、まとめる仕組みに参加しません
- やり取りの形の版（`MenuBarProtocol.version`）が違うアプリとはまとめず、それぞれのアイコンのままにします
- 🌸 の形は、アプリの `.app` の `Contents/Resources/tsubomi-logo.png`（tsubomi のロゴ）から白い花の部分を抜き出して作ります。各アプリの Makefile がすでにこの画像を入れています

## アプリへの組み込み方

1. `Package.swift` に追加します。

   ```swift
   dependencies: [
       .package(url: "https://github.com/tsubomi-works/tsubomi-kit", branch: "main"),
   ],
   // アプリのターゲットの dependencies に
   .product(name: "TsubomiMenuBar", package: "tsubomi-kit"),
   ```

2. 自前の `StatusItemController` を置き換えます。

   ```swift
   import TsubomiMenuBar

   let menuBar = TsubomiMenuBar(appName: "Profilink", icon: MenuBarIcon.active) { close in
       MenuBarView(close: close).environmentObject(model)
   }
   // 中身が変わったらパネルの大きさを合わせ直す。
   menuBar.redrawWhenChanged(model.objectWillChange)
   // パネルを開く前に状態を読み直す。
   menuBar.willShowPanel = { model.refreshDefaultBrowser() }
   // 一時停止などでアイコンを変える。
   model.$isPaused.sink { menuBar.icon = $0 ? MenuBarIcon.paused : MenuBarIcon.active }
   // 「メニューバーにアイコンを表示」の設定。
   model.$showsMenuBarIcon.sink { menuBar.isIconVisible = $0 }
   ```

3. パネルの中身（`MenuBarView`）から、外側の飾りを外します。ガラスの背景・角丸 26・幅 320・外側の余白 12 は `TsubomiMenuBar` が描きます。

   ```swift
   // 外すもの
   .padding(12)
   .frame(width: 320)
   .background(PopupGlassBackground())
   .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
   .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(...))
   ```

4. 設定のサイドバーに「tsubomi」のページを足します（どのアプリでも同じ中身）。

   ```swift
   // サイドバーの項目：名前は TsubomiSettingsPage.title、四角の色は TsubomiSettingsPage.tileColor、
   // 絵は FlowerIcon.image（テンプレート画像。白で描く）
   TsubomiSettingsPage(coordinator: menuBar.coordinator)
   ```

   ページの中身：
   - **メニューバー** — 「1 つにまとめる／アプリごとに表示」（絵つきの 2 択）と、🌸 に入れるアプリ（外したアプリは単独でアイコンを出す）
   - **tsubomi のアプリ** — 入っているアプリの版・起動中か・開く。入っていないアプリは販売ページへ（`TsubomiCatalog`。新しいアプリを出したらここに足す）

5. 設定の窓に、サイドバーの開閉ボタンを消し続ける処理をかけます（SwiftUI があとから入れ直すため）。

   ```swift
   window.keepSidebarToggleAway()
   ```

## 開発

```bash
swift test   # TsubomiKitCore のテスト（Linux でも動く）
swift build  # macOS では TsubomiMenuBar もビルドする
```
