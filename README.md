# PitchChecker

WAVファイルの音データの音高（ピッチ）を表示します。

# 使い方

## 準備

* 入っていなければ PowerShell v7 以降をインストール
* [MathNet](https://numerics.mathdotnet.com/)をダウンロードしてインストール
* コードをクローン
* FFTHelper.psm1 の Add-Type のパスを修正
* ダウンロード先にログ保管先フォルダ logs を作成。ログ保管先はオプションで変更可能


## 実行

`
pwsh .\PitchChecker.ps1 -File <ファイル>
`

# 実行結果例

```
0:01:46.2 G4 ソ 400 (+5) Miss! 54.6%
0:01:46.4 G3 ソ 181 (-16) Miss! 54.5%
0:01:47.0 D#4 レ# 305 (+8) Miss! 54.4%
0:01:47.2 B3 シ 241 (+7) Miss! 54.3%
0:01:47.4 A#3 ラ# 238 (+4) Miss! 54.2%
0:01:47.6 G3 ソ 172 (-25) Miss! 54.1%
```

WAVファイルデータ内の再生時刻、音、正規の音高からのずれ、すれが許容できるかどうか、許容内に入っている音の割合を表示します。


# オプション

## -File \<string\>

必須。規定値なし。

WAVEファイルを指定します。対応しているのは以下。

* 32ビット Float
* 16ビット PCM

## -StartTime \<float\>

規定値は ~~0~~ 1 (録音開始直後のノイズスキップのため)。

データ取得開始位置を指定の秒数にします。

## --EndTime \<float\>

規定値 0。

データ末尾を解析しない時間。

## -OutFile \<path\>

FFT 解析後のデータを JSON 形式で保存し、そのデータを可視化する HTML ファイルを制します。

指定されたファイルパスの拡張子は無視され、パス.json、パス.html ファイルが生成されます。

## -Interval \<float\>

規定値は 0.1 ~~0.2~~。

データ解析間隔(秒)を指定します。この間隔毎に音を一つ抽出します。

## -ExportTo \<string\>

~~指定のファイルに StartTime から Interval 秒間のデータを FFT した結果データを指定のファイルに書き込みます。この場合、各インターバル毎の解析は実行しません。~~

廃止されました。

## -ShowAll

~~既定では連続して同じ音が検出された場合の表示をスキップしますが、それを全て表示するようにします。~~

廃止されました。

## -LogFilename \<string\>

規定値 logs\log.txt

実行結果ログを出力するファイル。

