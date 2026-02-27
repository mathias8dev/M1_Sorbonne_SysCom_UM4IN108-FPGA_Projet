----------------------------------------------------------------------------------
-- Module Name: REGISTRE_DCC - Behavioral
-- Project Name: Centrale DCC
-- Target Devices: Basys 3
--
-- Registre a decalage 51 bits pour la trame DCC
-- Chargement parallele ou decalage vers la gauche (MSB first)
-- COM_REG: "01" = chargement, "10" = decalage, autres = maintien
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity REGISTRE_DCC is
    Port ( Clk          : in  STD_LOGIC;                       -- Horloge 100 MHz
           Reset        : in  STD_LOGIC;                       -- Reset Asynchrone
           COM_REG      : in  STD_LOGIC_VECTOR(1 downto 0);   -- Commande: "01"=load, "10"=shift
           Trame_DCC    : in  STD_LOGIC_VECTOR(50 downto 0);  -- Trame a charger
           Bit_Courant  : out STD_LOGIC                        -- MSB du registre (bit a transmettre)
    );
end REGISTRE_DCC;

architecture Behavioral of REGISTRE_DCC is

    signal Reg : STD_LOGIC_VECTOR(50 downto 0);

begin

    Bit_Courant <= Reg(50);

    process(Clk, Reset)
    begin
        if Reset = '1' then
            Reg <= (others => '1');  -- Preambule par defaut
        elsif rising_edge(Clk) then
            case COM_REG is
                when "01" =>     -- Chargement parallele
                    Reg <= Trame_DCC;
                when "10" =>     -- Decalage a gauche (MSB sort, '0' entre a droite)
                    Reg <= Reg(49 downto 0) & '0';
                when others =>   -- Maintien
                    null;
            end case;
        end if;
    end process;

end Behavioral;
