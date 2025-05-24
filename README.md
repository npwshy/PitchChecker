# PitchChecker

WAVファイルの音データの音高（ピッチ）を表示します。

# 使い方

## 準備

* 入っていなければ PowerShell v7 以降をインストール
* コードをクローン
* ダウンロード先にログ補完先フォルダ logs を作成。ログ保管先はオプションで変更可能


## 実行

`
pwsh .\PitchChecker.ps1 -File <ファイル>
`

# オプション

## -File <string>

必須。規定値なし。

WAVEファイルを指定します。対応しているのは以下。

* 32ビット Float
* 16ビット PCM

## -StartTime <float>

規定値は 0。

データ取得開始位置を指定の秒数にします。

## -Interval <float>

規定値は 0.2。

データ解析間隔(秒)を指定します。この間隔毎に音を一つ抽出します。

## -ExportTo <string>

指定のファイルに StartTime から Interval 秒間のデータを FFT した結果データを指定のファイルに書き込みます。この場合、各インターバル毎の解析は実行しません。

## -ShowAll

既定では連続して同じ音が検出された場合の表示をスキップしますが、それを全て表示するようにします。

## -LogFilename <string>

規定値 logs\log.txt

実行結果ログを出力するファイル。



