# Hover Translate

[English](README.en.md) · 日本語 · [MIT License](LICENSE)

英文を選択して **⌥ Option＋T** を押すと、Apple標準翻訳で日本語を表示する小さなMacアプリです。フルスクリーンでも使えます。必要なときだけ、訳の「AIで訳し直す（外部送信）」からOpenRouterを使えます。

**試作段階です。Apple公証済みの配布アプリではありません。** 自動ホバー翻訳・コピー監視・常駐する画面内ボタンはありません。

## 使い方

1. 下の「新しいMacに導入する」の手順でビルドし、アプリを起動します。
2. 設定の「Apple翻訳を準備」で英語・日本語を準備します。必要な場合のみ、macOSが言語データのダウンロードを案内します。
3. 「Macのアクセス設定を開く」からHover Translateのアクセシビリティを許可します。
4. CodexまたはClaudeで英文を選択し、**Optionを押しながらT**。コピーやメニューバー操作は不要です。訳を閉じるには吹き出しの×を押します。
5. AI翻訳も使う場合はアプリ内でOpenRouter APIキーを保存します。Apple訳の「AIで訳し直す（外部送信）」を押したときだけ、元の選択文を送信します。

Option+Tは対象アプリが手前のときだけ登録します。Command+Tは変更しません。対象アプリ内ではOption+Tの既存の文字入力・操作より翻訳を優先します。システム上でキーを登録できない場合は設定画面に表示します。

選択がない、対象外アプリ、読み取り許可がない場合は翻訳しません。選択文を取得できないときも、カーソル下の文章・クリップボード・文書全体で代用しません。Apple翻訳の失敗時もAIへ自動送信しません。結果は閉じるまで表示されます。

初期対象はCodexとClaude。設定の「変更」で対象を選べます。CodexとClaudeではElectronの公式`AXManualAccessibility`属性で文字情報の公開を要求します。対応状況は対象アプリの実装によって変わります。

右クリックのLook Up / Copyなどの一覧には追加しません。メニューバーの「訳」はApple翻訳の補助操作として残しています。設定はアプリを開き直すか「訳」を右クリックして開けます。

## 費用とプライバシー

- 通常はApple Translation frameworkで端末内翻訳します。APIキーとAPI従量料金は不要です。言語モデルはmacOSが管理します。
- 任意のAI翻訳には `openai/gpt-4.1-nano` を使用。2026-09-27確認の単価は入力100万トークン$0.10、出力$0.40。入力300・出力300トークンなら約$0.00015/回。文字量や価格改定で変わります。
- 入力は1,800文字かつ7,200 UTF-8バイト以内。AI出力は最大1,200トークン。AIは1日500回までで、失敗・キャンセルも回数に含みます。自動の通信再試行はありません。
- 入力のバイト数をトリム・正規表現より先に制限し、結合文字・ゼロ幅文字でも上限を回避できないようにしています。
- AI再翻訳を明示的に押したときだけ、選択した原文をOpenRouterとモデル提供元へ送信します。設定の接続テスト・比較では固定の公開テスト文だけを送信します。providerに`data_collection: deny`、`zdr: true`と単価上限を指定します。これらの履行は外部サービスに依存し、OpenRouterのアカウント設定・ポリシーも適用されます。
- 同じ文はApple・AIそれぞれメモリ上の64件キャッシュを使います。右クリックのキャッシュ削除または終了で破棄します。アプリの回数制限はOpenRouterアカウント全体の金額制限ではありません。専用の利用上限付きAPIキーを推奨します。
- キーはアプリのSecureFieldから**このMacのローカル・キーチェーン**に保存します。iCloud同期は未対応で、同じApple Accountだけでは他のMacへ共有されません。各Macで初回保存してください。
- 認識できるAPIキー・トークン・秘密鍵・パスワード代入を含む文字列は送信を拒否します。完全な機密情報検出ではありません。選択した企業情報・個人情報なども外部へ送られるため、送信できる文章だけを選んでください。
- 固定HTTPS宛先だけを使い、HTTPリダイレクトは拒否します。モデルにツール実行権限はありません。
- 原文・訳のファイル保存、テレメトリー、画面録画、スクリーンショット、クリップボード読み取りはありません。UserDefaultsには対象アプリ、日別回数、キー有無などの設定メタデータだけを保存します。OSのメモリ管理やクラッシュ記録まで制御する保証ではありません。
- 吹き出しは×を押すまで表示されるため、画面共有前には閉じてください。

