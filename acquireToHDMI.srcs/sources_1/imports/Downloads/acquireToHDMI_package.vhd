----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.scopeToHdmi_package.all;


package acquireToHDMI_package is


-- Clock period definitions
CONSTANT clk_period : time := 20 ns;			-- 50Mhz crystal input (XTL_IN).

type state_type is (RESET_STATE, LONG_DELAY, ADC_RST, WAIT_FORCED, SET_STORE_FLAG, BEGIN_CONVST, CLEAR_STORE_FLAG, 
  ASSERT_CONVST, BUSY_0, BUSY_1, READ_CH1_LOW, WRITE_CH1_TRIG, WRITE_CH1_BRAM, READ_CH1_HIGH, RST_SHORT, 
  READ_CH2_LOW, WRITE_CH2_TRIG, WRITE_CH2_BRAM, READ_CH2_HIGH, WAIT_END_SAMP_INT, BRAM_FULL);


---------------------------- CONTROL WORD -----------------------------
CONSTANT CW_WIDTH : NATURAL := 22;
CONSTANT CONTROL_CW_WIDTH : NATURAL := 10; -- is this right? verify

CONSTANT CLEAR_STORE_FLAG_CW_BIT_INDEX : NATURAL := 21;
CONSTANT SET_STORE_FLAG_CW_BIT_INDEX : NATURAL := 20;
CONSTANT TRIG_CH2_WRITE_CW_BIT_INDEX : NATURAL := 19;
CONSTANT TRIG_CH1_WRITE_CW_BIT_INDEX : NATURAL := 18;
CONSTANT CONVERSION_PLUS_READOUT_CW_BIT_INDEX : NATURAL := 17;
CONSTANT SAMPLE_TIMER_ROLLOVER_CW_BIT_INDEX : NATURAL := 16;
CONSTANT DATA_STORAGE_CH2_WRITE_CW_BIT_INDEX : NATURAL := 15;
CONSTANT DATA_STORAGE_CH1_WRITE_CW_BIT_INDEX : NATURAL := 14;
CONSTANT CONVST_CW_BIT_INDEX : NATURAL := 13;
CONSTANT RD_CW_BIT_INDEX : NATURAL := 12;
CONSTANT CS_CW_BIT_INDEX : NATURAL := 11;
CONSTANT RESET_AD7606_CW_BIT_INDEX : NATURAL := 10;
CONSTANT DATA_STORAGE_COUNTER_CW_BIT_INDEX : NATURAL := 9;
CONSTANT SAMPLING_COUNTER_CW_BIT_INDEX : NATURAL := 7;
CONSTANT SAMPLING_RATE_SELECT_CW_BIT_INDEX : NATURAL := 5;
CONSTANT LONG_DELAY_COUNTER_CW_BIT_INDEX : NATURAL := 3;
CONSTANT SHORT_DELAY_COUNTER_CW_BIT_INDEX : NATURAL := 1;

---------------------------- STATUS WORD -----------------------------
CONSTANT SW_WIDTH : NATURAL := 11;
CONSTANT DATAPATH_SW_WIDTH : NATURAL := 6; -- again, check

-- sw signals coming from the datapath
CONSTANT SHORT_DELAY_DONE_SW_BIT_INDEX : NATURAL := 0;
CONSTANT LONG_DELAY_DONE_SW_BIT_INDEX : NATURAL := 1;
CONSTANT FULL_SW_BIT_INDEX : NATURAL := 2;
CONSTANT SAMPLE_SW_BIT_INDEX : NATURAL := 3;
CONSTANT TRIGGER_SW_BIT_INDEX : NATURAL := 4;
CONSTANT STORE_SW_BIT_INDEX : NATURAL := 5;

-- external sw signals
CONSTANT TRIG_CH1_SW_BIT_INDEX : NATURAL := 6;
CONSTANT TRIG_CH2_SW_BIT_INDEX : NATURAL := 7;
CONSTANT SINGLE_MODE_SW_BIT_INDEX : NATURAL := 8;
CONSTANT FORCED_MODE_SW_BIT_INDEX : NATURAL := 9;
CONSTANT AN7606_BUSY_SW_BIT_INDEX : NATURAL := 10;


CONSTANT LONG_DELAY_50Mhz_CONST_WIDTH : NATURAL := 24;
CONSTANT LONG_DELAY_50Mhz_COUNTS : STD_LOGIC_VECTOR(LONG_DELAY_50Mhz_CONST_WIDTH - 1 downto 0) := x"00FFFF";

CONSTANT SHORT_DELAY_50Mhz_CONST_WIDTH : NATURAL := 8; 
CONSTANT SHORT_DELAY_50Mhz_COUNTS : STD_LOGIC_VECTOR(SHORT_DELAY_50Mhz_CONST_WIDTH - 1 downto 0) := x"10";

CONSTANT HIGHEST_RATE   : STD_LOGIC_VECTOR(31 downto 0) := STD_LOGIC_VECTOR(to_unsigned(300, 32));
CONSTANT HIGH_RATE      : STD_LOGIC_VECTOR(31 downto 0) := STD_LOGIC_VECTOR(to_unsigned(600, 32));
CONSTANT LOWEST_RATE    : STD_LOGIC_VECTOR(31 downto 0) := STD_LOGIC_VECTOR(to_unsigned(1200, 32));
CONSTANT LOW_RATE       : STD_LOGIC_VECTOR(31 downto 0) := STD_LOGIC_VECTOR(to_unsigned(2400, 32));

component acquireToHDMI_fsm is
    PORT (  clk : in  STD_LOGIC;
            resetn : in  STD_LOGIC;
            sw: in STD_LOGIC_VECTOR(SW_WIDTH - 1 downto 0);
            cw: out STD_LOGIC_VECTOR (CW_WIDTH - 1 downto 0));
end component;

component acquireToHDMI_datapath is
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
end component;

component acquireToHDMI is
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
end component;	

component an7606 is
    PORT ( clk : in  STD_LOGIC;
           an7606data: out STD_LOGIC_VECTOR(15 downto 0);
           an7606convst, an7606cs, an7606rd, an7606reset: in STD_LOGIC;
           an7606od: in STD_LOGIC_VECTOR(2 downto 0);
           an7606busy : out STD_LOGIC);
END component;

component blk_mem_gen_0 is
  PORT (
    clka : IN STD_LOGIC;
    ena : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END component;

end package;
