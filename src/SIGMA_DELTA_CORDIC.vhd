library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sigma_Delta is
    Port (
        CLK       : in  STD_LOGIC;
        pdm_out   : out STD_LOGIC;
        interrupt : out STD_LOGIC := '0'
    );
end sigma_Delta;

architecture sigma_delta_arch of sigma_Delta is

    -- CORDIC gain-compensated amplitude (19894 ~= 32766 / K_15, prevents 16-bit overflow)
    constant k                   : integer := 16#4DB6#;
    -- Phase increment for 1 kHz sine at f_clk = 100 MHz, fs = f_clk / 16 = 6.25 MHz
    constant phase_inc           : unsigned(31 downto 0) := to_unsigned(687195, 32);
    -- Interrupt timing constants (500 kHz, 50% duty cycle at 100 MHz)
    constant C_INT_BUFFER_LIMIT  : integer := 2**10;
    constant C_INT_PERIOD_CYCLES : integer := 200;
    constant C_INT_PULSE_CYCLES  : integer := 100;

    signal int_counter : integer range 0 to C_INT_BUFFER_LIMIT-1 := 0;
    signal phase_acc   : unsigned(31 downto 0) := (others => '0'); -- 32-bit NCO phase accumulator
    signal clk_delay   : integer range 0 to 7 := 0;                -- Divides CLK by 8 for PDM rate
    signal N           : integer range 0 to 15 := 0;               -- CORDIC step counter (16 cycles/sample)
    signal theta       : integer range -65536 to 65535 := 0;       -- Residual angle (pi/2 = 65536)
    signal x           : signed(16 downto 0) := to_signed(k, 17);  -- 17-bit signed to avoid intermediate overflow
    signal y           : signed(16 downto 0) := (others => '0');
    signal y_out       : signed(16 downto 0) := (others => '0');   -- Latched sine output

    -- 1st-order Sigma-Delta modulator accumulator and unsigned input
    signal sigma_acc, sigma_acc_next : unsigned(16 downto 0) := (others => '0');
    signal y_unsigned                : unsigned(15 downto 0);

    -- Elementary CORDIC angles atan(2^-i) for i = 0..14, scaled to pi/2 = 65536
    type LUT is array (14 downto 0) of integer range -32768 to 32767;
    constant arctg_lut : LUT := (
        32767, 19344, 10221, 5188, 2604, 1303, 652, 326,
        163,   81,    41,    20,   10,   5,    3
    );

begin
    CORDIC_process: process(CLK)
    begin
        if rising_edge(CLK) then
            -- Periodic interrupt pulse generator (100 cycles high, 100 cycles low)
            if (int_counter < C_INT_PERIOD_CYCLES-1) then
                int_counter <= int_counter + 1;
                if (int_counter = C_INT_PULSE_CYCLES - 1) then
                    interrupt <= '0';
                end if;
            else
                interrupt   <= '1';
                int_counter <= 0;
            end if;

            -- CORDIC rotation mode (15 shift-add iterations + 1 latch/init cycle = 16 cycles)
            if (N /= 15) then
                N <= N + 1;
                if (theta > 0) then
                    x     <= x - shift_right(y, N);
                    y     <= shift_right(x, N) + y;
                    theta <= theta - arctg_lut(14-N);
                else
                    x     <= x + shift_right(y, N);
                    y     <= -shift_right(x, N) + y;
                    theta <= theta + arctg_lut(14-N);
                end if;

                -- Advance NCO phase one cycle before re-initialization
                if (N = 14) then
                    phase_acc <= phase_acc + phase_inc;
                end if;
            else
                -- Latch completed sine sample and initialize next quadrant/angle
                y_out <= y;
                N     <= 0;
                case phase_acc(31 downto 30) is
                    when "00"   => x <= to_signed(k, 17);  y <= (others => '0');
                    when "01"   => x <= (others => '0');   y <= to_signed(k, 17);
                    when "10"   => x <= to_signed(-k, 17); y <= (others => '0');
                    when others => x <= (others => '0');   y <= to_signed(-k, 17);
                end case;
                theta <= to_integer(phase_acc(29 downto 14));
            end if;

            -- Sigma-Delta update every 8 CLK cycles (2 PDM steps per CORDIC sample)
            if (clk_delay < 7) then
                clk_delay <= clk_delay + 1;
            else
                sigma_acc <= sigma_acc_next;
                clk_delay <= 0;
            end if;
        end if;
    end process;

    -- Offset signed sine output to unsigned [2, 65532] and integrate quantization error
    y_unsigned     <= unsigned(y_out(15 downto 0) + 32767);
    sigma_acc_next <= ('0' & sigma_acc(15 downto 0)) + y_unsigned;
    pdm_out        <= sigma_acc(16); -- 1-bit PDM carry output

end sigma_delta_arch;
