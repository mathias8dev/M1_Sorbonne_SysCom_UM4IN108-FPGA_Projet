----------------------------------------------------------------------------------
-- Company: SORBONNE UNIVERSITE
-- Designed by: J.DENOULET, Winter 2021
-- Completed by: Etudiant
--
-- Module Name: DCC_FRAME_GENERATOR - Behavioral
-- Project Name: Centrale DCC
-- Target Devices: Basys 3
--
-- Generateur de Trames de Test pour la Centrale DCC
-- Adresse du train de test: 3 (00000011)
--
-- Format trame 1 octet (51 bits, preambule etendu a 23 bits):
--   [23x'1'][0][addr 8b][0][cmd 8b][0][ctrl 8b][1]
--
-- Format trame 2 octets (51 bits, preambule standard 14 bits):
--   [14x'1'][0][addr 8b][0][cmd1 8b][0][cmd2 8b][0][ctrl 8b][1]
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity DCC_FRAME_GENERATOR is
    Port ( Interrupteur : in  STD_LOGIC_VECTOR(7 downto 0);
           Trame_DCC    : out STD_LOGIC_VECTOR(50 downto 0));
end DCC_FRAME_GENERATOR;

architecture Behavioral of DCC_FRAME_GENERATOR is

begin

process(Interrupteur)
begin

    -- Interrupteur 7 Active
        --> Trame Marche Avant du Train d'Adresse 3 (vitesse step 10)
    if Interrupteur(7) = '1' then
        -- Addr=00000011, Cmd=01110110 (fwd step10), Ctrl=01110101
        Trame_DCC <= "11111111111111111111111"  -- Preambule (23 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "01110110"                 -- Champ Commande (marche avant step 10)
                   & "0"                        -- Start Bit
                   & "01110101"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    -- Interrupteur 6 Active
        --> Trame Marche Arriere du Train d'Adresse 3 (vitesse step 10)
    elsif Interrupteur(6) = '1' then
        -- Addr=00000011, Cmd=01010110 (rev step10), Ctrl=01010101
        Trame_DCC <= "11111111111111111111111"  -- Preambule (23 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "01010110"                 -- Champ Commande (marche arriere step 10)
                   & "0"                        -- Start Bit
                   & "01010101"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    -- Interrupteur 5 Active
        --> Allumage des Phares du Train d'Adresse 3
    elsif Interrupteur(5) = '1' then
        -- Addr=00000011, Cmd=10010000 (F0=1), Ctrl=10010011
        Trame_DCC <= "11111111111111111111111"  -- Preambule (23 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "10010000"                 -- Champ Commande (phares ON)
                   & "0"                        -- Start Bit
                   & "10010011"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    -- Interrupteur 4 Active
        --> Extinction des Phares du Train d'Adresse 3
    elsif Interrupteur(4) = '1' then
        -- Addr=00000011, Cmd=10000000 (F0=0), Ctrl=10000011
        Trame_DCC <= "11111111111111111111111"  -- Preambule (23 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "10000000"                 -- Champ Commande (phares OFF)
                   & "0"                        -- Start Bit
                   & "10000011"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    -- Interrupteur 3 Active
        --> Activation du Klaxon (Fonction F11) du Train d'Adresse 3
    elsif Interrupteur(3) = '1' then
        -- Addr=00000011, Cmd=10100100 (F9-F12, F11=1), Ctrl=10100111
        Trame_DCC <= "11111111111111111111111"  -- Preambule (23 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "10100100"                 -- Champ Commande (F11 ON)
                   & "0"                        -- Start Bit
                   & "10100111"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    -- Interrupteur 2 Active
        --> Reamorcage du Klaxon (Fonction F11 OFF) du Train d'Adresse 3
    elsif Interrupteur(2) = '1' then
        -- Addr=00000011, Cmd=10100000 (F9-F12 toutes OFF), Ctrl=10100011
        Trame_DCC <= "11111111111111111111111"  -- Preambule (23 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "10100000"                 -- Champ Commande (F11 OFF)
                   & "0"                        -- Start Bit
                   & "10100011"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    -- Interrupteur 1 Active
        --> Annonce SNCF (Fonction F13 ON) du Train d'Adresse 3
    elsif Interrupteur(1) = '1' then
        -- Addr=00000011, Cmd1=11011110, Cmd2=00000001 (F13=1), Ctrl=11011100
        Trame_DCC <= "11111111111111"           -- Preambule (14 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "11011110"                 -- Champ Commande (Octet 1)
                   & "0"                        -- Start Bit
                   & "00000001"                 -- Champ Commande (Octet 2: F13 ON)
                   & "0"                        -- Start Bit
                   & "11011100"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    -- Interrupteur 0 Active
        --> Reamorcage Annonce SNCF (Fonction F13 OFF) du Train d'Adresse 3
    elsif Interrupteur(0) = '1' then
        -- Addr=00000011, Cmd1=11011110, Cmd2=00000000 (F13=0), Ctrl=11011101
        Trame_DCC <= "11111111111111"           -- Preambule (14 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "11011110"                 -- Champ Commande (Octet 1)
                   & "0"                        -- Start Bit
                   & "00000000"                 -- Champ Commande (Octet 2: F13 OFF)
                   & "0"                        -- Start Bit
                   & "11011101"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    -- Aucun Interrupteur Active
        --> Arret du Train d'Adresse 3
    else
        -- Addr=00000011, Cmd=01100000 (stop), Ctrl=01100011
        Trame_DCC <= "11111111111111111111111"  -- Preambule (23 bits)
                   & "0"                        -- Start Bit
                   & "00000011"                 -- Champ Adresse (3)
                   & "0"                        -- Start Bit
                   & "01100000"                 -- Champ Commande (arret)
                   & "0"                        -- Start Bit
                   & "01100011"                 -- Champ Controle (XOR)
                   & "1";                       -- Stop Bit

    end if;

end process;

end Behavioral;
