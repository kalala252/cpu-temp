# CPUTemp

macOS のメニューバーに CPU 温度を表示する軽量アプリです。Apple Silicon / Intel どちらでも動作し、**管理者権限（root）不要**で温度を取得します。

- メニューバーに `60℃` のように現在の CPU 温度を表示
- 数字の色が温度に応じて変化（緑 → オレンジ → 赤）
- クリックすると CPU 以外のセンサー（GPU・SoC / Neural・バッテリー / 電源・その他）も一覧表示
- 一番下に **終了 (Quit)** ボタン
- 白ベースのシンプルな UI
- Dock アイコンなしのメニューバー常駐アプリ

> macOS には CPU 温度を取得する公開 API がないため、SMC（System Management Controller）および `IOHIDEventSystem` の 2 つの非公開インターフェイスを併用しています。SMC から CPU / GPU / SoC コア温度を、IOHIDEventSystem から PMU / バッテリー系の温度を取得します。

## 動作環境

- macOS 13 (Ventura) 以降
- Xcode Command Line Tools（`swift` コマンド）

```sh
xcode-select --install
```

## ビルドと実行

リポジトリ直下で以下を実行すると、`dist/CPUTemp.app` が生成されます。

```sh
./build_app.sh
open dist/CPUTemp.app
```

ビルドすると CPU 温度がメニューバーに表示されます。クリックすると各種センサーの一覧と終了ボタンが出ます。

### 開発用

```sh
# そのまま実行（メニューバー常駐）
swift run -c release

# センサー一覧をターミナルに出力（UI を起動せず確認用）
CPUTEMP_DUMP=1 swift run -c release
```

## 温度と色の対応

| 温度        | 色          |
| ----------- | ----------- |
| 〜35℃ 前後  | 緑          |
| 55℃ 前後    | 黄緑〜オリーブ |
| 70℃ 前後    | オレンジ    |
| 85℃ 以上    | 赤          |

中間の温度はグラデーションで補間されます。

## ログイン時に自動起動する

「システム設定 → 一般 → ログイン項目」で `CPUTemp.app` を追加してください。

## 仕組み

- `Sources/SMCSensors/` … 非公開 IOKit を呼び出す C ブリッジ。SMC と `IOHIDEventSystemClient` の両方からサーマルセンサーを列挙して名前と摂氏温度を返します。
- `Sources/CPUTemp/` … AppKit + SwiftUI 製のメニューバー UI。`NSStatusItem` に色付きの温度を描画し、クリックで `NSPopover`（SwiftUI）を表示します。

メニューバーの数値は CPU 系センサーの最大値を採用しています。Apple Silicon では SMC の `Tp*`（P-Core）/ `Te*`（E-Core）キーから取得しています。

## 注意

- 非公開 API を使用しているため、将来の macOS で名称や挙動が変わる可能性があります。
- Mac App Store での配布には向きません（非公開 API のため）。個人利用・GitHub での配布を想定しています。

## ライセンス

MIT License. 詳細は [LICENSE](LICENSE) を参照してください。
