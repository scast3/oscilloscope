--------------------------------------------------------------------
-- Name:	Santiago Castillo
-- File:	acquireToHDMI_Datapath.vhdl
------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.acquireToHDMI_Package.all;			
use work.basicBuildingBlocks_package.all;		
use work.scopeToHdmi_package.all;
use work.all; 

entity acquireToHDMI_datapath is
    PORT ( clk : in  STD_LOGIC;
           resetn : in  STD_LOGIC;
		   cw : in STD_LOGIC_VECTOR(CW_WIDTH -1 downto 0);
		   sw : out STD_LOGIC_VECTOR(DATAPATH_SW_WIDTH - 1 downto 0);
		   an7606data: in STD_LOGIC_VECTOR(15 downto 0);

           triggerVolt16bitSigned: in SIGNED(15 downto 0);
		   triggerTimePixel: in STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS-1 downto 0);
		   ch1Data16bitSLV, ch2Data16bitSLV: out STD_LOGIC_VECTOR(15 downto 0);
		   
		   tmdsDataP : out  STD_LOGIC_VECTOR (2 downto 0);
           tmdsDataN : out  STD_LOGIC_VECTOR (2 downto 0);
           tmdsClkP : out STD_LOGIC;
           tmdsClkN : out STD_LOGIC;
           hdmiOen:    out STD_LOGIC
		   );
end acquireToHDMI_datapath;

architecture behavior of acquireToHDMI_datapath is

    signal storeIntoBramFlag: STD_LOGIC;
    signal videoClk, videoClk5x, clkLocked: STD_LOGIC;
    signal hs_temp : STD_LOGIC;
    signal vs_temp : STD_LOGIC;
    signal de_temp : STD_LOGIC;
    
    signal reset : STD_LOGIC;
    
    signal triggerTime, triggerVolt: STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    signal pixelHorz, pixelVert: STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    
    signal red, green, blue: STD_LOGIC_VECTOR(7 downto 0);
    
    signal ch1, ch2: STD_LOGIC; -- is this logic or a slv???
    
    signal wrAddr : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    signal zeros_vec : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    
    signal dout_bram1 : STD_LOGIC_VECTOR(15 downto 0);
    signal ch1_pixelV : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    
    signal dout_bram2 : STD_LOGIC_VECTOR(15 downto 0);
    signal ch2_pixelV : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    
    
    signal wea_1_temp : STD_LOGIC_VECTOR(0 downto 0);
    signal wea_2_temp : STD_LOGIC_VECTOR(0 downto 0);
    
begin
    zeros_vec <= (others => '0');

    reset <= not resetn;
    -- Simple SR Latch to assist FSM
    process(clk)
    begin
        if(rising_edge(clk)) then
            if(resetn ='0') then
                storeIntoBramFlag <= '0';
            elsif (cw(SET_STORE_FLAG_CW_BIT_INDEX) = '1') then
                storeIntoBramFlag <= '1';
            elsif (cw(CLEAR_STORE_FLAG_CW_BIT_INDEX) = '1') then
                storeIntoBramFlag <= '0';
            end if;
        end if;
    end process;

    sw(STORE_SW_BIT_INDEX) <= storeIntoBramFlag;
    
    
      
    vc: clk_wiz_0
        PORT MAP (
            clk_in1 => clk,
            clk_out1 => videoClk,
            resetn => resetn,
            locked => clkLocked,
            clk_out2 => videoClk5x);
    
    vsg: videoSignalGenerator
        PORT MAP (clk => videoClk, 
            resetn => resetn,
            hs => hs_temp,
            vs => vs_temp,
            de => de_temp,
            pixelHorz => pixelHorz,
            pixelVert => pixelVert
        );
        
    sf: scopeFace
        PORT MAP (clk => videoClk,
            resetn => resetn,
            pixelHorz => pixelHorz,
            pixelVert => pixelVert,
            triggerTime => triggerTime,
            triggerVolt => triggerVolt,
            ch1 => ch1,
            ch1enb => '1',
            ch2 => ch2,
            ch2enb => '1',
            red => red,
            green => green,
            blue => blue
        );
                 

    hdmi_inst: hdmi_tx_0
        PORT MAP (
            pix_clk => videoClk,
            pix_clkx5 => videoClk5x,
            rst => reset,
            hsync => hs_temp,
            vsync => vs_temp,
            vde => de_temp,
            pix_clk_locked => clkLocked,
            red => red,
            green => green,
            blue => blue,
            TMDS_DATA_P => tmdsDataP,
            TMDS_DATA_N => tmdsDataN,
            TMDS_CLK_P => tmdsClkP,
            TMDS_CLK_N => tmdsClkN,
            aux0_din => "0000",
            aux1_din => "0000",
            aux2_din => "0000",
            ade => '0'
        );
    -- counter to determine the BRAM write address
    ch1_counter : genericCounter
        GENERIC MAP (VIDEO_WIDTH_IN_BITS)
        PORT MAP(clk=>clk,
            resetn => resetn,
            c => cw(DATA_STORAGE_COUNTER_CW_BIT_INDEX downto DATA_STORAGE_COUNTER_CW_BIT_INDEX-1),
            d => zeros_vec,
            q => wrAddr
        );
    
    -- comparator to see if the write address had reached the end yet (screen width)
    -- i am not really sure how to declare screen width (1099 - 100), but what constants to use?
    ch1_compare_full : genericCompare
        GENERIC MAP(VIDEO_WIDTH_IN_BITS)
        PORT MAP(x => DATA_SIZE, 
            y => wrAddr, 
            g => open, 
            l => open,
            e => sw(FULL_SW_BIT_INDEX)
        );
    pixelConvert_Ch1: entity work.toPixelValue(behavior)
        PORT MAP (
            ad7606SLV => dout_bram1,
            currentPixelV => ch1_pixelV
        );
    ch1_compare_pixelV : genericCompare
        GENERIC MAP(VIDEO_WIDTH_IN_BITS)
        PORT MAP(x => ch1_pixelV, 
            y => pixelVert, 
            g => open, 
            l => open,
            e => ch1
        );
    
    wea_1_temp <= cw(DATA_STORAGE_CH1_WRITE_CW_BIT_INDEX)&"";
    ch1_bram : blk_mem_gen_0
        PORT MAP(
            clka => clk,
            ena => '1',
            wea => wea_1_temp,
            addra => wrAddr(VIDEO_WIDTH_IN_BITS-2 downto 0), -- need to ensure it's 10 bits not 11
            dina => an7606data,
            clkb => clk,
            enb => '1',
            addrb => L_EDGE(VIDEO_WIDTH_IN_BITS-2 downto 0) -- same
        );

end behavior;
