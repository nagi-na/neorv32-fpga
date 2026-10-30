#!/bin/bash
# 使い方: run_one.sh <制約周波数 MHz> <seed>
# コミット済みの efinix/ti375 のコピー (base/) で合成・Interface・配置配線を行い,
# 結果を results.csv に 1 行追記する. 作業用の base/ と runs/ は git 管理外.
# まとめて回すとき: xargs -P4 -L1 ./run_one.sh < jobs.txt
set -u
S=$(cd "$(dirname "$0")" && pwd)
REPO=$(git -C "$S" rev-parse --show-toplevel)
F=$1; SEED=$2
if [ ! -d "$S/base" ]; then
    mkdir -p "$S/base"
    git -C "$REPO" archive HEAD efinix/ti375 | tar -x -C "$S/base"
fi
[ -f "$S/results.csv" ] || echo "target_mhz,seed,period_ns,fmax_mhz,setup_slack,hold_slack,xlr,xlr_routing,sec" > "$S/results.csv"
R=$S/runs/f${F}_s${SEED}
P=$(awk -v f="$F" 'BEGIN{printf "%.4f", 1000/f}')

rm -rf "$R"; mkdir -p "$R"
cp -r "$S/base/efinix" "$R/"
ln -s "$REPO/external" "$R/external"
D=$R/efinix/ti375
echo "create_clock -period $P io_systemClk" > "$D/constraints.sdc"
sed -i "s|<efx:param name=\"seed\" value=\"[0-9]*\"|<efx:param name=\"seed\" value=\"$SEED\"|" "$D/neorv32_ti375.xml"

source "$HOME/efinity/2026.1/bin/setup.sh" >/dev/null 2>&1
cd "$D"
start=$(date +%s)
for flow in map interface pnr; do
    efx_run --prj neorv32_ti375.xml -f $flow > "$R/$flow.log" 2>&1 || { echo "$F,$SEED,$P,FAIL_$flow,,,,," >> "$S/results.csv"; exit 1; }
done
sec=$(( $(date +%s) - start ))

T=$D/outflow/neorv32_ti375.timing.rpt
fmax=$(awk '/Maximum possible analyzed clocks frequency/{getline; getline; print $3; exit}' "$T")
setup=$(awk '/Setup \(Max\) Clock Relationship/{getline; getline; print $4; exit}' "$T")
hold=$(awk '/Hold \(Min\) Clock Relationship/{getline; getline; print $4; exit}' "$T")
PR=$D/outflow/neorv32_ti375.place.rpt
xlr=$(awk '/^XLRs:/{print $2; exit}' "$PR")
rt=$(awk '/XLRs needed for Routing:/{print $5; exit}' "$PR")
echo "$F,$SEED,$P,$fmax,$setup,$hold,$xlr,$rt,$sec" >> "$S/results.csv"
# 容量節約: 中間ファイルを消し, レポートだけ残す
rm -rf "$D/work_"* "$D/outflow/"*.{bit,hex,map.v,netlist,lpf,troutingtraces,elab.vdb,place,gplace,htree} 2>/dev/null
