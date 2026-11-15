library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_sigma_Delta is
end tb_sigma_Delta;

architecture sim of tb_sigma_Delta is
    signal CLK         : std_logic := '0';
    signal pdm_out     : std_logic;
    signal interrupt   : std_logic;
    signal sim_done    : boolean := false;

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz
begin

    clk_process: process
    begin
        while not sim_done loop
            CLK <= '0';
            wait for CLK_PERIOD/2;
            CLK <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    uut: entity work.sigma_Delta
        port map (
            CLK         => CLK,
            pdm_out     => pdm_out,
            interrupt   => interrupt
        );

    stim_proc: process
    begin
        wait for 100 ms;
        sim_done <= true;
        report "SIMULATION COMPLETE" severity note;
        wait;
    end process;

end sim;
