library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.acquireToHDMI_package.all;
use work.scopeToHdmi_package.all;
use work.basicBuildingBlocks_package.all;

entity final_oscope_slave_lite_v1_0_S00_AXI is
generic (
-- Users to add parameters here
       
-- User parameters ends
-- Do not modify the parameters beyond this line

-- Width of S_AXI data bus
C_S_AXI_DATA_WIDTH : integer := 32;
-- Width of S_AXI address bus
C_S_AXI_ADDR_WIDTH : integer := 6
);
port (
-- Users to add ports here
        an7606data_ext: in STD_LOGIC_VECTOR(15 downto 0);
       an7606convst_ext, an7606cs_ext, an7606rd_ext, an7606reset_ext: out STD_LOGIC;
       an7606od_ext: out STD_LOGIC_VECTOR(2 downto 0);
       an7606busy_ext : in STD_LOGIC;
       
       tmdsDataP_ext : out  STD_LOGIC_VECTOR (2 downto 0);
       tmdsDataN_ext : out  STD_LOGIC_VECTOR (2 downto 0);
       tmdsClkP_ext : out STD_LOGIC;
       tmdsClkN_ext : out STD_LOGIC;
       hdmiOen_ext:    out STD_LOGIC;
-- User ports ends
-- Do not modify the ports beyond this line

-- Global Clock Signal
S_AXI_ACLK : in std_logic;
-- Global Reset Signal. This Signal is Active LOW
S_AXI_ARESETN : in std_logic;
-- Write address (issued by master, acceped by Slave)
S_AXI_AWADDR : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
-- Write channel Protection type. This signal indicates the
    -- privilege and security level of the transaction, and whether
    -- the transaction is a data access or an instruction access.
S_AXI_AWPROT : in std_logic_vector(2 downto 0);
-- Write address valid. This signal indicates that the master signaling
    -- valid write address and control information.
S_AXI_AWVALID : in std_logic;
-- Write address ready. This signal indicates that the slave is ready
    -- to accept an address and associated control signals.
S_AXI_AWREADY : out std_logic;
-- Write data (issued by master, acceped by Slave)
S_AXI_WDATA : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
-- Write strobes. This signal indicates which byte lanes hold
    -- valid data. There is one write strobe bit for each eight
    -- bits of the write data bus.    
S_AXI_WSTRB : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
-- Write valid. This signal indicates that valid write
    -- data and strobes are available.
S_AXI_WVALID : in std_logic;
-- Write ready. This signal indicates that the slave
    -- can accept the write data.
S_AXI_WREADY : out std_logic;
-- Write response. This signal indicates the status
    -- of the write transaction.
S_AXI_BRESP : out std_logic_vector(1 downto 0);
-- Write response valid. This signal indicates that the channel
    -- is signaling a valid write response.
S_AXI_BVALID : out std_logic;
-- Response ready. This signal indicates that the master
    -- can accept a write response.
S_AXI_BREADY : in std_logic;
-- Read address (issued by master, acceped by Slave)
S_AXI_ARADDR : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
-- Protection type. This signal indicates the privilege
    -- and security level of the transaction, and whether the
    -- transaction is a data access or an instruction access.
S_AXI_ARPROT : in std_logic_vector(2 downto 0);
-- Read address valid. This signal indicates that the channel
    -- is signaling valid read address and control information.
S_AXI_ARVALID : in std_logic;
-- Read address ready. This signal indicates that the slave is
    -- ready to accept an address and associated control signals.
S_AXI_ARREADY : out std_logic;
-- Read data (issued by slave)
S_AXI_RDATA : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
-- Read response. This signal indicates the status of the
    -- read transfer.
S_AXI_RRESP : out std_logic_vector(1 downto 0);
-- Read valid. This signal indicates that the channel is
    -- signaling the required read data.
S_AXI_RVALID : out std_logic;
-- Read ready. This signal indicates that the master can
    -- accept the read data and response information.
S_AXI_RREADY : in std_logic
);
end final_oscope_slave_lite_v1_0_S00_AXI;

architecture arch_imp of final_oscope_slave_lite_v1_0_S00_AXI is

