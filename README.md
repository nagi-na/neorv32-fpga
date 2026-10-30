# neorv32-fpga

NEORV32 を Efinix と AMD の FPGA に実装して比較するためのリポジトリ (卒業研究)。
NEORV32 本体と CoreMark の移植版はサブモジュールとして `external/` に置き, 無改変で使う。

## 復元手順 (別の PC で)

```bash
mkdir -p ~/fpga-softcpu && cd ~/fpga-softcpu
git clone --recursive https://github.com/nagi-na/neorv32-fpga.git
```

- `--recursive` で `external/` のサブモジュールも取得される
- `external/neorv32-coremark/neorv32` (NEORV32 v1.13.3) も一緒に取得されるが使わない。ビルドでは `NEORV32_HOME` で `external/neorv32` (v1.13.7) を指定する
- 別途必要: Efinity 2026.1, xPack riscv-none-elf-gcc 15.2.0-1 (`~/tools`), Java 11 (SDKMAN, `.sdkmanrc`)

## 構成

| パス | 内容 |
|---|---|
| `external/neorv32/` | NEORV32 v1.13.7 (b1f307244928161a3fca1a010af11d5a736b5339) |
| `external/neorv32-coremark/` | CoreMark の NEORV32 移植版 (e1553f10106faf3edfb34d86780b414782bc2aea), 中の `coremark/` は 1f483d5b |
| `efinix/ti375/` | Efinity プロジェクト (Ti375N1156 開発キット) |
| `amd/` | Vivado プロジェクト (未作成) |
| `sw/upload.sh` | UART ブートローダへの書き込みスクリプト |
| `results/` | 実験結果 (`ti375_fmax_sweep_2026-10-30/`: Ti375 の Fmax スイープ) |
| `docs/neorv32_ja/` | NEORV32 ドキュメントの日本語訳 (入門部分) |
| `.sdkmanrc` | Java 11 の指定 (Efinity の IP Manager が Java 24 以降の警告で失敗するため) |

## 使用したもの

| 項目 | バージョン |
|---|---|
| Efinity | 2026.1 |
| デバイス | Ti375N1156, タイミングモデル C4 |
| RISC-V GCC | xPack riscv-none-elf-gcc 15.2.0-1 |

## efinix/ti375

### ファイル

| ファイル | 内容 |
|---|---|
| `neorv32_ti375.vhd` | トップ。`neorv32.neorv32_test_setup_bootloader` を呼び, ピンとつなぐ |
| `neorv32_ti375.xml` | Efinity プロジェクト。NEORV32 の RTL 55 ファイルを `../../external/neorv32/rtl/...` で参照 (ライブラリ `neorv32`) |
| `neorv32_ti375.peri.xml`, `package_settings.xml` | Interface Designer の設定 (ピン, PLL) |
| `constraints.sdc` | タイミング制約 (`io_systemClk` 100MHz) |

### Efinity の起動

```bash
cd ~/fpga-softcpu/neorv32-fpga   # Java 11 に切り替わる (java -version で確認)
efx                              # Efinity の環境を読み込む
efinity &
```

### 構成

- CPU: rv32imc + Zicsr + Zicntr (テストセットアップの既定値)
- IMEM 16KB (RAM), DMEM 8KB, GPIO 8 本, CLINT, UART0 (FIFO 1 段)
- クロック: GPIOR_101 (100MHz) → PLL_TR2 → `io_systemClk` 100MHz
- リセット: SW3 (GPIOB_P_31) と PLL ロック → `rstn_i`
- UART: TX GPIOL_24, RX GPIOL_20 (FT4232H 経由で `/dev/ttyUSB2`, 番号は接続状況で変わる)
- LED: `gpio(0..3)` → LED1〜4 (LED1 はブートローダの動作表示で点滅)

### ビルド結果 (2026-10-27)

| 項目 | 値 |
|---|---|
| Fmax (io_systemClk) | 176.678 MHz |
| setup / hold slack | 4.340 ns / 0.092 ns |
| XLR | 7,084 / 362,880 (1.95%), うち配線用 632 |
| メモリブロック | 28 |
| DSP | 0 |

## プログラムの書き込みと実行

ブートローダは 19200 baud。

### ビルド

```bash
cd external/neorv32/sw/example/hello_world
make clean_all exe
```

CoreMark は `external/neorv32-coremark` で `make NEORV32_HOME=../neorv32 clean_all exe` (IMEM/DMEM 64KB が必要)。

### 自動 (sw/upload.sh)

screen は閉じておく。SW3 を押してから 8 秒以内に:

```bash
sw/upload.sh <neorv32_exe.bin> [シリアルポート] [出力を表示する秒数]
```

### 手動 (screen)

```bash
screen /dev/ttyUSB2 19200,cs8,-ixon,-ixoff
```

SW3 → 何かキー (Aborted) → `u` → `Awaiting neorv32_exe.bin...` を確認 →
Ctrl+A `:` で `exec .!. cat <neorv32_exe.bin の絶対パス>` → `OK` → `e`

## 注意

- 公式の `make upload` (`sw/image_gen/uart_upload.sh`) はこの環境では失敗する
  - Ubuntu 標準の `stty` (uutils 版) が `-hup` に未対応 → `upload.sh` は `gnustty` を使う
  - UART0 の受信 FIFO が 1 段で, 公式スクリプトは `Awaiting` を待たずに送るため先頭が欠ける (`ERROR_SIGNATURE`) → `upload.sh` は `Awaiting` を待ってから送る
- screen を開いている間は, ほかのプログラムからシリアルポートを開けない (ビジー)
- screen の中で打った文字はブートローダのコマンドになる (`e` 実行, `u` 受信待ち など)