料金：[OpenRouter GPT-4.1 nano](https://openrouter.ai/openai/gpt-4.1-nano)

## 新しいMacに導入する

**macOS 26以降・Swift 6.2以降のCommand Line Toolsが必要です。** 現在はソースからビルドする試作版です。第三者ライブラリ・サーバーは不要です。画面の表示は日本語で、翻訳方向は英語→日本語です。

Command Line Toolsがない場合は、先にターミナルで `xcode-select --install` を実行し、Appleのインストール画面を完了してください。その後：

```sh
mkdir -p ~/Projects
cd ~/Projects
git clone https://github.com/rjoshima/hover-translate.git
cd hover-translate
./scripts/check.sh
./scripts/build.sh
open dist
```

Finderに表示された **Hover Translate.app** を自分の「アプリケーション」フォルダ（`~/Applications`。なければ作成）へコピーし、そのコピーを開きます。更新時は、動作中のHover Translateを設定画面から終了してから置き換えてください。アクセシビリティには、ビルド用のdistフォルダではなく、このインストール先のアプリを登録します。

新しいMacでは「Apple翻訳を準備」とアクセシビリティ許可をもう一度行います。Apple翻訳だけならAPIキーの移行は不要です。対象アプリの設定もMacごとに選び直します。AIを使う場合だけ、そのMacのアプリ内入力欄からキーを保存してください。

## 構成と開発

単独のスクリプトではなく、Swift / AppKit / SwiftUIで作った常駐Macアプリです。スクリプトはビルドと検証に使います。Apple翻訳と任意のAI翻訳は同じアプリにまとめ、翻訳処理を分離しています。選択文の取得・ショートカット・表示・許可処理を共有でき、Apple利用者にAPI設定を必須にしません。名前はHover Translateですが、現在は明示的な選択操作でのみ翻訳します。

```sh
./scripts/check.sh
./scripts/check-keychain.sh # UUIDで分けたテスト領域とダミー値だけを使用
./scripts/build.sh
```

リポジトリをクローンしてビルドし、各MacでApple言語データの準備・アクセシビリティ許可を設定します。AIを使うMacだけAPIキーも保存します。キーはGit、設定ファイル、iCloud Driveにコピーしません。

`Package.swift`もありますが、アプリの実行には上記スクリプトで作ったバンドルを使ってください。ローカルのCommand Line Tools問題に対応するため`swiftc`を直接使い、重複module mapがある場合はコンパイラ限定のVFS overlayを使います。システムファイルは変更しません。

ビルド成果物はHardened Runtime付きのad-hoc署名です。App Sandboxではありません。再ビルド後はキーチェーンやアクセシビリティの再許可が必要な場合があります。アクセシビリティがオンでも動かない場合は、その一覧からHover Translateの登録を外し、実際に使うアプリ本体を追加し直してください。安定した一般配布にはDeveloper ID署名とApple公証が別途必要です。

## 検証状況

ローカルチェックは文字数・バイト数・キャッシュ・固定宛先・機密文字列・単価/保持設定・リダイレクト・失敗応答を確認します。キーチェーンチェックは実キーに触れません。

2026-09-27、M4・16GBのMacで固定英文3件を各1回、アプリ内キャッシュを使わず比較しました。言語モデルの初期準備後の測定です。

- Apple: 0.09秒、0.30秒、0.24秒。
- GPT-4.1 nano: 比較の第2・第3文で1.77秒、1.46秒。第1文はキーチェーン認証待ちを含んだため速度評価から除外。
- 3件では、Apple・AIとも意味とGitコマンドを保ちました。Appleは設定説明の「When off」を「オフになると」とするなど表現に差があります。少数例なので翻訳品質・速度の一般的な保証ではありません。

Claudeをフルスクリーンにし、設定説明の英文を選択してOption+Tを押すと、Appleの日本語訳が表示されることを実操作で確認しました。Apple翻訳ではAPI利用回数が増えません。訳の「AIで訳し直す（外部送信）」も実操作で確認し、同じ選択文がAPIで再翻訳されました。Codexの実画面・別Macは未検証です。

[Apple Translation](https://developer.apple.com/documentation/translation/) / [Electron Accessibility](https://www.electronjs.org/docs/latest/tutorial/accessibility) / [Electron Context Menu](https://www.electronjs.org/docs/latest/tutorial/context-menu)

## ライセンス

MIT。Appleの翻訳モデルやOSのコードは同梱・再配布しません。Apple、OpenAI、Anthropic、OpenRouterとは独立した非公式プロジェクトです。

変更を提案する場合は [CONTRIBUTING.md](CONTRIBUTING.md)、脆弱性の報告は [SECURITY.md](SECURITY.md) を参照してください。