-- AXI4LITE signals
signal axi_awaddr : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
signal axi_awready : std_logic;
signal axi_wready : std_logic;
signal axi_bresp : std_logic_vector(1 downto 0);
signal axi_bvalid : std_logic;
signal axi_araddr : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
signal axi_arready : std_logic;
signal axi_rresp : std_logic_vector(1 downto 0);
signal axi_rvalid : std_logic;

-- Example-specific design signals
-- local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
-- ADDR_LSB is used for addressing 32/64 bit registers/memories
-- ADDR_LSB = 2 for 32 bits (n downto 2)
-- ADDR_LSB = 3 for 64 bits (n downto 3)
constant ADDR_LSB  : integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
constant OPT_MEM_ADDR_BITS : integer := 3;
------------------------------------------------
---- Signals for user logic register space example
--------------------------------------------------
---- Number of Slave Registers 10
signal slv_reg0 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg1 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg2 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg3 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg4 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg5 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg6 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg7 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg8 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal slv_reg9 :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
signal byte_index : integer;

signal mem_logic  : std_logic_vector(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

--State machine local parameters
constant Idle : std_logic_vector(1 downto 0) := "00";
constant Raddr: std_logic_vector(1 downto 0) := "10";
constant Rdata: std_logic_vector(1 downto 0) := "11";
constant Waddr: std_logic_vector(1 downto 0) := "10";
constant Wdata: std_logic_vector(1 downto 0) := "11";
--State machine variables
signal state_read : std_logic_vector(1 downto 0);
signal state_write: std_logic_vector(1 downto 0);

component acquireToHdmi is
PORT ( clk : in  STD_LOGIC;
           resetn : in  STD_LOGIC;
           
  flag_clear : in STD_LOGIC;
  flag_q : out STD_LOGIC;
  
  single_mode : in  STD_LOGIC; -- control reg
  forced_mode : in  STD_LOGIC; -- control reg
  ch1enb, ch2enb : in STD_LOGIC; -- control reg
  sampleRate_select : in STD_LOGIC_VECTOR(1 downto 0); -- control reg
 
  triggerCh1, triggerCh2: out STD_LOGIC; -- status reg  
  conversionPlusReadoutTime: out STD_LOGIC; -- status reg
  sampleTimerRollover: out STD_LOGIC; -- status reg
 
  an7606data: in STD_LOGIC_VECTOR(15 downto 0);
  an7606convst, an7606cs, an7606rd, an7606reset: out STD_LOGIC;
  an7606od: out STD_LOGIC_VECTOR(2 downto 0);
  an7606busy : in STD_LOGIC;
 
  tmdsDataP : out  STD_LOGIC_VECTOR (2 downto 0);
           tmdsDataN : out  STD_LOGIC_VECTOR (2 downto 0);
           tmdsClkP : out STD_LOGIC;
           tmdsClkN : out STD_LOGIC;
           hdmiOen:    out STD_LOGIC;
           
           triggerVolt16bitSigned: in SIGNED(15 downto 0); -- reg1
           triggerTime: in STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS-1 downto 0); -- reg2
           ch1Data16bitSLV, ch2Data16bitSLV: out STD_LOGIC_VECTOR(15 downto 0) --reg 3 and 4  
  );
    end component;
    signal ch1_data_int : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- read
    signal ch2_data_int : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- read
    -- signal trig_volt_int : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- write
    -- signal trig_time_int : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- write
    -- signal control_reg_int : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- write
    signal status_reg_int : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- read
    
    -- signal univ_reset : std_logic;
begin
-- I/O Connections assignments

S_AXI_AWREADY <= axi_awready;
S_AXI_WREADY <= axi_wready;
S_AXI_BRESP <= axi_bresp;
S_AXI_BVALID <= axi_bvalid;
S_AXI_ARREADY <= axi_arready;
S_AXI_RRESP <= axi_rresp;
S_AXI_RVALID <= axi_rvalid;
   mem_logic     <= S_AXI_AWADDR(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) when (S_AXI_AWVALID = '1') else axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);

