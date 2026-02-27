----------------------------------------------------------------------------------
-- Testbench: TB_DIVISEUR_HORLOGE
-- Verification du diviseur d'horloge 100 MHz -> 1 MHz
--
-- Tests effectues :
--   1. Reset asynchrone : Clk_Out = '0' pendant le reset
--   2. Periode de sortie : 1 us (500 ns bas + 500 ns haut)
--   3. Rapport cyclique 50%
--   4. Stabilite sur plusieurs periodes
--   5. Re-reset en cours de fonctionnement
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_DIVISEUR_HORLOGE is
end TB_DIVISEUR_HORLOGE;

architecture Behavioral of TB_DIVISEUR_HORLOGE is

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz

    signal Clk_In  : STD_LOGIC := '0';
    signal Reset   : STD_LOGIC := '0';
    signal Clk_Out : STD_LOGIC;

begin

    -- Instance du module sous test
    UUT: entity work.CLK_DIV
        port map (
            Reset   => Reset,
            Clk_In  => Clk_In,
            Clk_Out => Clk_Out
        );

    -- Horloge 100 MHz
    Clk_In <= not Clk_In after CLK_PERIOD / 2;

    -- Processus de test
    process
        variable t_rising  : time;
        variable t_falling : time;
        variable half_high : time;
        variable half_low  : time;
        variable full_period : time;
    begin
        -----------------------------------------------------------------------
        -- Test 1 : Reset asynchrone
        -----------------------------------------------------------------------
        Reset <= '1';
        wait for 100 ns;
        assert Clk_Out = '0'
            report "ERREUR: Clk_Out devrait etre 0 pendant le reset"
            severity error;

        Reset <= '0';
        wait for 50 ns;  -- Synchro apres release du reset

        -----------------------------------------------------------------------
        -- Test 2 : Mesure de la premiere demi-periode (phase basse -> montante)
        -- Apres reset, Clk_Out = '0'. Premiere transition montante apres 50 cycles.
        -----------------------------------------------------------------------
        wait until rising_edge(Clk_Out);
        t_rising := now;

        -- Mesure de la demi-periode haute
        wait until falling_edge(Clk_Out);
        t_falling := now;
        half_high := t_falling - t_rising;

        assert half_high = 500 ns
            report "ERREUR: Demi-periode haute attendue 500 ns, obtenue " &
                   time'image(half_high)
            severity error;

        -- Mesure de la demi-periode basse
        wait until rising_edge(Clk_Out);
        half_low := now - t_falling;

        assert half_low = 500 ns
            report "ERREUR: Demi-periode basse attendue 500 ns, obtenue " &
                   time'image(half_low)
            severity error;

        -----------------------------------------------------------------------
        -- Test 3 : Verification de la periode complete (1 us) sur 5 periodes
        -----------------------------------------------------------------------
        for i in 1 to 5 loop
            t_rising := now;
            wait until rising_edge(Clk_Out);
            full_period := now - t_rising;

            assert full_period = 1000 ns
                report "ERREUR: Periode complete attendue 1000 ns, obtenue " &
                       time'image(full_period) & " (iteration " &
                       integer'image(i) & ")"
                severity error;
        end loop;

        -----------------------------------------------------------------------
        -- Test 4 : Re-reset en cours de fonctionnement
        -----------------------------------------------------------------------
        -- Attendre d'etre en phase haute
        wait until rising_edge(Clk_Out);
        wait for 200 ns;  -- Milieu de la phase haute
        assert Clk_Out = '1'
            report "ERREUR: Clk_Out devrait etre 1 en phase haute"
            severity error;

        -- Appliquer le reset
        Reset <= '1';
        wait for 30 ns;  -- Reset asynchrone, agit immediatement
        assert Clk_Out = '0'
            report "ERREUR: Clk_Out devrait etre 0 immediatement apres re-reset"
            severity error;

        -- Relacher et verifier que la sortie reprend normalement
        wait for 70 ns;
        Reset <= '0';

        -- Attendre une periode complete et verifier
        wait until rising_edge(Clk_Out);
        t_rising := now;
        wait until rising_edge(Clk_Out);
        full_period := now - t_rising;

        assert full_period = 1000 ns
            report "ERREUR: Periode apres re-reset attendue 1000 ns, obtenue " &
                   time'image(full_period)
            severity error;

        -----------------------------------------------------------------------
        -- Test 5 : Verification que la frequence est stable (10 periodes supplementaires)
        -----------------------------------------------------------------------
        for i in 1 to 10 loop
            t_rising := now;
            wait until rising_edge(Clk_Out);
            full_period := now - t_rising;

            assert full_period = 1000 ns
                report "ERREUR: Periode instable a l'iteration " &
                       integer'image(i) & ", obtenue " &
                       time'image(full_period)
                severity error;
        end loop;

        report "*** TB_DIVISEUR_HORLOGE: Tous les tests passes ***" severity note;
        wait;
    end process;

end Behavioral;
