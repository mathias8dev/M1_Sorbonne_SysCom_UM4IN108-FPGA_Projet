----------------------------------------------------------------------------------
-- Testbench: TB_GENERATEUR_TRAMES
-- Verification du generateur de trames DCC de test
--
-- Tests effectues :
--   1. Trame par defaut (aucun interrupteur) : arret train 3
--   2. SW7 : marche avant step 10
--   3. SW6 : marche arriere step 10
--   4. SW5 : phares ON (F0)
--   5. SW4 : phares OFF
--   6. SW3 : klaxon ON (F11)
--   7. SW2 : klaxon OFF
--   8. SW1 : annonce SNCF ON (F13, trame 2 octets)
--   9. SW0 : annonce SNCF OFF (F13, trame 2 octets)
--  10. Verification de la priorite (SW7 > SW6 > ... > SW0)
--  11. Verification du preambule (23 bits pour 1 octet, 14 bits pour 2 octets)
--  12. Verification du champ controle (XOR adresse ^ commande(s))
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TB_GENERATEUR_TRAMES is
end TB_GENERATEUR_TRAMES;

architecture Behavioral of TB_GENERATEUR_TRAMES is

    signal Interrupteur : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal Trame_DCC    : STD_LOGIC_VECTOR(50 downto 0);

    -- Constantes : trames attendues
    -- Train adresse 3 = 00000011

    -- Preambule 23 bits de '1'
    constant PREAMBLE_23 : STD_LOGIC_VECTOR(22 downto 0) := (others => '1');
    -- Preambule 14 bits de '1'
    constant PREAMBLE_14 : STD_LOGIC_VECTOR(13 downto 0) := (others => '1');
    -- Adresse
    constant ADDR_3      : STD_LOGIC_VECTOR(7 downto 0)  := "00000011";

    -- Fonction utilitaire : construit une trame 1 octet de commande (51 bits)
    -- Format : [23x'1'][0][addr][0][cmd][0][ctrl][1]
    function build_1byte(addr : STD_LOGIC_VECTOR(7 downto 0);
                         cmd  : STD_LOGIC_VECTOR(7 downto 0))
        return STD_LOGIC_VECTOR is
        variable ctrl : STD_LOGIC_VECTOR(7 downto 0);
    begin
        ctrl := addr xor cmd;
        return PREAMBLE_23 & "0" & addr & "0" & cmd & "0" & ctrl & "1";
    end function;

    -- Fonction utilitaire : construit une trame 2 octets de commande (51 bits)
    -- Format : [14x'1'][0][addr][0][cmd1][0][cmd2][0][ctrl][1]
    function build_2bytes(addr : STD_LOGIC_VECTOR(7 downto 0);
                          cmd1 : STD_LOGIC_VECTOR(7 downto 0);
                          cmd2 : STD_LOGIC_VECTOR(7 downto 0))
        return STD_LOGIC_VECTOR is
        variable ctrl : STD_LOGIC_VECTOR(7 downto 0);
    begin
        ctrl := addr xor cmd1 xor cmd2;
        return PREAMBLE_14 & "0" & addr & "0" & cmd1 & "0" & cmd2 & "0" & ctrl & "1";
    end function;

    -- Trames de reference
    constant TRAME_STOP     : STD_LOGIC_VECTOR(50 downto 0) := build_1byte(ADDR_3, "01100000");
    constant TRAME_FWD10    : STD_LOGIC_VECTOR(50 downto 0) := build_1byte(ADDR_3, "01110110");
    constant TRAME_REV10    : STD_LOGIC_VECTOR(50 downto 0) := build_1byte(ADDR_3, "01010110");
    constant TRAME_LIGHT_ON : STD_LOGIC_VECTOR(50 downto 0) := build_1byte(ADDR_3, "10010000");
    constant TRAME_LIGHT_OFF: STD_LOGIC_VECTOR(50 downto 0) := build_1byte(ADDR_3, "10000000");
    constant TRAME_HORN_ON  : STD_LOGIC_VECTOR(50 downto 0) := build_1byte(ADDR_3, "10100100");
    constant TRAME_HORN_OFF : STD_LOGIC_VECTOR(50 downto 0) := build_1byte(ADDR_3, "10100000");
    constant TRAME_F13_ON   : STD_LOGIC_VECTOR(50 downto 0) := build_2bytes(ADDR_3, "11011110", "00000001");
    constant TRAME_F13_OFF  : STD_LOGIC_VECTOR(50 downto 0) := build_2bytes(ADDR_3, "11011110", "00000000");

    -- Procedure pour verifier une trame
    procedure check_trame(
        signal   sw      : out STD_LOGIC_VECTOR(7 downto 0);
        constant sw_val  : in  STD_LOGIC_VECTOR(7 downto 0);
        signal   trame   : in  STD_LOGIC_VECTOR(50 downto 0);
        constant expected: in  STD_LOGIC_VECTOR(50 downto 0);
        constant name    : in  string
    ) is
    begin
        sw <= sw_val;
        wait for 10 ns;  -- Laisser le process combinatoire reagir
        assert trame = expected
            report "ERREUR " & name & ": trame incorrecte"
            severity error;
    end procedure;

