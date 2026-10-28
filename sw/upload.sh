#!/usr/bin/env bash
# NEORV32 ブートローダへ UART で実行ファイルを送り, 起動して出力を表示する
#
# 公式の sw/image_gen/uart_upload.sh との違い:
#   - " u" を送ったあと, ブートローダが "Awaiting" と返すのを待ってからファイルを送る
#     (テストセットアップの UART0 は受信 FIFO が 1 段しかなく, ブートローダが
#      メッセージを送信している間に届いたバイトが捨てられて ERROR_SIGNATURE になるため)
#   - stty は GNU 版 (gnustty) を使う (Ubuntu 標準の uutils 版は -hup 非対応)
#   - 起動後のプログラムの出力を数秒間表示する
#
# 使い方: SW3 を押してから 8 秒以内に
#   ./upload.sh <neorv32_exe.bin> [シリアルポート] [出力を表示する秒数]

set -e

EXE=$1
TTY=${2:-/dev/ttyUSB2}
VIEW=${3:-5}
BAUD=19200

if [ -z "$EXE" ] || [ ! -f "$EXE" ]; then
  echo "usage: $0 <neorv32_exe.bin> [serial port] [view seconds]" >&2
  exit 1
fi

# 返事の中に文字列 $1 が現れるまで最大 $2 秒待つ
wait_for() {
  local pattern=$1 limit=$(( SECONDS + $2 )) buf="" ch
  while [ $SECONDS -lt $limit ]; do
    if IFS= read -r -n 1 -u 3 -t 1 ch; then
      buf+=$ch
      if [[ "$buf" == *"$pattern"* ]]; then
        return 0
      fi
      if [[ "$buf" == *"ERROR"* ]]; then
        IFS= read -r -t 1 -u 3 ch || true   # エラー名の残りを読む
        echo "NG (bootloader: ERROR${buf##*ERROR}${ch})" >&2
        return 1
      fi
    fi
  done
  echo "NG (timeout waiting for '$pattern')" >&2
  return 1
}

gnustty -F "$TTY" $BAUD -hup raw -echo cs8 -cstopb -ixon clocal cread
exec 3<>"$TTY"

printf "Requesting upload... "
printf " u" >&3              # 自動起動を止めて (SPACE), アップロードを要求 ('u')
wait_for "Awaiting" 3
echo "OK"

SIZE=$(stat -c%s "$EXE")
printf "Uploading %s (%d bytes)... " "$EXE" "$SIZE"
cat "$EXE" >&3
wait_for "OK" $(( SIZE / (BAUD / 10) + 3 ))
echo "OK"

echo "Booting executable... (output for ${VIEW}s)"
echo "----------------------------------------"
printf "e" >&3
timeout "$VIEW" cat <&3 || true
echo
echo "----------------------------------------"
exec 3>&-
