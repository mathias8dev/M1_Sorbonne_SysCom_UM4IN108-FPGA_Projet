----------------------------------------------------------------------------------
-- Module Name: TOP_DCC - Structural
-- Project Name: Centrale DCC
-- Target Devices: Basys 3
--
-- Module Top-Level assemblant tous les composants de la Centrale DCC
-- Sortie DCC sur JB[4] (broche 4 du connecteur PMOD B)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TOP_DCC is
    Port ( Clk_100MHz   : in  STD_LOGIC;                       -- Horloge 100 MHz
           Reset        : in  STD_LOGIC;                       -- Reset (bouton centre)
           Interrupteur : in  STD_LOGIC_VECTOR(7 downto 0);   -- 8 interrupteurs
           Sortie_DCC   : out STD_LOGIC                        -- Signal DCC (JB[4])
    );
end TOP_DCC;

architecture Structural of TOP_DCC is

    -- Signaux internes
    signal Clk_1MHz     : STD_LOGIC;
    signal Trame_DCC    : STD_LOGIC_VECTOR(50 downto 0);
    signal COM_REG      : STD_LOGIC_VECTOR(1 downto 0);
    signal Bit_Courant  : STD_LOGIC;
    signal Start_Tempo  : STD_LOGIC;
    signal Fin_Tempo    : STD_LOGIC;
    signal Go_1         : STD_LOGIC;
    signal Fin_1        : STD_LOGIC;
    signal Go_0         : STD_LOGIC;
    signal Fin_0        : STD_LOGIC;
    signal DCC_1        : STD_LOGIC;
    signal DCC_0        : STD_LOGIC;

    -- Declarations des composants
    component CLK_DIV is
        Port ( Reset   : in  STD_LOGIC;
               Clk_In  : in  STD_LOGIC;
               Clk_Out : out STD_LOGIC);
    end component;

    component COMPTEUR_TEMPO is
        Port ( Clk         : in  STD_LOGIC;
               Reset       : in  STD_LOGIC;
               Clk1M       : in  STD_LOGIC;
               Start_Tempo : in  STD_LOGIC;
               Fin_Tempo   : out STD_LOGIC);
    end component;

    component DCC_FRAME_GENERATOR is
        Port ( Interrupteur : in  STD_LOGIC_VECTOR(7 downto 0);
               Trame_DCC    : out STD_LOGIC_VECTOR(50 downto 0));
    end component;

    component REGISTRE_DCC is
        Port ( Clk         : in  STD_LOGIC;
               Reset       : in  STD_LOGIC;
               COM_REG     : in  STD_LOGIC_VECTOR(1 downto 0);
               Trame_DCC   : in  STD_LOGIC_VECTOR(50 downto 0);
               Bit_Courant : out STD_LOGIC);
    end component;

    component MAE is
        Port ( Clk         : in  STD_LOGIC;
               Reset       : in  STD_LOGIC;
               Bit_Courant : in  STD_LOGIC;
               Fin_1       : in  STD_LOGIC;
               Fin_0       : in  STD_LOGIC;
               Fin_Tempo   : in  STD_LOGIC;
               Go_1        : out STD_LOGIC;
               Go_0        : out STD_LOGIC;
               Start_Tempo : out STD_LOGIC;
               COM_REG     : out STD_LOGIC_VECTOR(1 downto 0));
    end component;

    component DCC_BIT_1 is
        Port ( Clk     : in  STD_LOGIC;
               Clk1M   : in  STD_LOGIC;
               Reset   : in  STD_LOGIC;
               Go      : in  STD_LOGIC;
               Fin     : out STD_LOGIC;
               DCC_Out : out STD_LOGIC);
    end component;

    component DCC_BIT_0 is
        Port ( Clk     : in  STD_LOGIC;
               Clk1M   : in  STD_LOGIC;
               Reset   : in  STD_LOGIC;
               Go      : in  STD_LOGIC;
               Fin     : out STD_LOGIC;
               DCC_Out : out STD_LOGIC);
    end component;

begin

    -- Diviseur d'horloge 100MHz -> 1MHz
    inst_clk_div : CLK_DIV
        port map (
            Reset   => Reset,
            Clk_In  => Clk_100MHz,
            Clk_Out => Clk_1MHz
        );

    -- Generateur de trames de test
    inst_gen_trames : DCC_FRAME_GENERATOR
        port map (
            Interrupteur => Interrupteur,
            Trame_DCC    => Trame_DCC
        );

    -- Registre a decalage DCC
    inst_registre : REGISTRE_DCC
        port map (
            Clk         => Clk_100MHz,
            Reset       => Reset,
            COM_REG     => COM_REG,
            Trame_DCC   => Trame_DCC,
            Bit_Courant => Bit_Courant
        );

    -- Machine a etats principale
    inst_mae : MAE
        port map (
            Clk         => Clk_100MHz,
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

    -- Compteur de temporisation (6ms)
    inst_tempo : COMPTEUR_TEMPO
        port map (
            Clk         => Clk_100MHz,
            Reset       => Reset,
            Clk1M       => Clk_1MHz,
            Start_Tempo => Start_Tempo,
            Fin_Tempo   => Fin_Tempo
        );

    -- Generateur de bit DCC 1
    inst_bit1 : DCC_BIT_1
        port map (
            Clk     => Clk_100MHz,
            Clk1M   => Clk_1MHz,
            Reset   => Reset,
            Go      => Go_1,
            Fin     => Fin_1,
            DCC_Out => DCC_1
        );

    -- Generateur de bit DCC 0
    inst_bit0 : DCC_BIT_0
        port map (
            Clk     => Clk_100MHz,
            Clk1M   => Clk_1MHz,
            Reset   => Reset,
            Go      => Go_0,
            Fin     => Fin_0,
            DCC_Out => DCC_0
        );

    -- Porte OU en sortie des deux generateurs de bits
    Sortie_DCC <= DCC_1 or DCC_0;

end Structural;