begin

    -- Instance du module sous test
    UUT: entity work.DCC_FRAME_GENERATOR
        port map (
            Interrupteur => Interrupteur,
            Trame_DCC    => Trame_DCC
        );

    -- Processus de test
    process
    begin
        -----------------------------------------------------------------------
        -- Test 1 : Trame par defaut (arret)
        -----------------------------------------------------------------------
        Interrupteur <= "00000000";
        wait for 10 ns;
        assert Trame_DCC = TRAME_STOP
            report "ERREUR Test 1: Trame arret incorrecte"
            severity error;

        -- Verification du preambule 23 bits
        assert Trame_DCC(50 downto 28) = PREAMBLE_23
            report "ERREUR Test 1: Preambule 23 bits incorrect"
            severity error;

        -- Verification du start bit apres preambule
        assert Trame_DCC(27) = '0'
            report "ERREUR Test 1: Start bit manquant apres preambule"
            severity error;

        -- Verification du stop bit
        assert Trame_DCC(0) = '1'
            report "ERREUR Test 1: Stop bit incorrect"
            severity error;

        -- Verification du champ adresse
        assert Trame_DCC(26 downto 19) = ADDR_3
            report "ERREUR Test 1: Champ adresse incorrect"
            severity error;

        -- Verification du champ controle (XOR)
        assert Trame_DCC(8 downto 1) = (ADDR_3 xor "01100000")
            report "ERREUR Test 1: Champ controle XOR incorrect"
            severity error;

        -----------------------------------------------------------------------
        -- Test 2 : SW7 = marche avant step 10
        -----------------------------------------------------------------------
        check_trame(Interrupteur, "10000000", Trame_DCC, TRAME_FWD10, "Test 2 (SW7 fwd)");

        -----------------------------------------------------------------------
        -- Test 3 : SW6 = marche arriere step 10
        -----------------------------------------------------------------------
        check_trame(Interrupteur, "01000000", Trame_DCC, TRAME_REV10, "Test 3 (SW6 rev)");

        -----------------------------------------------------------------------
        -- Test 4 : SW5 = phares ON
        -----------------------------------------------------------------------
        check_trame(Interrupteur, "00100000", Trame_DCC, TRAME_LIGHT_ON, "Test 4 (SW5 phares ON)");

        -----------------------------------------------------------------------
        -- Test 5 : SW4 = phares OFF
        -----------------------------------------------------------------------
        check_trame(Interrupteur, "00010000", Trame_DCC, TRAME_LIGHT_OFF, "Test 5 (SW4 phares OFF)");

        -----------------------------------------------------------------------
        -- Test 6 : SW3 = klaxon ON (F11)
        -----------------------------------------------------------------------
        check_trame(Interrupteur, "00001000", Trame_DCC, TRAME_HORN_ON, "Test 6 (SW3 klaxon ON)");

        -----------------------------------------------------------------------
        -- Test 7 : SW2 = klaxon OFF
        -----------------------------------------------------------------------
        check_trame(Interrupteur, "00000100", Trame_DCC, TRAME_HORN_OFF, "Test 7 (SW2 klaxon OFF)");

        -----------------------------------------------------------------------
        -- Test 8 : SW1 = annonce SNCF ON (F13, trame 2 octets)
        -----------------------------------------------------------------------
        Interrupteur <= "00000010";
        wait for 10 ns;
        assert Trame_DCC = TRAME_F13_ON
            report "ERREUR Test 8 (SW1 F13 ON): trame incorrecte"
            severity error;

        -- Verification du preambule 14 bits (trame 2 octets)
        assert Trame_DCC(50 downto 37) = PREAMBLE_14
            report "ERREUR Test 8: Preambule 14 bits incorrect pour trame 2 octets"
            severity error;

        -- Verification du stop bit
        assert Trame_DCC(0) = '1'
            report "ERREUR Test 8: Stop bit incorrect"
            severity error;

        -- Verification du champ controle (XOR addr ^ cmd1 ^ cmd2)
        assert Trame_DCC(8 downto 1) = (ADDR_3 xor "11011110" xor "00000001")
            report "ERREUR Test 8: Champ controle XOR incorrect pour trame 2 octets"
            severity error;

        -----------------------------------------------------------------------
        -- Test 9 : SW0 = annonce SNCF OFF (F13, trame 2 octets)
        -----------------------------------------------------------------------
        Interrupteur <= "00000001";
        wait for 10 ns;
        assert Trame_DCC = TRAME_F13_OFF
            report "ERREUR Test 9 (SW0 F13 OFF): trame incorrecte"
            severity error;

        assert Trame_DCC(8 downto 1) = (ADDR_3 xor "11011110" xor "00000000")
            report "ERREUR Test 9: Champ controle XOR incorrect"
            severity error;

        -----------------------------------------------------------------------
        -- Test 10 : Verification de la priorite (SW7 > SW6 > ... > SW0)
        -- Quand SW7 et SW6 sont actifs, SW7 doit l'emporter
        -----------------------------------------------------------------------
        Interrupteur <= "11000000";  -- SW7 + SW6
        wait for 10 ns;
        assert Trame_DCC = TRAME_FWD10
            report "ERREUR Test 10a: Priorite SW7 non respectee (SW7+SW6)"
            severity error;

        Interrupteur <= "01100000";  -- SW6 + SW5
        wait for 10 ns;
        assert Trame_DCC = TRAME_REV10
            report "ERREUR Test 10b: Priorite SW6 non respectee (SW6+SW5)"
            severity error;

        Interrupteur <= "00110000";  -- SW5 + SW4
        wait for 10 ns;
        assert Trame_DCC = TRAME_LIGHT_ON
            report "ERREUR Test 10c: Priorite SW5 non respectee (SW5+SW4)"
            severity error;

        Interrupteur <= "00011000";  -- SW4 + SW3
        wait for 10 ns;
        assert Trame_DCC = TRAME_LIGHT_OFF
            report "ERREUR Test 10d: Priorite SW4 non respectee (SW4+SW3)"
            severity error;

        Interrupteur <= "00001100";  -- SW3 + SW2
        wait for 10 ns;
        assert Trame_DCC = TRAME_HORN_ON
            report "ERREUR Test 10e: Priorite SW3 non respectee (SW3+SW2)"
            severity error;

        Interrupteur <= "00000110";  -- SW2 + SW1
        wait for 10 ns;
        assert Trame_DCC = TRAME_HORN_OFF
            report "ERREUR Test 10f: Priorite SW2 non respectee (SW2+SW1)"
            severity error;

        Interrupteur <= "00000011";  -- SW1 + SW0
        wait for 10 ns;
        assert Trame_DCC = TRAME_F13_ON
            report "ERREUR Test 10g: Priorite SW1 non respectee (SW1+SW0)"
            severity error;

        -- Tous les interrupteurs actifs : SW7 doit l'emporter
        Interrupteur <= "11111111";
        wait for 10 ns;
        assert Trame_DCC = TRAME_FWD10
            report "ERREUR Test 10h: Priorite SW7 non respectee (tous actifs)"
            severity error;

        -----------------------------------------------------------------------
        -- Test 11 : Verification de la structure des trames
        -- Tous les start bits doivent etre a '0' et le stop bit a '1'
        -----------------------------------------------------------------------
        -- Trame 1 octet : bits 27, 18, 9 = start bits ; bit 0 = stop bit
        Interrupteur <= "10000000";  -- SW7
        wait for 10 ns;
        assert Trame_DCC(27) = '0'
            report "ERREUR Test 11: Start bit 1 incorrect (1 octet)"
            severity error;
        assert Trame_DCC(18) = '0'
            report "ERREUR Test 11: Start bit 2 incorrect (1 octet)"
            severity error;
        assert Trame_DCC(9) = '0'
            report "ERREUR Test 11: Start bit 3 incorrect (1 octet)"
            severity error;
        assert Trame_DCC(0) = '1'
            report "ERREUR Test 11: Stop bit incorrect (1 octet)"
            severity error;

        -- Trame 2 octets : bits 36, 27, 18, 9 = start bits ; bit 0 = stop bit
        Interrupteur <= "00000010";  -- SW1
        wait for 10 ns;
        assert Trame_DCC(36) = '0'
            report "ERREUR Test 11: Start bit 1 incorrect (2 octets)"
            severity error;
        assert Trame_DCC(27) = '0'
            report "ERREUR Test 11: Start bit 2 incorrect (2 octets)"
            severity error;
        assert Trame_DCC(18) = '0'
            report "ERREUR Test 11: Start bit 3 incorrect (2 octets)"
            severity error;
        assert Trame_DCC(9) = '0'
            report "ERREUR Test 11: Start bit 4 incorrect (2 octets)"
            severity error;
        assert Trame_DCC(0) = '1'
            report "ERREUR Test 11: Stop bit incorrect (2 octets)"
            severity error;

        -----------------------------------------------------------------------
        report "*** TB_GENERATEUR_TRAMES: Tous les tests passes ***" severity note;
        wait;
    end process;

end Behavioral;
