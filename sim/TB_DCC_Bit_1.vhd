----------------------------------------------------------------------------------
-- Testbench: TB_DCC_BIT_1
-- Verification du generateur de bit DCC 1 (58us + 58us)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_DCC_BIT_1 is
end TB_DCC_BIT_1;

architecture Behavioral of TB_DCC_BIT_1 is

    -- Constantes
    constant CLK_PERIOD   : time := 10 ns;   -- 100 MHz
    constant CLK1M_HALF   : time := 500 ns;  -- 1 MHz (half period)

    -- Signaux
    signal Clk      : STD_LOGIC := '0';
    signal Clk1M    : STD_LOGIC := '0';
    signal Reset    : STD_LOGIC := '0';
    signal Go       : STD_LOGIC := '0';
    signal Fin      : STD_LOGIC;
    signal DCC_Out  : STD_LOGIC;

    -- Pour mesurer les durees
    signal t_start_low  : time := 0 ns;
    signal t_start_high : time := 0 ns;
    signal t_end_high   : time := 0 ns;

begin

    -- Instance du module sous test
    UUT: entity work.DCC_BIT_1
        port map (
            Clk     => Clk,
            Clk1M   => Clk1M,
            Reset   => Reset,
            Go      => Go,
            Fin     => Fin,
            DCC_Out => DCC_Out
        );

    -- Generation de l'horloge 100 MHz
    Clk <= not Clk after CLK_PERIOD / 2;

    -- Generation de l'horloge 1 MHz
    Clk1M <= not Clk1M after CLK1M_HALF;

    -- Processus de test
    process
        variable low_duration  : time;
        variable high_duration : time;
    begin
        -- Reset initial
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

        -- Lancement de la generation d'un bit 1
        wait until rising_edge(Clk);
        Go <= '1';
        t_start_low <= now;

        -- Attente de la phase haute (transition de DCC_Out de 0 a 1)
        wait until DCC_Out = '1';
        t_start_high <= now;
        low_duration := now - t_start_low;

        -- Verification de la duree de la phase basse (~58 us, tolerance 3 us)
        assert low_duration >= 55 us and low_duration <= 61 us
            report "ERREUR: Phase basse du bit 1 hors tolerance. Duree = " &
                   time'image(low_duration)
            severity error;

        -- Attente de la fin (Fin = '1')
        wait until Fin = '1';
        t_end_high <= now;
        high_duration := now - t_start_high;

        -- Verification que DCC_Out repasse a 0 en etat DONE
        assert DCC_Out = '0'
            report "ERREUR: DCC_Out devrait etre 0 en etat DONE"
            severity error;

        -- Verification de la duree de la phase haute (~58 us, tolerance 3 us)
        assert high_duration >= 55 us and high_duration <= 61 us
            report "ERREUR: Phase haute du bit 1 hors tolerance. Duree = " &
                   time'image(high_duration)
            severity error;

        -- Verification que Fin reste a 1 tant que Go est a 1
        wait for 1 us;
        assert Fin = '1'
            report "ERREUR: Fin devrait rester a 1 tant que Go est actif"
            severity error;

        -- Relachement de Go
        Go <= '0';
        wait for 200 ns;

        -- Verification retour a l'etat idle
        assert Fin = '0'
            report "ERREUR: Fin devrait repasser a 0 apres Go = 0"
            severity error;
        assert DCC_Out = '0'
            report "ERREUR: DCC_Out devrait etre 0 en idle"
            severity error;

        -- Test d'un second bit pour verifier le fonctionnement repetitif
        wait for 1 us;
        Go <= '1';
        wait until Fin = '1';
        assert DCC_Out = '0'
            report "ERREUR: DCC_Out devrait etre 0 en DONE (2eme bit)"
            severity error;
        Go <= '0';
        wait for 200 ns;

        report "*** TB_DCC_BIT_1: Tous les tests passes ***" severity note;
        wait;
    end process;

end Behavioral;
