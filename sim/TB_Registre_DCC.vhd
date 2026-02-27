----------------------------------------------------------------------------------
-- Testbench: TB_REGISTRE_DCC
-- Verification du registre a decalage 51 bits
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_REGISTRE_DCC is
end TB_REGISTRE_DCC;

architecture Behavioral of TB_REGISTRE_DCC is

    constant CLK_PERIOD : time := 10 ns;

    signal Clk         : STD_LOGIC := '0';
    signal Reset       : STD_LOGIC := '0';
    signal COM_REG     : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal Trame_DCC   : STD_LOGIC_VECTOR(50 downto 0);
    signal Bit_Courant : STD_LOGIC;

    -- Trame de test: alternance 1/0 pour verification facile
    constant TRAME_TEST : STD_LOGIC_VECTOR(50 downto 0) :=
        "101010101010101010101010101010101010101010101010101";

begin

    UUT: entity work.REGISTRE_DCC
        port map (
            Clk         => Clk,
            Reset       => Reset,
            COM_REG     => COM_REG,
            Trame_DCC   => Trame_DCC,
            Bit_Courant => Bit_Courant
        );

    Clk <= not Clk after CLK_PERIOD / 2;

    process
    begin
        -- Reset
        Reset <= '1';
        Trame_DCC <= TRAME_TEST;
        wait for 50 ns;
        Reset <= '0';
        wait for 20 ns;

        -- Apres reset, le registre est tout a 1, donc Bit_Courant = '1'
        assert Bit_Courant = '1'
            report "ERREUR: Bit_Courant devrait etre 1 apres reset (registre tout a 1)"
            severity error;

        -- Chargement de la trame de test
        wait until rising_edge(Clk);
        COM_REG <= "01";  -- Load
        wait until rising_edge(Clk);
        COM_REG <= "00";  -- Hold
        wait for 5 ns;

        -- Verification: MSB de TRAME_TEST = '1'
        assert Bit_Courant = '1'
            report "ERREUR: Bit_Courant devrait etre 1 apres chargement (MSB=1)"
            severity error;

        -- Premier decalage: le nouveau MSB devrait etre '0'
        wait until rising_edge(Clk);
        COM_REG <= "10";  -- Shift
        wait until rising_edge(Clk);
        COM_REG <= "00";  -- Hold
        wait for 5 ns;

        assert Bit_Courant = '0'
            report "ERREUR: Bit_Courant devrait etre 0 apres 1er decalage"
            severity error;

        -- Deuxieme decalage: le MSB devrait etre '1'
        wait until rising_edge(Clk);
        COM_REG <= "10";  -- Shift
        wait until rising_edge(Clk);
        COM_REG <= "00";  -- Hold
        wait for 5 ns;

        assert Bit_Courant = '1'
            report "ERREUR: Bit_Courant devrait etre 1 apres 2eme decalage"
            severity error;

        -- Verification du maintien (hold)
        wait for 100 ns;
        assert Bit_Courant = '1'
            report "ERREUR: Bit_Courant ne devrait pas changer en mode maintien"
            severity error;

        -- Test avec une trame DCC reelle (arret train 3)
        -- Preambule(23) + 0 + addr(8) + 0 + cmd(8) + 0 + ctrl(8) + 1
        Trame_DCC <= "11111111111111111111111" & "0" & "00000011" & "0"
                   & "01100000" & "0" & "01100011" & "1";
        wait until rising_edge(Clk);
        COM_REG <= "01";  -- Load
        wait until rising_edge(Clk);
        COM_REG <= "00";
        wait for 5 ns;

        -- MSB doit etre '1' (debut du preambule)
        assert Bit_Courant = '1'
            report "ERREUR: Premier bit du preambule devrait etre 1"
            severity error;

        -- Decaler 23 fois pour atteindre le start bit
        for i in 0 to 22 loop
            wait until rising_edge(Clk);
            COM_REG <= "10";
            wait until rising_edge(Clk);
            COM_REG <= "00";
        end loop;
        wait for 5 ns;

        -- Bit 27 (index 50-23=27) devrait etre '0' (start bit)
        assert Bit_Courant = '0'
            report "ERREUR: Start bit apres preambule devrait etre 0"
            severity error;

        report "*** TB_REGISTRE_DCC: Tous les tests passes ***" severity note;
        wait;
    end process;

end Behavioral;
