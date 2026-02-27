----------------------------------------------------------------------------------
-- Testbench: TB_MAE
-- Verification de la machine a etats principale
-- On simule les signaux Fin_1, Fin_0 et Fin_Tempo pour verifier
-- le sequencement de la MAE
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_MAE is
end TB_MAE;

architecture Behavioral of TB_MAE is

    constant CLK_PERIOD : time := 10 ns;

    signal Clk          : STD_LOGIC := '0';
    signal Reset        : STD_LOGIC := '0';
    signal Bit_Courant  : STD_LOGIC := '1';  -- Simule le MSB du registre
    signal Fin_1        : STD_LOGIC := '0';
    signal Fin_0        : STD_LOGIC := '0';
    signal Fin_Tempo    : STD_LOGIC := '0';
    signal Go_1         : STD_LOGIC;
    signal Go_0         : STD_LOGIC;
    signal Start_Tempo  : STD_LOGIC;
    signal COM_REG      : STD_LOGIC_VECTOR(1 downto 0);

begin

    UUT: entity work.MAE
        port map (
            Clk         => Clk,
            Reset       => Reset,
            Bit_Courant => Bit_Courant,
            Fin_1       => Fin_1,
            Fin_0       => Fin_0,
            Fin_Tempo   => Fin_Tempo,
            Go_1        => Go_1,
            Go_0        => Go_0,
            Start_Tempo => Start_Tempo,
            COM_REG     => COM_REG
        );

    Clk <= not Clk after CLK_PERIOD / 2;

    process
    begin
        -- Reset
        Reset <= '1';
        wait for 50 ns;
        Reset <= '0';

        -- Apres reset: etat LOAD, COM_REG devrait etre "01" (chargement)
        wait until rising_edge(Clk);
        wait for 1 ns;
        assert COM_REG = "01"
            report "ERREUR: COM_REG devrait etre 01 (load) apres reset"
            severity error;

        -- Cycle suivant: etat SEND
        wait until rising_edge(Clk);
        wait for 1 ns;

        -- Bit_Courant = '1', donc on devrait aller vers SEND_1 puis WAIT_1
        -- Go_1 devrait passer a 1
        wait until rising_edge(Clk);  -- SEND -> SEND_1
        wait until rising_edge(Clk);  -- SEND_1 -> WAIT_1
        wait for 1 ns;
        assert Go_1 = '1'
            report "ERREUR: Go_1 devrait etre 1 pendant WAIT_1"
            severity error;
        assert Go_0 = '0'
            report "ERREUR: Go_0 devrait etre 0 quand on transmet un bit 1"
            severity error;

        -- Simuler la fin de transmission du bit 1
        wait for 100 ns;
        Fin_1 <= '1';
        wait until rising_edge(Clk);
        wait until rising_edge(Clk);  -- WAIT_1 -> SHIFT
        Fin_1 <= '0';
        wait for 1 ns;

        -- En etat SHIFT, COM_REG devrait etre "10"
        assert COM_REG = "10"
            report "ERREUR: COM_REG devrait etre 10 (shift) en etat SHIFT"
            severity error;

        -- Changer Bit_Courant a '0' pour tester le chemin bit 0
        Bit_Courant <= '0';
        wait until rising_edge(Clk);  -- SHIFT -> SEND
        wait until rising_edge(Clk);  -- SEND -> SEND_0
        wait until rising_edge(Clk);  -- SEND_0 -> WAIT_0
        wait for 1 ns;

        assert Go_0 = '1'
            report "ERREUR: Go_0 devrait etre 1 pendant WAIT_0"
            severity error;
        assert Go_1 = '0'
            report "ERREUR: Go_1 devrait etre 0 quand on transmet un bit 0"
            severity error;

        -- Simuler la fin du bit 0
        Fin_0 <= '1';
        wait until rising_edge(Clk);
        wait until rising_edge(Clk);
        Fin_0 <= '0';

        -- Simuler les 49 bits restants rapidement
        -- (bits 2 a 50, en alternant Fin_1 et Fin_0)
        for i in 2 to 50 loop
            -- En SEND, choisir le bon bit
            if i mod 2 = 0 then
                Bit_Courant <= '1';
            else
                Bit_Courant <= '0';
            end if;

            -- Attendre SEND -> SEND_x -> WAIT_x
            wait until rising_edge(Clk);  -- SEND
            wait until rising_edge(Clk);  -- SEND_x
            wait until rising_edge(Clk);  -- WAIT_x
            wait for 50 ns;

            -- Simuler fin du bit
            if i mod 2 = 0 then
                Fin_1 <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                Fin_1 <= '0';
            else
                Fin_0 <= '1';
                wait until rising_edge(Clk);
                wait until rising_edge(Clk);
                Fin_0 <= '0';
            end if;
        end loop;

        -- Apres 51 bits: on devrait etre en START_TEMP -> WAIT_TEMP
        wait until rising_edge(Clk);
        wait for 1 ns;
        assert Start_Tempo = '1'
            report "ERREUR: Start_Tempo devrait etre 1 apres envoi des 51 bits"
            severity error;

        -- Simuler fin de tempo
        wait for 200 ns;
        Fin_Tempo <= '1';
        wait until rising_edge(Clk);
        wait until rising_edge(Clk);
        Fin_Tempo <= '0';
        wait for 1 ns;

        -- Devrait revenir a LOAD
        assert COM_REG = "01"
            report "ERREUR: COM_REG devrait etre 01 (load) apres fin tempo"
            severity error;

        report "*** TB_MAE: Tous les tests passes ***" severity note;
        wait;
    end process;

end Behavioral;
