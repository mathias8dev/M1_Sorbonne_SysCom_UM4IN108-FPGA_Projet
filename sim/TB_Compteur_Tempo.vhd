----------------------------------------------------------------------------------
-- Testbench: TB_COMPTEUR_TEMPO
-- Verification du compteur de temporisation 6 ms
--
-- Tests effectues :
--   1. Reset asynchrone : Fin_Tempo = '0'
--   2. Temporisation de 6 ms (6000 coups de Clk1M)
--   3. Fin_Tempo reste a '1' tant que Start_Tempo est actif
--   4. Fin_Tempo repasse a '0' des que Start_Tempo repasse a '0'
--   5. Deuxieme temporisation pour verifier la repetabilite
--   6. Reset pendant une temporisation en cours
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_COMPTEUR_TEMPO is
end TB_COMPTEUR_TEMPO;

architecture Behavioral of TB_COMPTEUR_TEMPO is

    constant CLK_PERIOD   : time := 10 ns;    -- 100 MHz
    constant CLK1M_HALF   : time := 500 ns;   -- 1 MHz (demi-periode)

    signal Clk         : STD_LOGIC := '0';
    signal Clk1M       : STD_LOGIC := '0';
    signal Reset       : STD_LOGIC := '0';
    signal Start_Tempo : STD_LOGIC := '0';
    signal Fin_Tempo   : STD_LOGIC;

    signal t_start     : time := 0 ns;

begin

    -- Instance du module sous test
    UUT: entity work.COMPTEUR_TEMPO
        port map (
            Clk         => Clk,
            Reset       => Reset,
            Clk1M       => Clk1M,
            Start_Tempo => Start_Tempo,
            Fin_Tempo   => Fin_Tempo
        );

    -- Horloge 100 MHz
    Clk <= not Clk after CLK_PERIOD / 2;

    -- Horloge 1 MHz
    Clk1M <= not Clk1M after CLK1M_HALF;

    -- Processus de test
    process
        variable tempo_duration : time;
    begin
        -----------------------------------------------------------------------
        -- Test 1 : Reset asynchrone
        -----------------------------------------------------------------------
        Reset <= '1';
        wait for 100 ns;
        assert Fin_Tempo = '0'
            report "ERREUR: Fin_Tempo devrait etre 0 apres reset"
            severity error;

        Reset <= '0';
        wait for 200 ns;

        -----------------------------------------------------------------------
        -- Test 2 : Temporisation de 6 ms
        -- Le sequenceur detecte le front montant de Start_Tempo sur Clk (100MHz).
        -- Le compteur compte 6000 coups de Clk1M (0 a 5999).
        -- Duree attendue : ~6 ms (tolerance liee a la synchro entre domaines)
        -----------------------------------------------------------------------
        wait until rising_edge(Clk);
        Start_Tempo <= '1';
        t_start <= now;

        -- Verifier que Fin_Tempo ne passe pas a '1' avant ~5.9 ms
        wait for 5900 us;
        assert Fin_Tempo = '0'
            report "ERREUR: Fin_Tempo est passe a 1 trop tot (avant 5.9 ms)"
            severity error;

        -- Attente de Fin_Tempo
        wait until Fin_Tempo = '1';
        tempo_duration := now - t_start;

        -- Verification de la duree (6 ms, tolerance +/- 10 us pour synchro)
        assert tempo_duration >= 5990 us and tempo_duration <= 6010 us
            report "ERREUR: Temporisation hors tolerance. Duree = " &
                   time'image(tempo_duration) & " (attendu ~6 ms)"
            severity error;

        -----------------------------------------------------------------------
        -- Test 3 : Fin_Tempo reste a '1' tant que Start_Tempo = '1'
        -----------------------------------------------------------------------
        wait for 50 us;
        assert Fin_Tempo = '1'
            report "ERREUR: Fin_Tempo devrait rester a 1 tant que Start_Tempo est actif"
            severity error;

        -----------------------------------------------------------------------
        -- Test 4 : Fin_Tempo repasse a '0' quand Start_Tempo repasse a '0'
        -----------------------------------------------------------------------
        wait until rising_edge(Clk);
        Start_Tempo <= '0';

        -- Attendre quelques cycles pour la detection du retour a 0
        wait for 200 ns;
        assert Fin_Tempo = '0'
            report "ERREUR: Fin_Tempo devrait repasser a 0 apres Start_Tempo = 0"
            severity error;

        -----------------------------------------------------------------------
        -- Test 5 : Deuxieme temporisation (repetabilite)
        -----------------------------------------------------------------------
        wait for 1 us;
        wait until rising_edge(Clk);
        Start_Tempo <= '1';
        t_start <= now;

        wait until Fin_Tempo = '1';
        tempo_duration := now - t_start;

        assert tempo_duration >= 5990 us and tempo_duration <= 6010 us
            report "ERREUR: 2eme temporisation hors tolerance. Duree = " &
                   time'image(tempo_duration)
            severity error;

        Start_Tempo <= '0';
        wait for 200 ns;

        assert Fin_Tempo = '0'
            report "ERREUR: Fin_Tempo devrait etre 0 apres 2eme temporisation"
            severity error;

        -----------------------------------------------------------------------
        -- Test 6 : Reset pendant une temporisation en cours
        -----------------------------------------------------------------------
        wait for 1 us;
        wait until rising_edge(Clk);
        Start_Tempo <= '1';
        wait for 3000 us;  -- Milieu de la temporisation

        assert Fin_Tempo = '0'
            report "ERREUR: Fin_Tempo devrait etre 0 a mi-parcours"
            severity error;

        -- Reset asynchrone
        Reset <= '1';
        wait for 100 ns;
        assert Fin_Tempo = '0'
            report "ERREUR: Fin_Tempo devrait etre 0 apres reset mid-tempo"
            severity error;

        Reset <= '0';
        Start_Tempo <= '0';
        wait for 200 ns;

        -- Relancer et verifier que ca refonctionne
        wait until rising_edge(Clk);
        Start_Tempo <= '1';
        t_start <= now;

        wait until Fin_Tempo = '1';
        tempo_duration := now - t_start;

        assert tempo_duration >= 5990 us and tempo_duration <= 6010 us
            report "ERREUR: Temporisation apres reset hors tolerance. Duree = " &
                   time'image(tempo_duration)
            severity error;

        Start_Tempo <= '0';
        wait for 200 ns;

        report "*** TB_COMPTEUR_TEMPO: Tous les tests passes ***" severity note;
        wait;
    end process;

end Behavioral;
