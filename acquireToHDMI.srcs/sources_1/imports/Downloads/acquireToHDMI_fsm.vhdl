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

	signal state: state_type;	-- define the state_type in your package file	
	signal SHORT_DELAY_DONE_SW,: STD_LOGIC;
	signal LONG_DELAY_DONE_SW,: STD_LOGIC;  
    signal FORCED_MODE_SW, STORE_INTO_BRAM_SW, CH1_TRIGGER_SW: STD_LOGIC;
begin

    SHORT_DELAY_DONE_SW <= sw(SHORT_DELAY_DONE_SW_BIT_INDEX);
	LONG_DELAY_DONE_SW <= sw(LONG_DELAY_DONE_SW_BIT_INDEX);
	BUSY_SW <= sw(BUSY_SW_BIT_INDEX);
    
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
					when SET_STORE_FLAG =>
					when BEGIN_CONVST =>
					when CLEAR_STORE_FLAG =>
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
					when WRITE_CH1_TRIG =>
					when WRITE_CH1_BRAM =>
					when READ_CH1_HIGH =>
						if (SHORT_DELAY_DONE_SW = '1') then
							state <= RST_SHORT;
						end if;
					when RST_SHORT =>
						state <= READ_CH2_LOW;
					when READ_CH2_LOW =>
					when WRITE_CH2_TRIG =>
					when WRITE_CH2_BRAM =>
					when READ_CH2_HIGH =>
						if (SHORT_DELAY_DONE_SW = '1') then
							state <= WAIT_END_SAMP_INT;
						end if;
					when WAIT_END_SAMP_INT =>
					when BRAM_FULL =>
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
		end case;
	end process;	                       

end Behavioral;



