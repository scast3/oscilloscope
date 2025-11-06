--------------------------------------------------------------------
-- Name:	Santiago Castillo
-- File:	acquireToHDMI_fsm.vhdl
------------------------------------------------------------------------- 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.acquireToHDMI_package.all;					-- include your library here with added components ac97, ac97cmd


entity acquireToHDMI_fsm is
    PORT (  clk : in  STD_LOGIC;
            resetn : in  STD_LOGIC;
            sw: in STD_LOGIC_VECTOR(SW_WIDTH - 1 downto 0);
            cw: out STD_LOGIC_VECTOR (CW_WIDTH - 1 downto 0));
end acquireToHDMI_fsm;

architecture Behavioral of acquireToHDMI_fsm is

	signal state: state_type;
	signal SHORT_DELAY_DONE_SW, LONG_DELAY_DONE_SW: STD_LOGIC; 
    signal FULL_SW, SAMPLE_SW, TRIGGER_SW, STORE_SW : STD_LOGIC;
	signal TRIG_CH1_SW, TRIG_CH2_SW, SINGLE_SW, FORCED_SW, BUSY_SW : STD_LOGIC;

begin

    SHORT_DELAY_DONE_SW <= sw(SHORT_DELAY_DONE_SW_BIT_INDEX);
	LONG_DELAY_DONE_SW <= sw(LONG_DELAY_DONE_SW_BIT_INDEX);
	FULL_SW <= sw(FULL_SW_BIT_INDEX);
	SAMPLE_SW <= sw(SAMPLE_SW_BIT_INDEX);
	TRIGGER_SW <= sw(TRIGGER_SW_BIT_INDEX);
	STORE_SW <= sw(STORE_SW_BIT_INDEX);

	TRIG_CH1_SW <= sw(TRIG_CH1_SW_BIT_INDEX);
	TRIG_CH2_SW <= sw(TRIG_CH2_SW_BIT_INDEX);

	SINGLE_SW <= sw(SINGLE_MODE_SW_BIT_INDEX);
	FORCED_SW <= sw(FORCED_MODE_SW_BIT_INDEX);
	
	BUSY_SW <= sw(AN7606_BUSY_SW_BIT_INDEX);
    
	-------------------------------------------------------------------------------
	-------------------------------------------------------------------------------
	state_proces: process(clk)  
	begin
		if (rising_edge(clk)) then
			if (resetn = '0') then 
				state <= RESET_STATE;
			else 
				case state is				
					when RESET_STATE =>
						  state <= LONG_DELAY;
					when LONG_DELAY =>
						if (LONG_DELAY_DONE_SW = '1') then
							state <= ADC_RST;
						end if;
					when ADC_RST =>
						if (SHORT_DELAY_DONE_SW = '1') then
							state <= WAIT_FORCED;
						end if;
					when WAIT_FORCED =>
						if (SINGLE_SW = '1') then
							state <= SET_STORE_FLAG;
						end if;
					when SET_STORE_FLAG =>
						state <= BEGIN_CONVST;
					when BEGIN_CONVST =>
						state <= ASSERT_CONVST;
					when CLEAR_STORE_FLAG =>
						state <= BEGIN_CONVST;
					when ASSERT_CONVST =>
						if (SHORT_DELAY_DONE_SW = '1') then
							state <= BUSY_0;
						end if;
					when BUSY_0 =>
						if (BUSY_SW = '1') then
							state <= BUSY_1;
						end if;
					when BUSY_1 =>
						if (BUSY_SW = '0') then
							state <= READ_CH1_LOW;
						end if;
					when READ_CH1_LOW =>
						if (SHORT_DELAY_DONE_SW = '0') then
							state <= READ_CH1_LOW;
						elsif (STORE_SW = '0') then
							state <= WRITE_CH1_TRIG;
						else
							state <= WRITE_CH1_BRAM;
						end if;							
					when WRITE_CH1_TRIG =>
						state <= READ_CH1_HIGH;
					when WRITE_CH1_BRAM =>
						state <= READ_CH1_HIGH;
					when READ_CH1_HIGH =>
						if (SHORT_DELAY_DONE_SW = '1') then
							state <= RST_SHORT;
						end if;
					when RST_SHORT =>
						state <= READ_CH2_LOW;
					when READ_CH2_LOW =>
						if (SHORT_DELAY_DONE_SW = '0') then
							state <= READ_CH2_LOW;
						elsif (STORE_SW = '0') then
							state <= WRITE_CH2_TRIG;
						else
							state <= WRITE_CH2_BRAM;
						end if;	
					when WRITE_CH2_TRIG =>
						state <= READ_CH2_HIGH;
					when WRITE_CH2_BRAM =>
						state <= READ_CH2_HIGH;
					when READ_CH2_HIGH =>
						if (SHORT_DELAY_DONE_SW = '1') then
							state <= WAIT_END_SAMP_INT;
						end if;
					when WAIT_END_SAMP_INT =>
						if (SAMPLE_SW = '0') then
							state <= WAIT_END_SAMP_INT;
						elsif (SAMPLE_SW = '0') then
							if (FULL_SW = '1') then
								state <= BRAM_FULL;
							else -- full=0
								if (FORCED_SW = '1') then
									state <= BEGIN_CONVST;
								elsif (STORE_SW ='0') then -- full = 0, forced = 0 row
									state <= SET_STORE_FLAG;
								else
									state <= BEGIN_CONVST;
								end if;
						end if;
					when BRAM_FULL =>
						if (FORCED_SW = '1') then
							state <= WAIT_FORCED;
						else 
							state <= CLEAR_STORE_FLAG;
						end if;
				end case;
			end if;
		end if;
	end process;

	-------------------------------------------------------------------------------
    -- Dedicated Control Word spreadsheet
    -------------------------------------------------------------------------------
	output_process: process (state)
	begin
		case state is		
            when RESET_STATE  =>  cw <= '0'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'1'&'1'&'1'&'0'&"11"&"11"&"00"&"11"&"11";
			when LONG_DELAY  =>  cw <= '0'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'1'&'1'&'0'&"00"&"00"&"00"&"10"&"00";
			when ADC_RST  =>  cw <= '0'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'1'&'1'&'1'&"00"&"00"&"00"&"11"&"00";
			when WAIT_FORCED  =>  cw <= '0'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'1'&'1'&'0'&"00"&"00"&"00"&"00"&"00";
			when SET_STORE_FLAG  =>  cw <= '0'&'1'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'1'&'1'&'0'&"00"&"00"&"00"&"00"&"00";
			when BEGIN_CONVST  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'1'&'1'&'1'&'0'&"00"&"10"&"00"&"00"&"11";
			when CLEAR_STORE_FLAG  =>  cw <= '1'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'0'&'1'&'1'&'0'&"00"&"00"&"00"&"00"&"00";
			when ASSERT_CONVST  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'1'&'1'&'1'&'0'&"00"&"10"&"00"&"00"&"10";
			when BUSY_0  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'0'&'1'&'1'&'0'&"00"&"10"&"00"&"00"&"11";
			when BUSY_1  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'0'&'1'&'1'&'0'&"11"&"10"&"00"&"00"&"00";
			when READ_CH1_LOW  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'0'&'0'&'0'&'0'&"10"&"10"&"00"&"00"&"10";
			when WRITE_CH1_TRIG  =>  cw <= '0'&'0'&'0'&'1'&'1'&'1'&'0'&'0'&'0'&'1'&'0'&'0'&"00"&"10"&"00"&"00"&"11";
			when WRITE_CH1_BRAM  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'1'&'0'&'1'&'0'&'0'&"10"&"10"&"00"&"00"&"11";
			when READ_CH1_HIGH  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'0'&'0'&'0'&'0'&"10"&"10"&"00"&"00"&"10";
			when RST_SHORT  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'0'&'1'&'0'&'0'&"11"&"10"&"00"&"00"&"11";
			when READ_CH2_LOW  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'0'&'0'&'0'&'0'&"10"&"10"&"00"&"00"&"10";
			when WRITE_CH2_TRIG  =>  cw <= '0'&'0'&'1'&'0'&'1'&'1'&'0'&'0'&'0'&'1'&'0'&'0'&"00"&"10"&"00"&"00"&"11";
			when WRITE_CH2_BRAM  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'1'&'0'&'0'&'1'&'0'&'0'&"10"&"10"&"00"&"00"&"11";
			when READ_CH2_HIGH  =>  cw <= '0'&'0'&'0'&'0'&'1'&'1'&'0'&'0'&'0'&'0'&'0'&'0'&"10"&"10"&"00"&"00"&"10";
			when WAIT_END_SAMP_INT  =>  cw <= '0'&'0'&'0'&'0'&'0'&'1'&'0'&'0'&'0'&'1'&'0'&'0'&"10"&"11"&"00"&"00"&"11";
			when BRAM_FULL  =>  cw <= '0'&'0'&'0'&'0'&'0'&'1'&'0'&'0'&'0'&'1'&'0'&'0'&"11"&"00"&"00"&"00"&"00";
		end case;
	end process;	                       

end Behavioral;



