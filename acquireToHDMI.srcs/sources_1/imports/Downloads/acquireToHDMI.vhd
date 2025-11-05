--//////////Top Level for signal Acquisition /////////////////////////////--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.acquireToHDMI_package.all;					-- include your library here with added components ac97, ac97cmd
use work.scopeToHdmi_package.all;
use work.basicBuildingBlocks_package.all;					-- include your library here with added components ac97, ac97cmd
use IEEE.NUMERIC_STD.ALL;

entity acquireToHDMI is
    PORT ( clk : in  STD_LOGIC;
           resetn : in  STD_LOGIC;
		   btn: in	STD_LOGIC_VECTOR(2 downto 0);
		   triggerCh1, triggerCh2: out STD_LOGIC;		   
		   conversionPlusReadoutTime: out STD_LOGIC;
		   sampleTimerRollover: out STD_LOGIC;
		   
		   an7606data: in STD_LOGIC_VECTOR(15 downto 0);
		   an7606convst, an7606cs, an7606rd, an7606reset: out STD_LOGIC;
		   an7606od: out STD_LOGIC_VECTOR(2 downto 0);
		   an7606busy : in STD_LOGIC;
		   
		   tmdsDataP : out  STD_LOGIC_VECTOR (2 downto 0);
           tmdsDataN : out  STD_LOGIC_VECTOR (2 downto 0);
           tmdsClkP : out STD_LOGIC;
           tmdsClkN : out STD_LOGIC;
           hdmiOen:    out STD_LOGIC		   
		   );		   
end acquireToHDMI;

architecture behavior of acquireToHDMI is
    
    signal cw: STD_LOGIC_VECTOR(CW_WIDTH -1 downto 0);
    signal sw: STD_LOGIC_VECTOR(SW_WIDTH -1 downto 0);
    signal forcedMode: STD_LOGIC;
    signal triggerVolts : SIGNED(15 downto 0); 
    signal triggerTimePix : STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS-1 downto 0);
        	
begin
    triggerVolts <= (others => '0');
    triggerTimePix <= (others => '0');

    conversionPlusReadoutTime <= cw(CONVERSION_PLUS_READOUT_CW_BIT_INDEX);
    sampleTimerRollover <= cw(SAMPLE_TIMER_ROLLOVER_CW_BIT_INDEX);
    
    an7606convst <= cw(CONVST_CW_BIT_INDEX);    
    an7606od <= "000"; 

    ------------------------------------------------------------------------------
    -- Button Process
    ------------------------------------------------------------------------------

    
    
    sw(FORCED_MODE_SW_BIT_INDEX) <= btn(0);
    triggerCh2 <= sw(TRIG_CH2_SW_BIT_INDEX);

 	datapath_inst: acquireToHDMI_datapath 
        PORT MAP (
            clk => clk,
            resetn => resetn,
            cw => cw,
            sw => sw(DATAPATH_SW_WIDTH - 1 downto 0),
            an7606data => an7606data,
            triggerVolt16bitSigned => triggerVolts,
            triggerTimePixel => triggerTimePix,
            ch1Data16bitSLV => open,
            ch2Data16bitSLV => open,
            tmdsDataP => tmdsDataP,
            tmdsDataN => tmdsDataN,
            tmdsClkP => tmdsClkP,
            tmdsClkN => tmdsClkN,
            hdmiOen => hdmiOen
	);
                
	control_inst: acquireToHDMI_fsm 
	   PORT MAP ( 
            clk => clk,
            resetn => resetn,
            sw => sw,
            cw => cw);

end behavior;
