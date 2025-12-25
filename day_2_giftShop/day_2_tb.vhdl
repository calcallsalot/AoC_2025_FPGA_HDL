library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity tb_productID is
end entity;

architecture sim of tb_productID is


  -- DUT component 

  component productID is
    port (
      clk         : in  std_logic;
      reset       : in  std_logic;

      start       : in  std_logic;

      range_valid : in  std_logic;
      range_lo    : in  unsigned(63 downto 0);
      range_hi    : in  unsigned(63 downto 0);
      range_ready : out std_logic;

      done        : out std_logic;
      invalid_sum : out unsigned(127 downto 0)
    );
  end component;

  signal clk         : std_logic := '0';
  signal reset       : std_logic := '1';
  signal start       : std_logic := '0';
  signal range_valid : std_logic := '0';
  signal range_lo    : unsigned(63 downto 0) := (others => '0');
  signal range_hi    : unsigned(63 downto 0) := (others => '0');
  signal range_ready : std_logic;
  signal done        : std_logic;
  signal invalid_sum : unsigned(127 downto 0);

  constant CLK_PERIOD : time := 10 ns;


  -- Simple storage for parsed ranges

  constant MAX_RANGES : natural := 256;

  type u64_array is array (natural range <>) of unsigned(63 downto 0);
  signal lo_arr : u64_array(0 to MAX_RANGES-1);
  signal hi_arr : u64_array(0 to MAX_RANGES-1);
  signal n_ranges : natural := 0;


  -- Hex print helper (portable)

  function hex_char(n : natural) return character is
    constant lut : string := "0123456789ABCDEF";
  begin
    return lut(n+1);
  end;

  function to_hex(u : unsigned) return string is
    variable padded : unsigned(((u'length+3)/4)*4 - 1 downto 0) := (others => '0');
    variable out_s  : string(1 to padded'length/4);
    variable nib    : unsigned(3 downto 0);
    variable idx    : integer := 1;
  begin
    padded(u'length-1 downto 0) := u;

    for i in 0 to out_s'length-1 loop
      nib := padded(padded'left - i*4 downto padded'left - i*4 - 3);
      out_s(idx) := hex_char(to_integer(nib));
      idx := idx + 1;
    end loop;
    return out_s;
  end;


  -- Parsing helpers

  function is_digit(c : character) return boolean is
  begin
    return (c >= '0') and (c <= '9');
  end function;

    -- Parse an unsigned integer starting at s(idx). Updates idx to first non-digit.
  procedure parse_u64(
    constant s   : in  string;
    variable idx : inout integer;
    variable val : out unsigned(63 downto 0)
  ) is
    variable acc : unsigned(63 downto 0) := (others => '0');
    variable d   : natural;
  begin

    while idx <= s'length and (s(idx) = ' ' or s(idx) = HT) loop
      idx := idx + 1;
    end loop;

    if idx > s'length or not is_digit(s(idx)) then
      val := (others => '0');
      return;
    end if;

    while idx <= s'length and is_digit(s(idx)) loop
      d := character'pos(s(idx)) - character'pos('0');
      acc := (acc sll 3) + (acc sll 1) + to_unsigned(d, acc'length);
      idx := idx + 1;
    end loop;

    val := acc;
  end procedure;

begin


  -- DUT instance

  dut : productID
    port map (
      clk         => clk,
      reset       => reset,
      start       => start,
      range_valid => range_valid,
      range_lo    => range_lo,
      range_hi    => range_hi,
      range_ready => range_ready,
      done        => done,
      invalid_sum => invalid_sum
    );

  -- Clock

  clk <= not clk after CLK_PERIOD/2;


  -- Main stimulus

  stim : process
    file f         : text open read_mode is "inputs.txt";
    variable l     : line;
    variable s     : string(1 to 10000);
    variable slen  : natural;

    variable idx   : integer;
    variable a, b  : unsigned(63 downto 0);

    variable count : natural := 0;


    variable total_sum : unsigned(127 downto 0) := (others => '0');
  begin
    -- Reset
    reset <= '1';
    wait for 5*CLK_PERIOD;
    reset <= '0';
    wait for 2*CLK_PERIOD;

    -- Read single line
    readline(f, l);
    slen := l'length;
    if slen > s'length then
      report "Input line too long for buffer" severity failure;
    end if;

    -- init buffer
    for i in s'range loop
      s(i) := ' ';
    end loop;

    -- copy line into s
    for i in 1 to slen loop
      s(i) := l.all(i);
    end loop;

    -- Parse into arrays
    idx := 1;
    while idx <= integer(slen) loop
      parse_u64(s(1 to slen), idx, a);

      if idx > integer(slen) or s(idx) /= '-' then
        report "Parse error: expected '-' at position " & integer'image(idx) severity failure;
      end if;
      idx := idx + 1;

      parse_u64(s(1 to slen), idx, b);

      if count >= MAX_RANGES then
        report "Too many ranges for MAX_RANGES" severity failure;
      end if;

      lo_arr(count) <= a;
      hi_arr(count) <= b;
      count := count + 1;

      if idx <= integer(slen) and s(idx) = ',' then
        idx := idx + 1;
      else
        exit;
      end if;
    end loop;

    n_ranges <= count;
    report "Parsed ranges: " & integer'image(integer(count));

    for i in 0 to integer(count)-1 loop

      -- pulse start
      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';

      -- wait until DUT asks for range
      while range_ready /= '1' loop
        wait until rising_edge(clk);
      end loop;

      -- present range for one cycle
      range_lo <= lo_arr(i);
      range_hi <= hi_arr(i);
      range_valid <= '1';
      wait until rising_edge(clk);
      range_valid <= '0';

      -- wait done
      while done /= '1' loop
        wait until rising_edge(clk);
      end loop;

      -- accumulate this range's sum into TB total
      total_sum := total_sum + invalid_sum;

    end loop;

    report "ALL RANGES DONE. total_sum = 0x" & to_hex(total_sum);

    wait for 10*CLK_PERIOD;
    report "Simulation finished." severity failure;
  end process;

end architecture;
