--------------------------------------------------------------------
-- Name:	Santiago Castillo
-- File:	acquireToHDMI_Datapath.vhdl
------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

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
    
    signal trigTime, trigVscr : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    signal pixelHorz, pixelVert: STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    
    signal red, green, blue: STD_LOGIC_VECTOR(7 downto 0);
    
    signal ch1, ch2: STD_LOGIC; -- is this logic or a slv???
    
    signal wrAddr : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    signal zeros_vec : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    signal zeros_vec32 : STD_LOGIC_VECTOR(31 downto 0);
    
    signal dout_bram1 : STD_LOGIC_VECTOR(15 downto 0);
    signal ch1_pixelV : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    
    signal dout_bram2 : STD_LOGIC_VECTOR(15 downto 0);
    signal ch2_pixelV : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    
    signal data_address : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    
    signal wea_1_temp : STD_LOGIC_VECTOR(0 downto 0);
    signal wea_2_temp : STD_LOGIC_VECTOR(0 downto 0);
    
    -- ch1 trigger signals
    signal ch1_trigger_sample1 : STD_LOGIC_VECTOR(15 downto 0);
    signal ch1_trigger_sample2 : STD_LOGIC_VECTOR(15 downto 0);
    signal ch1_trigger_sample1_signed : SIGNED(15 downto 0);
    signal ch1_trigger_sample2_signed : SIGNED(15 downto 0);
    
    signal ch1_trigger_sample1_cond : STD_LOGIC;
    signal ch1_trigger_sample2_cond : STD_LOGIC;
    
    signal ch2_trigger_sample1 : STD_LOGIC_VECTOR(15 downto 0);
    signal ch2_trigger_sample2 : STD_LOGIC_VECTOR(15 downto 0);
    signal ch2_trigger_sample1_signed : SIGNED(15 downto 0);
    signal ch2_trigger_sample2_signed : SIGNED(15 downto 0);
    
    signal ch2_trigger_sample1_cond : STD_LOGIC;
    signal ch2_trigger_sample2_cond : STD_LOGIC;

    -- counter signals
    signal currentLongCount : STD_LOGIC_VECTOR(LONG_DELAY_50Mhz_CONST_WIDTH-1 downto 0);
	signal currentShortCount : STD_LOGIC_VECTOR(SHORT_DELAY_50Mhz_CONST_WIDTH-1 downto 0);
	signal longZeros : STD_LOGIC_VECTOR(LONG_DELAY_50Mhz_CONST_WIDTH-1 downto 0) ;
	signal shortZeros : STD_LOGIC_VECTOR(SHORT_DELAY_50Mhz_CONST_WIDTH-1 downto 0);
    
    -- sampling signals
    signal currentRate : STD_LOGIC_VECTOR(31 downto 0);
    signal sampleIndex : STD_LOGIC_VECTOR(31 downto 0);
    
    
