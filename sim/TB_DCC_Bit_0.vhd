----------------------------------------------------------------------------------
-- Testbench: TB_DCC_BIT_0
-- Verification du generateur de bit DCC 0 (100us + 100us)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_DCC_BIT_0 is
end TB_DCC_BIT_0;

architecture Behavioral of TB_DCC_BIT_0 is

    constant CLK_PERIOD : time := 10 ns;
    constant CLK1M_HALF : time := 500 ns;

    signal Clk      : STD_LOGIC := '0';
    signal Clk1M    : STD_LOGIC := '0';
    signal Reset    : STD_LOGIC := '0';
    signal Go       : STD_LOGIC := '0';
    signal Fin      : STD_LOGIC;
    signal DCC_Out  : STD_LOGIC;

    signal t_start_low  : time := 0 ns;
    signal t_start_high : time := 0 ns;

begin

    UUT: entity work.DCC_BIT_0
        port map (
            Clk     => Clk,
            Clk1M   => Clk1M,
            Reset   => Reset,
            Go      => Go,
            Fin     => Fin,
            DCC_Out => DCC_Out
        );

    Clk   <= not Clk after CLK_PERIOD / 2;
    Clk1M <= not Clk1M after CLK1M_HALF;

    process
        variable low_duration  : time;
        variable high_duration : time;
    begin
        -- Reset
        Reset <= '1';
        wait for 100 ns;
        Reset <= '0';
        wait for 100 ns;

        -- Verification etat initial
        assert DCC_Out = '0'
            report "ERREUR: DCC_Out devrait etre 0 apres reset"
            severity error;
        assert Fin = '0'
            report "ERREUR: Fin devrait etre 0 apres reset"
            severity error;

        -- Generation d'un bit 0
        wait until rising_edge(Clk);
        Go <= '1';
        t_start_low <= now;

        -- Attente phase haute
        wait until DCC_Out = '1';
        t_start_high <= now;
        low_duration := now - t_start_low;

        -- Verification duree phase basse (~100 us, tolerance 3 us)
        assert low_duration >= 97 us and low_duration <= 103 us
            report "ERREUR: Phase basse du bit 0 hors tolerance. Duree = " &
                   time'image(low_duration)
            severity error;

        -- Attente fin
        wait until Fin = '1';
        high_duration := now - t_start_high;

        -- Verification duree phase haute (~100 us, tolerance 3 us)
        assert high_duration >= 97 us and high_duration <= 103 us
            report "ERREUR: Phase haute du bit 0 hors tolerance. Duree = " &
                   time'image(high_duration)
            severity error;

        assert DCC_Out = '0'
            report "ERREUR: DCC_Out devrait etre 0 en etat DONE"
            severity error;

        -- Relachement
        Go <= '0';
        wait for 200 ns;

        assert Fin = '0'
            report "ERREUR: Fin devrait repasser a 0 apres Go = 0"
            severity error;

        report "*** TB_DCC_BIT_0: Tous les tests passes ***" severity note;
        wait;
    end process;

end Behavioral;
