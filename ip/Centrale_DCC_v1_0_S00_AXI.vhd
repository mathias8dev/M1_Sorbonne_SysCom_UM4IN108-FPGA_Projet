----------------------------------------------------------------------------------
-- Module Name: Centrale_DCC_v1_0_S00_AXI - Behavioral
-- Project Name: Centrale DCC -- IP MicroBlaze
-- Target Devices: Basys 3
--
-- Interface AXI4-Lite esclave de l'IP Centrale DCC
-- Basee sur le template standard genere par Vivado, avec ajout du coeur DCC
--
-- Registres AXI:
--   slv_reg0 (offset 0x00) : Trame_DCC(31 downto 0)  -- 32 bits bas
--   slv_reg1 (offset 0x04) : Trame_DCC(50 downto 32)  -- bits [18:0]
--   slv_reg2 (offset 0x08) : Reserve
--   slv_reg3 (offset 0x0C) : Reserve
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Centrale_DCC_v1_0_S00_AXI is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4
    );
    port (
        -- Port utilisateur : sortie DCC
        SORTIE_DCC     : out STD_LOGIC;

        -- Ports AXI4-Lite Esclave
        S_AXI_ACLK    : in  STD_LOGIC;
        S_AXI_ARESETN  : in  STD_LOGIC;
        S_AXI_AWADDR   : in  STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT   : in  STD_LOGIC_VECTOR(2 downto 0);
        S_AXI_AWVALID  : in  STD_LOGIC;
        S_AXI_AWREADY  : out STD_LOGIC;
        S_AXI_WDATA    : in  STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB    : in  STD_LOGIC_VECTOR((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID   : in  STD_LOGIC;
        S_AXI_WREADY   : out STD_LOGIC;
        S_AXI_BRESP    : out STD_LOGIC_VECTOR(1 downto 0);
        S_AXI_BVALID   : out STD_LOGIC;
        S_AXI_BREADY   : in  STD_LOGIC;
        S_AXI_ARADDR   : in  STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT   : in  STD_LOGIC_VECTOR(2 downto 0);
        S_AXI_ARVALID  : in  STD_LOGIC;
        S_AXI_ARREADY  : out STD_LOGIC;
        S_AXI_RDATA    : out STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP    : out STD_LOGIC_VECTOR(1 downto 0);
        S_AXI_RVALID   : out STD_LOGIC;
        S_AXI_RREADY   : in  STD_LOGIC
    );
end Centrale_DCC_v1_0_S00_AXI;

architecture Behavioral of Centrale_DCC_v1_0_S00_AXI is

    -- Signaux AXI internes
    signal axi_awready : STD_LOGIC;
    signal axi_wready  : STD_LOGIC;
    signal axi_bresp   : STD_LOGIC_VECTOR(1 downto 0);
    signal axi_bvalid  : STD_LOGIC;
    signal axi_arready : STD_LOGIC;
    signal axi_rdata   : STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal axi_rresp   : STD_LOGIC_VECTOR(1 downto 0);
    signal axi_rvalid  : STD_LOGIC;

    signal slv_reg_rden : STD_LOGIC;
    signal slv_reg_wren : STD_LOGIC;
    signal reg_data_out : STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);

    -- 4 registres esclaves de 32 bits
    signal slv_reg0 : STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg1 : STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg2 : STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal slv_reg3 : STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);

    -- Adresse d'ecriture/lecture latche
    signal axi_awaddr_latched : STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_araddr_latched : STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);

    --------------------------------------------------------------------------
    -- Signaux du coeur DCC
    --------------------------------------------------------------------------
    signal Reset_DCC    : STD_LOGIC;
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

    --------------------------------------------------------------------------
    -- Composants du coeur DCC
    --------------------------------------------------------------------------
    component CLK_DIV is
        Port ( Reset : in STD_LOGIC; Clk_In : in STD_LOGIC; Clk_Out : out STD_LOGIC);
    end component;

    component COMPTEUR_TEMPO is
        Port ( Clk : in STD_LOGIC; Reset : in STD_LOGIC; Clk1M : in STD_LOGIC;
               Start_Tempo : in STD_LOGIC; Fin_Tempo : out STD_LOGIC);
    end component;

    component REGISTRE_DCC is
        Port ( Clk : in STD_LOGIC; Reset : in STD_LOGIC;
               COM_REG : in STD_LOGIC_VECTOR(1 downto 0);
               Trame_DCC : in STD_LOGIC_VECTOR(50 downto 0);
               Bit_Courant : out STD_LOGIC);
    end component;

    component MAE is
        Port ( Clk : in STD_LOGIC; Reset : in STD_LOGIC;
               Bit_Courant : in STD_LOGIC; Fin_1 : in STD_LOGIC;
               Fin_0 : in STD_LOGIC; Fin_Tempo : in STD_LOGIC;
               Go_1 : out STD_LOGIC; Go_0 : out STD_LOGIC;
               Start_Tempo : out STD_LOGIC;
               COM_REG : out STD_LOGIC_VECTOR(1 downto 0));
    end component;

    component DCC_BIT_1 is
        Port ( Clk : in STD_LOGIC; Clk1M : in STD_LOGIC; Reset : in STD_LOGIC;
               Go : in STD_LOGIC; Fin : out STD_LOGIC; DCC_Out : out STD_LOGIC);
    end component;

    component DCC_BIT_0 is
        Port ( Clk : in STD_LOGIC; Clk1M : in STD_LOGIC; Reset : in STD_LOGIC;
               Go : in STD_LOGIC; Fin : out STD_LOGIC; DCC_Out : out STD_LOGIC);
    end component;

