----------------------------------------------------------------------------------
-- Module Name: DCC_BIT_1 - Behavioral
-- Project Name: Centrale DCC
-- Target Devices: Basys 3
--
-- Generateur de bit DCC a 1
-- Impulsion a 0 de 58 us puis impulsion a 1 de 58 us
-- FSM cadencee par CLK 100MHz, compteur cadence par CLK 1MHz
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity DCC_BIT_1 is
    Port ( Clk      : in  STD_LOGIC;   -- Horloge 100 MHz
           Clk1M    : in  STD_LOGIC;   -- Horloge 1 MHz
           Reset    : in  STD_LOGIC;   -- Reset Asynchrone
           Go       : in  STD_LOGIC;   -- Commande de generation du bit
           Fin      : out STD_LOGIC;   -- Fin de transmission du bit
           DCC_Out  : out STD_LOGIC    -- Signal de sortie DCC
    );
end DCC_BIT_1;

architecture Behavioral of DCC_BIT_1 is

    type state_type is (IDLE, LOW_PHASE, RESET_CTR, HIGH_PHASE, DONE);
    signal state : state_type;

    -- Commandes du compteur
    signal Raz_Cpt  : STD_LOGIC;
    signal Inc_Cpt  : STD_LOGIC;
    signal Fin_Cpt  : STD_LOGIC;

    -- Compteur (1 MHz)
    signal Cpt : INTEGER range 0 to 127;

begin

    -- Machine a etats (100 MHz)
    process(Clk, Reset)
    begin
        if Reset = '1' then
            state <= IDLE;
        elsif rising_edge(Clk) then
            case state is
                when IDLE =>
                    if Go = '1' then
                        state <= LOW_PHASE;
                    end if;

                when LOW_PHASE =>
                    if Fin_Cpt = '1' then
                        state <= RESET_CTR;
                    end if;

                when RESET_CTR =>
                    if Fin_Cpt = '0' then
                        state <= HIGH_PHASE;
                    end if;

                when HIGH_PHASE =>
                    if Fin_Cpt = '1' then
                        state <= DONE;
                    end if;

                when DONE =>
                    if Go = '0' then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- Sorties combinatoires de la FSM
    DCC_Out <= '1' when (state = HIGH_PHASE or state = RESET_CTR) else '0';
    Fin     <= '1' when state = DONE else '0';
    Raz_Cpt <= '1' when (state = IDLE or state = RESET_CTR or state = DONE) else '0';
    Inc_Cpt <= '1' when (state = LOW_PHASE or state = HIGH_PHASE) else '0';

    -- Compteur (1 MHz)
    process(Clk1M, Reset)
    begin
        if Reset = '1' then
            Cpt <= 0;
        elsif rising_edge(Clk1M) then
            if Raz_Cpt = '1' then
                Cpt <= 0;
            elsif Inc_Cpt = '1' then
                Cpt <= Cpt + 1;
            end if;
        end if;
    end process;

    -- Fin de comptage a 57 (58 ticks = 58 us)
    Fin_Cpt <= '1' when Cpt = 57 else '0';

end Behavioral;
