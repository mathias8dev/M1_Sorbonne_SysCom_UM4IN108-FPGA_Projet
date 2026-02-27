----------------------------------------------------------------------------------
-- Module Name: MAE - Behavioral
-- Project Name: Centrale DCC
-- Target Devices: Basys 3
--
-- Machine a Etats principale de la Centrale DCC
-- Orchestre la transmission continue des trames DCC:
--   1. Charge la trame dans le registre
--   2. Envoie chaque bit (51 bits, MSB first) via DCC_Bit_1 ou DCC_Bit_0
--   3. Attend 6ms (tempo) entre chaque trame
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MAE is
    Port ( Clk          : in  STD_LOGIC;                       -- Horloge 100 MHz
           Reset        : in  STD_LOGIC;                       -- Reset Asynchrone
           Bit_Courant  : in  STD_LOGIC;                       -- Bit courant du registre (MSB)
           Fin_1        : in  STD_LOGIC;                       -- Fin de transmission DCC bit 1
           Fin_0        : in  STD_LOGIC;                       -- Fin de transmission DCC bit 0
           Fin_Tempo    : in  STD_LOGIC;                       -- Fin de temporisation 6ms
           Go_1         : out STD_LOGIC;                       -- Commande DCC_Bit_1
           Go_0         : out STD_LOGIC;                       -- Commande DCC_Bit_0
           Start_Tempo  : out STD_LOGIC;                       -- Commande Tempo
           COM_REG      : out STD_LOGIC_VECTOR(1 downto 0)     -- Commande Registre
    );
end MAE;

architecture Behavioral of MAE is

    type state_type is (LOAD, SEND, SEND_1, WAIT_1, SEND_0, WAIT_0,
                        SHIFT, START_TEMP, WAIT_TEMP);
    signal state : state_type;

    -- Compteur de bits (0 a 50 = 51 bits)
    signal Bit_Count : INTEGER range 0 to 50;

begin

    process(Clk, Reset)
    begin
        if Reset = '1' then
            state     <= LOAD;
            Bit_Count <= 0;
        elsif rising_edge(Clk) then
            case state is

                -- Chargement de la trame dans le registre
                when LOAD =>
                    Bit_Count <= 0;
                    state <= SEND;

                -- Lecture du bit courant et branchement
                when SEND =>
                    if Bit_Courant = '1' then
                        state <= SEND_1;
                    else
                        state <= SEND_0;
                    end if;

                -- Activation du generateur de bit 1
                when SEND_1 =>
                    state <= WAIT_1;

                -- Attente fin de transmission bit 1
                when WAIT_1 =>
                    if Fin_1 = '1' then
                        state <= SHIFT;
                    end if;

                -- Activation du generateur de bit 0
                when SEND_0 =>
                    state <= WAIT_0;

                -- Attente fin de transmission bit 0
                when WAIT_0 =>
                    if Fin_0 = '1' then
                        state <= SHIFT;
                    end if;

                -- Decalage du registre et verification
                when SHIFT =>
                    if Bit_Count = 50 then
                        state <= START_TEMP;
                    else
                        Bit_Count <= Bit_Count + 1;
                        state <= SEND;
                    end if;

                -- Demarrage de la temporisation 6ms
                when START_TEMP =>
                    state <= WAIT_TEMP;

                -- Attente fin de temporisation
                when WAIT_TEMP =>
                    if Fin_Tempo = '1' then
                        state <= LOAD;
                    end if;

            end case;
        end if;
    end process;

    -- Sorties combinatoires
    Go_1        <= '1' when (state = SEND_1 or state = WAIT_1) else '0';
    Go_0        <= '1' when (state = SEND_0 or state = WAIT_0) else '0';
    Start_Tempo <= '1' when (state = START_TEMP or state = WAIT_TEMP) else '0';

    -- Commande registre: "01" = load, "10" = shift
    COM_REG <= "01" when state = LOAD else
               "10" when state = SHIFT else
               "00";

end Behavioral;
