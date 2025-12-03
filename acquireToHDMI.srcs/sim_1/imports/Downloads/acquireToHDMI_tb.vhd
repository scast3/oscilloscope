--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;		
use work.acquireToHDMI_package.all;					-- include your library here with added components ac97, ac97cmd

ENTITY acquireToHDMI_tb IS
END acquireToHDMI_tb;
 
ARCHITECTURE behavior OF acquireToHDMI_tb is

   --Inputs
   signal clk_t : STD_LOGIC; 
   signal resetn_t : STD_LOGIC; 
   signal btn_t : STD_LOGIC_VECTOR(2 downto 0);
   signal ch1enb_t, ch2enb_t : STD_LOGIC;
   
   signal triggerCh1_t, triggerCh2_t: STD_LOGIC;		   
   signal conversionPlusReadoutTime_t: STD_LOGIC;
   signal sampleTimerRollover_t: STD_LOGIC;
   
   signal an7606data_t : STD_LOGIC_VECTOR (15 downto 0);
   signal an7606convst_t : STD_LOGIC;   
   signal an7606cs_t : STD_LOGIC;   
   signal an7606rd_t : STD_LOGIC; 
   signal an7606reset_t : STD_LOGIC;   
   signal an7606od_t : STD_LOGIC_VECTOR (2 downto 0);
   signal an7606busy_t : STD_LOGIC;   
   
   signal tmdsClkN_t, tmdsClkP_t: STD_LOGIC;
   signal hdmiOen_t: STD_LOGIC;
   signal sampleRate_select_t : STD_LOGIC_VECTOR(1 downto 0);
   
	
BEGIN
    sampleRate_select_t <= "00";
    
    an7606_inst: an7606
        PORT MAP (  clk => clk_t,
		            an7606data => an7606data_t,
		            an7606convst => an7606convst_t,
		            an7606cs => an7606cs_t,
		            an7606rd => an7606rd_t,
		            an7606reset => an7606reset_t,
		            an7606od => an7606od_t,
		            an7606busy => an7606busy_t);	
 
    uut: acquireToHDMI 
        PORT MAP (  clk => clk_t,
                    resetn => resetn_t,
                    single_mode => btn_t(0),
                    forced_mode => btn_t(1),
                    
                    triggerCh1 => triggerCh1_t,
                    triggerCh2 => triggerCh2_t,		   
		            conversionPlusReadoutTime => conversionPlusReadoutTime_t,
		            sampleTimerRollover => sampleTimerRollover_t,
		            
		            ch1enb => '1',
		            ch2enb => '1',
		   
		            an7606data => an7606data_t,
		            an7606convst => an7606convst_t,
		            an7606cs => an7606cs_t,
		            an7606rd => an7606rd_t,
		            an7606reset => an7606reset_t,
		            an7606od => an7606od_t,
		            an7606busy => an7606busy_t,	
                   tmdsDataP => open,
                   tmdsDataN => open,
                   tmdsClkP => tmdsClkP_t,
                   tmdsClkN => tmdsClkN_t,
                   hdmiOen => hdmiOen_t,
                   triggerVolt16bitSigned => (others => '0'),
                   triggerTime => (others => '0'),
                   ch1Data16bitSLV => open,
                   ch2Data16bitSLV => open,
                   sampleRate_select => "00"); 	
           
           
    resetn_t <= '0', '1' after clk_period;		

   -- Clock process definitions
   clk_process :process
   begin
		clk_t <= '0';
		wait for clk_period/2;
		clk_t <= '1';
		wait for clk_period/2;
   end process;   

    -- Button press from user after ad7606reset
    button_process :process
    begin
        
        btn_t <= "000"; 
        wait until (resetn_t = '1');
        wait for clk_period;
        
        -- commment out the following for forced mode
        -- btn_t <= "010";     -- trigger mode
        
        wait until (an7606reset_t = '1');
        wait until (an7606reset_t = '0');
        wait for 100ns;

        -- Leave this line in regardless of the mode
        btn_t <= "001"; -- single mode
        
        wait for 4*clk_period;
        btn_t <= "000";
        wait;
    end process;   

END behavior;
