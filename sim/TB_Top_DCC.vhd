----------------------------------------------------------------------------------
-- Testbench: TB_TOP_DCC
-- Verification du systeme complet de la Centrale DCC
-- Simule l'envoi d'une trame complete (train arret, puis marche avant)
-- et verifie le signal DCC en sortie
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_TOP_DCC is
end TB_TOP_DCC;

architecture Behavioral of TB_TOP_DCC is

    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz

    signal Clk_100MHz   : STD_LOGIC := '0';
    signal Reset        : STD_LOGIC := '0';
    signal Interrupteur : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal Sortie_DCC   : STD_LOGIC;

    -- Compteurs pour mesurer les durees des bits DCC
    signal bit_count      : INTEGER := 0;
    signal last_transition : time := 0 ns;

begin

    UUT: entity work.TOP_DCC
        port map (
            Clk_100MHz   => Clk_100MHz,
            Reset        => Reset,
            Interrupteur => Interrupteur,
            Sortie_DCC   => Sortie_DCC
        );

    -- Horloge 100 MHz
    Clk_100MHz <= not Clk_100MHz after CLK_PERIOD / 2;

    -- Processus de test principal
    process
        variable t_rise   : time;
        variable t_fall   : time;
        variable low_dur  : time;
        variable high_dur : time;
    begin
        -- Reset du systeme
        Reset <= '1';
        Interrupteur <= (others => '0');  -- Trame d'arret par defaut
        wait for 500 ns;
        Reset <= '0';

        -- Verification: apres reset, Sortie_DCC devrait etre 0
        wait for 100 ns;
        assert Sortie_DCC = '0'
            report "ERREUR: Sortie_DCC devrait etre 0 juste apres reset"
            severity error;

        -- Attendre le debut de la premiere trame (premier front montant de la sortie)
        -- Le preambule commence par des bits '1' (58us bas + 58us haut)
        wait until rising_edge(Sortie_DCC);
        report "Premier front montant detecte: debut de la trame DCC" severity note;

        -- Mesurer un bit '1' du preambule
        t_rise := now;
        wait until falling_edge(Sortie_DCC);
        high_dur := now - t_rise;

        -- La phase haute d'un bit '1' doit durer ~58us
        assert high_dur >= 55 us and high_dur <= 61 us
            report "ERREUR: Phase haute du bit 1 du preambule hors tolerance. Duree = " &
                   time'image(high_dur)
            severity error;

        -- Mesurer la phase basse suivante (debut du bit suivant)
        t_fall := now;
        wait until rising_edge(Sortie_DCC);
        low_dur := now - t_fall;

        -- La phase basse d'un bit '1' doit durer ~58us
        assert low_dur >= 55 us and low_dur <= 61 us
            report "ERREUR: Phase basse du bit 1 du preambule hors tolerance. Duree = " &
                   time'image(low_dur)
            severity error;

        report "Timing du preambule verifie (bit 1 DCC)" severity note;

        -- Attendre la fin de la trame complete
        -- 51 bits, chaque bit entre 116us et 200us => max ~10.2 ms
        -- Plus la tempo de 6ms => une trame complete prend ~16ms max
        wait for 20 ms;

        -- Changer la commande: marche avant (SW7)
        Interrupteur <= "10000000";
        report "Commande changee: marche avant (SW7)" severity note;

        -- Attendre que la nouvelle trame soit chargee et transmise
        -- (au plus tard apres la tempo en cours + nouvelle trame)
        wait for 20 ms;

        -- Verifier que le signal DCC est toujours actif (le systeme tourne)
        -- On attend un front montant pour confirmer l'activite
        wait until rising_edge(Sortie_DCC) for 15 ms;
        assert Sortie_DCC = '1'
            report "ERREUR: Le systeme DCC ne genere plus de signal apres changement de commande"
            severity error;

        report "*** TB_TOP_DCC: Tests systeme complet passes ***" severity note;
        report "Note: verifier visuellement les trames dans le chronogramme" severity note;
        wait;
    end process;

    -- Processus de comptage des transitions (pour debug)
    process
    begin
        wait until Sortie_DCC'event;
        if Reset = '0' then
            bit_count <= bit_count + 1;
            last_transition <= now;
        end if;
    end process;

end Behavioral;