begin

    -- Affectation des sorties AXI
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= axi_bresp;
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= axi_rresp;
    S_AXI_RVALID  <= axi_rvalid;

    --------------------------------------------------------------------------
    -- Logique d'ecriture AXI (canal W)
    --------------------------------------------------------------------------

    -- AWREADY : pret a accepter l'adresse d'ecriture
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
            else
                if axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' then
                    axi_awready <= '1';
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Latch de l'adresse d'ecriture
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awaddr_latched <= (others => '0');
            elsif axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' then
                axi_awaddr_latched <= S_AXI_AWADDR;
            end if;
        end if;
    end process;

    -- WREADY : pret a accepter les donnees d'ecriture
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_wready <= '0';
            else
                if axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' then
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Signal d'ecriture effectif
    slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID;

    -- Ecriture dans les registres esclaves
    process(S_AXI_ACLK)
        variable loc_addr : STD_LOGIC_VECTOR(1 downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                slv_reg0 <= (others => '0');
                slv_reg1 <= (others => '0');
                slv_reg2 <= (others => '0');
                slv_reg3 <= (others => '0');
            elsif slv_reg_wren = '1' then
                loc_addr := axi_awaddr_latched(3 downto 2);
                case loc_addr is
                    when "00" =>
                        for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8)-1 loop
                            if S_AXI_WSTRB(byte_index) = '1' then
                                slv_reg0(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                            end if;
                        end loop;
                    when "01" =>
                        for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8)-1 loop
                            if S_AXI_WSTRB(byte_index) = '1' then
                                slv_reg1(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                            end if;
                        end loop;
                    when "10" =>
                        for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8)-1 loop
                            if S_AXI_WSTRB(byte_index) = '1' then
                                slv_reg2(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                            end if;
                        end loop;
                    when others =>
                        for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8)-1 loop
                            if S_AXI_WSTRB(byte_index) = '1' then
                                slv_reg3(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                            end if;
                        end loop;
                end case;
            end if;
        end if;
    end process;

    -- Reponse d'ecriture (BRESP)
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_bvalid <= '0';
                axi_bresp  <= "00";
            else
                if axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0' then
                    axi_bvalid <= '1';
                    axi_bresp  <= "00";  -- OKAY
                elsif S_AXI_BREADY = '1' and axi_bvalid = '1' then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- Logique de lecture AXI (canal R)
    --------------------------------------------------------------------------

    -- ARREADY
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_arready <= '0';
                axi_araddr_latched <= (others => '0');
            else
                if axi_arready = '0' and S_AXI_ARVALID = '1' then
                    axi_arready <= '1';
                    axi_araddr_latched <= S_AXI_ARADDR;
                else
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- RVALID et RDATA
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rvalid <= '0';
                axi_rresp  <= "00";
            else
                if axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0' then
                    axi_rvalid <= '1';
                    axi_rresp  <= "00";  -- OKAY
                elsif axi_rvalid = '1' and S_AXI_RREADY = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid);

    -- Multiplexeur de lecture
    process(axi_araddr_latched, slv_reg0, slv_reg1, slv_reg2, slv_reg3)
        variable loc_addr : STD_LOGIC_VECTOR(1 downto 0);
    begin
        loc_addr := axi_araddr_latched(3 downto 2);
        case loc_addr is
            when "00"   => reg_data_out <= slv_reg0;
            when "01"   => reg_data_out <= slv_reg1;
            when "10"   => reg_data_out <= slv_reg2;
            when others => reg_data_out <= slv_reg3;
        end case;
    end process;

    -- Sortie RDATA
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rdata <= (others => '0');
            elsif slv_reg_rden = '1' then
                axi_rdata <= reg_data_out;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------
    -- COEUR DCC : instanciation des modules
    --------------------------------------------------------------------------

    -- Inversion du reset (AXI = actif bas, DCC = actif haut)
    Reset_DCC <= not S_AXI_ARESETN;

    -- Composition de la trame DCC depuis les registres AXI
    Trame_DCC <= slv_reg1(18 downto 0) & slv_reg0;

    -- Diviseur d'horloge 100MHz -> 1MHz
    inst_clk_div : CLK_DIV
        port map (
            Reset   => Reset_DCC,
            Clk_In  => S_AXI_ACLK,
            Clk_Out => Clk_1MHz
        );

    -- Registre a decalage DCC
    inst_registre : REGISTRE_DCC
        port map (
            Clk         => S_AXI_ACLK,
            Reset       => Reset_DCC,
            COM_REG     => COM_REG,
            Trame_DCC   => Trame_DCC,
            Bit_Courant => Bit_Courant
        );

    -- Machine a etats principale
    inst_mae : MAE
        port map (
            Clk         => S_AXI_ACLK,
            Reset       => Reset_DCC,
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
            Clk         => S_AXI_ACLK,
            Reset       => Reset_DCC,
            Clk1M       => Clk_1MHz,
            Start_Tempo => Start_Tempo,
            Fin_Tempo   => Fin_Tempo
        );

    -- Generateur de bit DCC 1
    inst_bit1 : DCC_BIT_1
        port map (
            Clk     => S_AXI_ACLK,
            Clk1M   => Clk_1MHz,
            Reset   => Reset_DCC,
            Go      => Go_1,
            Fin     => Fin_1,
            DCC_Out => DCC_1
        );

    -- Generateur de bit DCC 0
    inst_bit0 : DCC_BIT_0
        port map (
            Clk     => S_AXI_ACLK,
            Clk1M   => Clk_1MHz,
            Reset   => Reset_DCC,
            Go      => Go_0,
            Fin     => Fin_0,
            DCC_Out => DCC_0
        );

    -- Porte OU en sortie
    SORTIE_DCC <= DCC_1 or DCC_0;

end Behavioral;