begin
    hdmiOen <= '1';
    zeros_vec <= (others => '0');
    zeros_vec32 <= (others => '0');
    reset <= not resetn;
    
    data_address <= pixelHorz - L_EDGE;
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
            triggerTime => trigTime,
            triggerVolt => trigVscr,
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
    dataWriteAddr_counter : genericCounter
        GENERIC MAP (VIDEO_WIDTH_IN_BITS)
        PORT MAP(clk=>clk,
            resetn => resetn,
            c => cw(DATA_STORAGE_COUNTER_CW_BIT_INDEX downto DATA_STORAGE_COUNTER_CW_BIT_INDEX-1),
            d => zeros_vec,
            q => wrAddr
        );
    
    -- comparator to see if the write address had reached the end yet (screen width)
    -- i am not really sure how to declare screen width (1099 - 100), but what constants to use?
    cmp_BRAM_full : genericCompare
        GENERIC MAP(VIDEO_WIDTH_IN_BITS)
        PORT MAP(x => DATA_SIZE, 
            y => wrAddr, 
            g => open, 
            l => open,
            e => sw(FULL_SW_BIT_INDEX)
        );


    ch1_pixelConvert: entity work.toPixelValue(behavior)
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
            clkb => videoClk,
            enb => '1',
            addrb => data_address(VIDEO_WIDTH_IN_BITS-2 downto 0), -- same
            doutb => dout_bram1
        );

    ch2_pixelConvert: entity work.toPixelValue(behavior)
        PORT MAP (
            ad7606SLV => dout_bram2,
            currentPixelV => ch2_pixelV
        );
    ch2_compare_pixelV : genericCompare
        GENERIC MAP(VIDEO_WIDTH_IN_BITS)
        PORT MAP(x => ch2_pixelV, 
            y => pixelVert, 
            g => open, 
            l => open,
            e => ch2
        );
    
    wea_2_temp <= cw(DATA_STORAGE_CH2_WRITE_CW_BIT_INDEX)&"";
    ch2_bram : blk_mem_gen_1
        PORT MAP(
            clka => clk,
            ena => '1',
            wea => wea_2_temp,
            addra => wrAddr(VIDEO_WIDTH_IN_BITS-2 downto 0), -- need to ensure it's 10 bits not 11
            dina => an7606data,
            clkb => videoClk,
            enb => '1',
            addrb => data_address(VIDEO_WIDTH_IN_BITS-2 downto 0), -- need to do pixelhorz - l_edge
            doutb => dout_bram2
        );
    
    
    -- ch1 trigger logic
    ch1_sample1 : genericRegister
        GENERIC MAP(16)
        PORT MAP(
            clk => clk,
            resetn => resetn,
            load => cw(TRIG_CH1_WRITE_CW_BIT_INDEX),
            d => an7606data,
            q => ch1_trigger_sample1
        );
    ch1Data16bitSLV <= ch1_trigger_sample1;
    
    ch1_trigger_sample1_signed <= signed(ch1_trigger_sample1);
    ch1_sample1_compare : genericCompare_Signed
        GENERIC MAP(16)
        PORT MAP(x => ch1_trigger_sample1_signed, 
            y => triggerVolt16bitSigned,
            g => ch1_trigger_sample1_cond, 
            l => open,
            e => open
        );    
    ch1_sample2 : genericRegister
        GENERIC MAP(16)
        PORT MAP(
            clk => clk,
            resetn => resetn,
            load => cw(TRIG_CH1_WRITE_CW_BIT_INDEX),
            d => ch1_trigger_sample1,
            q => ch1_trigger_sample2
        );
    
    ch1_trigger_sample2_signed <= signed(ch1_trigger_sample2);
    ch1_sample2_compare : genericCompare_Signed
        GENERIC MAP(16)
        PORT MAP(x => ch1_trigger_sample2_signed, 
            y => triggerVolt16bitSigned,
            g => open, 
            l => ch1_trigger_sample2_cond,
            e => open
        );
    sw(TRIG_CH1_SW_BIT_INDEX) <= ch1_trigger_sample1_cond and ch1_trigger_sample2_cond;   
        
    -- ch2 trigger logic
    ch2_sample1 : genericRegister
        GENERIC MAP(16)
        PORT MAP(
            clk => clk,
            resetn => resetn,
            load => cw(TRIG_CH2_WRITE_CW_BIT_INDEX),
            d => an7606data,
            q => ch2_trigger_sample1
        );
    ch2Data16bitSLV <= ch2_trigger_sample1;
    
    ch2_trigger_sample1_signed <= signed(ch2_trigger_sample1);
    ch2_sample1_compare : genericCompare_Signed
        GENERIC MAP(16)
        PORT MAP(x => ch2_trigger_sample1_signed, 
            y => triggerVolt16bitSigned,
            g => ch2_trigger_sample1_cond, 
            l => open,
            e => open
        );    
    ch2_sample2 : genericRegister
        GENERIC MAP(16)
        PORT MAP(
            clk => clk,
            resetn => resetn,
            load => cw(TRIG_CH2_WRITE_CW_BIT_INDEX),
            d => ch2_trigger_sample1,
            q => ch2_trigger_sample2
        );
        
    ch2_trigger_sample2_signed <= signed(ch2_trigger_sample2);
    ch2_sample2_compare : genericCompare_Signed
        GENERIC MAP(16)
        PORT MAP(x => ch2_trigger_sample2_signed, 
            y => triggerVolt16bitSigned,
            g => open, 
            l => ch2_trigger_sample2_cond,
            e => open
        );
    sw(TRIG_CH2_SW_BIT_INDEX) <= ch2_trigger_sample1_cond and ch2_trigger_sample2_cond;

    -- short and long counters
    longCounter : genericCounter
        GENERIC MAP (LONG_DELAY_50Mhz_CONST_WIDTH)
        PORT MAP(clk=>clk,
            resetn => resetn,
            c => cw(LONG_DELAY_COUNTER_CW_BIT_INDEX downto LONG_DELAY_COUNTER_CW_BIT_INDEX-1),
            d => longZeros,
            q => currentLongCount
        );
	
	longCompare : genericCompare
        GENERIC MAP(LONG_DELAY_50Mhz_CONST_WIDTH)
        PORT MAP(x => LONG_DELAY_50Mhz_COUNTS, 
            y => currentLongCount, 
            g => open, 
            l => open,
            e => sw(LONG_DELAY_DONE_SW_BIT_INDEX)
        );

	shortCounter : genericCounter
        GENERIC MAP (SHORT_DELAY_50Mhz_CONST_WIDTH)
        PORT MAP(clk=>clk,
            resetn => resetn,
            c => cw(SHORT_DELAY_COUNTER_CW_BIT_INDEX downto SHORT_DELAY_COUNTER_CW_BIT_INDEX-1),
            d => shortZeros,
            q => currentShortCount
        );

	shortCompare : genericCompare
        GENERIC MAP(SHORT_DELAY_50Mhz_CONST_WIDTH)
        PORT MAP(x => SHORT_DELAY_50Mhz_COUNTS, 
            y => currentShortCount, 
            g => open, 
            l => open,
            e => sw(SHORT_DELAY_DONE_SW_BIT_INDEX)
        );
    
    -- sampling rate components
    sampleMux : genericMux4x1
        GENERIC MAP(32)
        PORT MAP(
            y0 => HIGHEST_RATE, 
            y1 => HIGH_RATE,
            y2 => LOWEST_RATE,
            y3 => LOW_RATE,
            s => cw(SAMPLING_RATE_SELECT_CW_BIT_INDEX downto SAMPLING_RATE_SELECT_CW_BIT_INDEX-1),
            f => currentRate

        );

    sampleCounter : genericCounter
        GENERIC MAP (32)
        PORT MAP(clk=>clk,
            resetn => resetn,
            c => cw(SAMPLING_COUNTER_CW_BIT_INDEX downto SAMPLING_COUNTER_CW_BIT_INDEX-1),
            d => zeros_vec32,
            q => sampleIndex
        );
    
    sampleCompare : genericCompare
        GENERIC MAP(32)
        PORT MAP(x => sampleIndex, 
            y => currentRate, 
            g => open, 
            l => open,
            e => sw(SAMPLE_SW_BIT_INDEX) -- end of smapling interval
        );

    triggerVoltConvert: entity work.toPixelValue(behavior)
        PORT MAP (
            ad7606SLV => STD_LOGIC_VECTOR(triggerVolt16bitSigned), -- this is totally wrong
            currentPixelV => trigVscr
        );
    
        
end behavior;
