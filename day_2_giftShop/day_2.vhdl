library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.productID_pkg.all;

entity productID is
  port (
    clk   : in  std_logic;
    reset : in  std_logic;

    start       : in  std_logic;
    range_valid : in  std_logic;
    range_lo    : in  unsigned(63 downto 0);
    range_hi    : in  unsigned(63 downto 0);
    range_ready : out std_logic;

    done        : out std_logic;
    invalid_sum : out unsigned(127 downto 0)
  );
end entity;

architecture rtl of productID is
  type state_t is (ST_IDLE, ST_WAIT_RANGE, ST_DO_K, ST_NEXT_K, ST_DONE);
  signal st : state_t := ST_IDLE;

  signal A, B : unsigned(63 downto 0);

  signal k : integer range 1 to 19 := 1;

  signal pow10_km1 : unsigned(63 downto 0) := (others => '0'); -- 10^(k-1)
  signal pow10_k   : unsigned(63 downto 0) := (others => '0'); -- 10^k

  signal sum_acc   : unsigned(127 downto 0) := (others => '0');

begin
  invalid_sum <= sum_acc;

  process(clk)
    -- per-cycle variables (avoid “old signal” problems)
    variable m_v       : unsigned(63 downto 0);
    variable xmin_v    : unsigned(63 downto 0);
    variable xmax_v    : unsigned(63 downto 0);
    variable cnt_v     : unsigned(63 downto 0);

    variable t1        : unsigned(127 downto 0);
    variable t2        : unsigned(127 downto 0);

    variable prod256   : unsigned(255 downto 0);
    variable s_halves  : unsigned(127 downto 0);
    variable add_term  : unsigned(127 downto 0);
  begin
    if rising_edge(clk) then
      if reset = '1' then
        st <= ST_IDLE;
        range_ready <= '0';
        done <= '0';
        sum_acc <= (others => '0');
        k <= 1;
        pow10_km1 <= (others => '0');
        pow10_k   <= (others => '0');

      else
        case st is
          when ST_IDLE =>
            done <= '0';
            range_ready <= '0';
            if start = '1' then
              sum_acc <= (others => '0');
              st <= ST_WAIT_RANGE;
            end if;

          when ST_WAIT_RANGE =>
            range_ready <= '1';
            if range_valid = '1' then
              range_ready <= '0';
              A <= range_lo;
              B <= range_hi;

              -- init k loop
              k <= 1;
              pow10_km1 <= to_unsigned(1, 64);   -- 10^(0)
              pow10_k   <= to_unsigned(10, 64);  -- 10^(1)

              st <= ST_DO_K;
            end if;

          when ST_DO_K =>
            -- m = 10^k + 1
            m_v := pow10_k + 1;

            -- stop if (10^(k-1) * m) > B
            -- rewritten to avoid wide multiply:
            -- pow10_km1 > (B / m)
            if pow10_km1 > (B / m_v) then
              st <= ST_DONE;
            else
              -- compute xmin/xmax for this k
              xmin_v := umax(pow10_km1, ceil_div(A, m_v));
              xmax_v := umin(pow10_k - 1, (B / m_v));

              if xmin_v <= xmax_v then
                cnt_v := xmax_v - xmin_v + 1;

                -- s_halves = (xmin+xmax)*cnt/2
                t1 := resize(xmin_v, 128) + resize(xmax_v, 128);
                t2 := resize(cnt_v, 128);

                prod256  := t1 * t2;                 -- 256-bit
                s_halves := resize(prod256 / 2, 128);

                -- add_term = m * s_halves
                prod256  := resize(m_v, 128) * s_halves;  -- 256-bit
                add_term := resize(prod256, 128);

                sum_acc <= sum_acc + add_term;
              end if;

              st <= ST_NEXT_K;
            end if;

          when ST_NEXT_K =>
            k <= k + 1;
            pow10_km1 <= pow10_k;
            pow10_k   <= (pow10_k sll 3) + (pow10_k sll 1);
            st <= ST_DO_K;

          when ST_DONE =>
            done <= '1';
            st <= ST_IDLE;

          when others =>
            st <= ST_IDLE;
        end case;
      end if;
    end if;
  end process;

end architecture;
