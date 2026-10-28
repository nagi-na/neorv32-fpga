-- NEORV32 (v1.13.7) を Ti375N1156 開発キットで動かすためのトップ
-- 中身は無改変のテストセットアップ (UART ブートローダ版) で, ここではピンとの接続だけを行う
-- ポート名は Sapphire.v と同じ (Interface Designer の設定を流用するため)

library ieee;
use ieee.std_logic_1164.all;

library neorv32;

entity neorv32_ti375 is
  port (
    io_systemClk : in  std_logic;  -- PLL 出力 (100MHz)
    pll_locked   : in  std_logic;  -- PLL が安定したら 1
    rst_n        : in  std_logic;  -- SW3 (押すと 0)

    -- UART (19200 baud: ブートローダの既定値)
    uart_rxd     : in  std_logic;
    uart_txd     : out std_logic;

    led_1        : out std_logic;
    led_2        : out std_logic;
    led_3        : out std_logic;
    led_4        : out std_logic
  );
end entity;

architecture rtl of neorv32_ti375 is

  signal rstn : std_ulogic;
  signal gpio : std_ulogic_vector(7 downto 0);

begin

  -- SW3 を押している間, または PLL が安定するまではリセット (アクティブ Low)
  rstn <= rst_n and pll_locked;

  u_neorv32: entity neorv32.neorv32_test_setup_bootloader
  generic map (
    CLOCK_FREQUENCY => 100000000, -- io_systemClk の周波数 [Hz]
    IMEM_SIZE       => 16*1024,   -- 既定値のまま
    DMEM_SIZE       => 8*1024     -- 既定値のまま
  )
  port map (
    clk_i       => io_systemClk,
    rstn_i      => rstn,
    gpio_o      => gpio,
    uart0_txd_o => uart_txd,
    uart0_rxd_i => uart_rxd
  );

  -- GPIO 8 本のうち下位 4 本を LED1〜4 へ (High で点灯)
  led_1 <= gpio(0);
  led_2 <= gpio(1);
  led_3 <= gpio(2);
  led_4 <= gpio(3);

end architecture;