-- Implement Write state machine
-- Outstanding write transactions are not supported by the slave i.e., master should assert bready to receive response on or before it starts sending the new transaction
process (S_AXI_ACLK)                                      
  begin                                      
    if rising_edge(S_AXI_ACLK) then                                      
       if S_AXI_ARESETN = '0' then                                      
         --asserting initial values to all 0's during reset                                      
         axi_awready <= '0';                                      
         axi_wready <= '0';                                      
         axi_bvalid <= '0';                                      
         axi_bresp <= (others => '0');                                      
         state_write <= Idle;                                      
       else                                      
         case (state_write) is                                      
            when Idle => --Initial state inidicating reset is done and ready to receive read/write transactions                                      
              if (S_AXI_ARESETN = '1') then                                      
                axi_awready <= '1';                                      
                axi_wready <= '1';                                      
                state_write <= Waddr;                                      
              else state_write <= state_write;                                      
              end if;                                      
            when Waddr => --At this state, slave is ready to receive address along with corresponding control signals and first data packet. Response valid is also handled at this state                                      
              if (S_AXI_AWVALID = '1' and axi_awready = '1') then                                      
                axi_awaddr <= S_AXI_AWADDR;                                      
                if (S_AXI_WVALID = '1') then                                      
                  axi_awready <= '1';                                      
                  state_write <= Waddr;                                      
                  axi_bvalid <= '1';                                      
                else                                      
                  axi_awready <= '0';                                      
                  state_write <= Wdata;                                      
                  if (S_AXI_BREADY = '1' and axi_bvalid = '1') then                                      
                    axi_bvalid <= '0';                                      
                  end if;                                      
                end if;                                      
              else                                        
                state_write <= state_write;                                      
                if (S_AXI_BREADY = '1' and axi_bvalid = '1') then                                      
                  axi_bvalid <= '0';                                      
                end if;                                      
              end if;                                      
            when Wdata => --At this state, slave is ready to receive the data packets until the number of transfers is equal to burst length                                      
              if (S_AXI_WVALID = '1') then                                      
                state_write <= Waddr;                                      
                axi_bvalid <= '1';                                      
                axi_awready <= '1';                                      
              else                                      
                state_write <= state_write;                                      
                if (S_AXI_BREADY ='1' and axi_bvalid = '1') then                                      
                  axi_bvalid <= '0';                                      
                end if;                                      
              end if;                                      
            when others =>      --reserved                                      
              axi_awready <= '0';                                      
              axi_wready <= '0';                                      
              axi_bvalid <= '0';                                      
          end case;                                      
       end if;                                      
     end if;                                                
end process;                                      
-- Implement memory mapped register select and write logic generation
-- The write data is accepted and written to memory mapped registers when
-- axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
-- select byte enables of slave registers while writing.
-- These registers are cleared when reset (active low) is applied.
-- Slave register write enable is asserted when valid address and data are available
-- and the slave is ready to accept the write address and write data.


