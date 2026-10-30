# Ti375 Fmax スイープ (2026-10-30)

SDC の制約周波数と配置配線の seed を変えて, NEORV32 の Fmax を求めた。

## 条件

| 項目 | 値 |
|---|---|
| 設計 | コミット 0471fa1 の `efinix/ti375` (テストセットアップ, IMEM 16KB, DMEM 8KB) |
| ツール | Efinity 2026.1, Ti375N1156, タイミングモデル C4 |
| フロー | `efx_run --prj` で map → interface → pnr (ビットストリームは作らない) |
| 変えたもの | `constraints.sdc` の周期, プロジェクトの pnr の `seed` のみ |
| 合成・配置配線のオプション | プロジェクトの設定のまま (synthesis mode=speed, placer_effort_level=2) |
| PLL | 100 MHz のまま (タイミング解析は SDC の値で行う) |

## 結果

| 定義 | Fmax |
|---|---|
| 制約を満たした最大の周波数 | 390 MHz (seed 2, setup slack +0.008 ns) |
| レポートの Fmax の最大値 | 391.236 MHz (同じ回) |
| 5 回中 4 回満たせた周波数 | 370 MHz |

- 100 MHz 制約では Fmax 176.678 MHz → ゆるい制約では実力の半分以下に見える
- 同じ制約でも seed により ±3〜4% ばらつく (例: 400 MHz 制約で 366.3〜385.2 MHz)
- 420 MHz 以上の制約では結果が同じ (381.825 MHz) で, それ以上は変わらない
- リソース使用量はどの制約でも同じ (XLR 7,084, うち配線用 632)

## ファイル

| ファイル | 内容 |
|---|---|
| `results.csv` | 全 33 回の結果 (制約, seed, 周期, Fmax, setup/hold slack, XLR, 配線用 XLR, 所要秒数) |
| `best_f390_s2.timing.rpt` | 最良の回 (390 MHz 制約, seed 2) のタイミングレポート |
| `best_f390_s2.place.rpt` | 同じ回のリソース使用量 |
| `run_one.sh` | 1 回分のビルドと結果の抽出を行うスクリプト |
| `jobs.txt` | スイープで回した制約と seed の組 (100 MHz, seed 1 は別に実行) |

## 再実行

```bash
cd results/ti375_fmax_sweep_2026-10-30
xargs -P4 -L1 ./run_one.sh < jobs.txt
```

- `efx` (Efinity の環境) は不要 (スクリプトの中で読み込む)
- 1 回約 1 分, 4 並列で 32 回が約 10 分
- 結果は `results.csv` に追記される。別の実験をするときは, このフォルダをコピーして新しい名前で行う
- 作業ファイルは `base/` と `runs/` にでき, git では無視される