process (S_AXI_ACLK)
begin
 if rising_edge(S_AXI_ACLK) then
   if S_AXI_ARESETN = '0' then
     slv_reg0 <= (others => '0');
     slv_reg1 <= (others => '0');
     slv_reg2 <= (others => '0');
     slv_reg3 <= (others => '0');
     slv_reg4 <= (others => '0');
     slv_reg5 <= (others => '0');
     slv_reg6 <= (others => '0');
     slv_reg7 <= (others => '0');
     slv_reg8 <= (others => '0');
     slv_reg9 <= (others => '0');
   else
     if (S_AXI_WVALID = '1') then
         case (mem_logic) is
         when b"0000" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 0
               slv_reg0(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"0001" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 1
               slv_reg1(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"0010" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 2
               slv_reg2(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"0011" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 3
               slv_reg3(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"0100" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 4
               slv_reg4(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"0101" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 5
               slv_reg5(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"0110" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 6
               slv_reg6(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"0111" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 7
               slv_reg7(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"1000" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 8
               slv_reg8(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when b"1001" =>
           for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
             if ( S_AXI_WSTRB(byte_index) = '1' ) then
               -- Respective byte enables are asserted as per write strobes                  
               -- slave registor 9
               slv_reg9(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
             end if;
           end loop;
         when others =>
           slv_reg0 <= slv_reg0;
           slv_reg1 <= slv_reg1;
           slv_reg2 <= slv_reg2;
           slv_reg3 <= slv_reg3;
           slv_reg4 <= slv_reg4;
           slv_reg5 <= slv_reg5;
           slv_reg6 <= slv_reg6;
           slv_reg7 <= slv_reg7;
           slv_reg8 <= slv_reg8;
           slv_reg9 <= slv_reg9;
       end case;
     end if;
   end if;
 end if;                  
end process;

-- Implement read state machine
process (S_AXI_ACLK)                                          
  begin                                          
    if rising_edge(S_AXI_ACLK) then                                          
       if S_AXI_ARESETN = '0' then                                          
         --asserting initial values to all 0's during reset                                          
         axi_arready <= '0';                                          
         axi_rvalid <= '0';                                          
         axi_rresp <= (others => '0');                                          
         state_read <= Idle;                                          
       else                                          
         case (state_read) is                                          
           when Idle => --Initial state inidicating reset is done and ready to receive read/write transactions                                          
               if (S_AXI_ARESETN = '1') then                                          
                 axi_arready <= '1';                                          
                 state_read <= Raddr;                                          
               else state_read <= state_read;                                          
               end if;                                          
           when Raddr => --At this state, slave is ready to receive address along with corresponding control signals                                          
               if (S_AXI_ARVALID = '1' and axi_arready = '1') then                                          
                 state_read <= Rdata;                                          
                 axi_rvalid <= '1';                                          
                 axi_arready <= '0';                                          
                 axi_araddr <= S_AXI_ARADDR;                                          
               else                                          
                 state_read <= state_read;                                          
               end if;                                          
           when Rdata => --At this state, slave is ready to send the data packets until the number of transfers is equal to burst length                                          
               if (axi_rvalid = '1' and S_AXI_RREADY = '1') then                                          
                 axi_rvalid <= '0';                                          
                 axi_arready <= '1';                                          
                 state_read <= Raddr;                                          
               else                                          
                 state_read <= state_read;                                          
               end if;                                          
           when others =>      --reserved                                          
               axi_arready <= '0';                                          
               axi_rvalid <= '0';                                          
          end case;                                          
        end if;                                          
      end if;                                                  
 end process;                                          
-- Implement memory mapped register select and read logic generation
S_AXI_RDATA <= ch1_data_int when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "000" ) else
ch2_data_int when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0001" ) else
status_reg_int when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0010" ) else
slv_reg3 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0011" ) else
slv_reg4 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0100" ) else
slv_reg5 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0101" ) else
slv_reg6 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0110" ) else
slv_reg7 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "0111" ) else
slv_reg8 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "1000" ) else
slv_reg9 when (axi_araddr(ADDR_LSB+OPT_MEM_ADDR_BITS downto ADDR_LSB) = "1001" ) else
(others => '0');

-- Add user logic here
    -- univ_reset <= S_AXI_ARESETN and (not(slv_reg3(6))); -- when slvreg3(6) bit is 1, the system will reset
    oscope_inst : acquireToHdmi
    PORT MAP(
        clk => S_AXI_ACLK,
        resetn => S_AXI_ARESETN,
        flag_clear => slv_reg3(7),
        flag_q => status_reg_int(4),
        single_mode => slv_reg3(0),
        forced_mode => slv_reg3(1),
        ch1enb => slv_reg3(2),
        ch2enb => slv_reg3(3),
        sampleRate_select => slv_reg3(5 downto 4),
       
        triggerCh1 => status_reg_int(0),
        triggerCh2 => status_reg_int(1),
        conversionPlusReadoutTime => status_reg_int(2),
        sampleTimerRollover => status_reg_int(3),
       
        an7606data => an7606data_ext,
       an7606convst => an7606convst_ext,
       an7606cs => an7606cs_ext,
       an7606rd => an7606rd_ext,
       an7606reset => an7606reset_ext,
       an7606od => an7606od_ext,
       an7606busy => an7606busy_ext,
       
       tmdsDataP => tmdsDataP_ext,
       tmdsDataN => tmdsDataN_ext,
       tmdsClkP => tmdsClkP_ext,
       tmdsClkN => tmdsClkN_ext,
       hdmiOen => hdmiOen_ext,
       
       triggerVolt16bitSigned => signed(slv_reg4(15 downto 0)),
       triggerTime => slv_reg5(VIDEO_WIDTH_IN_BITS-1 downto 0),
       ch1Data16bitSLV => ch1_data_int(15 downto 0),
       ch2Data16bitSLV => ch2_data_int(15 downto 0)
    );  
-- User logic ends

end arch_imp;