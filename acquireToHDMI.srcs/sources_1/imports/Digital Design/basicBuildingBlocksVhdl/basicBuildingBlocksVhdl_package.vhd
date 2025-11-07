library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

package basicBuildingBlocks_package is

component flagRegister is
	generic (N: integer := 8);
	port(	clk: in  STD_LOGIC;
			resetn : in  STD_LOGIC;
			set, clear: in std_logic_vector(N-1 downto 0);
			Q: out std_logic_vector(N-1 downto 0));
end component;

	
	component genericAdder is
	    generic(N: integer := 4);
	    port(a,b: in std_logic_vector(N-1 downto 0);
		 sum: out std_logic_vector(N-1 downto 0));
	end component;

	component genericAdderSubtrctor is
	    generic(N: integer := 4);
	    port(a,b: in std_logic_vector(N-1 downto 0);
		 fnc: in std_logic;
		 sum: out std_logic_vector(N-1 downto 0));
	end component;

	component genericCompare is
	    generic(N: integer := 4);
	    port(x,y : in std_logic_vector(N-1 downto 0);
		 g,l,e: out std_logic);
	end component;

	component genericCompare_Signed is
	    generic(N: integer := 4);
	    port(x,y : in SIGNED(N-1 downto 0);
		 g,l,e: out std_logic);
	end component;

	component genericCounter is
	    generic(N: integer:=4);
	    port(clk,resetn : in std_logic;
		 c: in std_logic_vector(1 downto 0);
		 d : in  std_logic_vector(N-1 downto 0);
		 q : out std_logic_vector(N-1 downto 0));
	end component;


	component genericMux2x1 is
	    	generic(N: integer := 4);
    		port(y1,y0: in std_logic_vector(N-1 downto 0);
			 s: in std_logic;
			 f: out std_logic_vector(N-1 downto 0) );
	end component;

component genericMux4x1 is
    generic(N: integer := 8);
    port(y3,y2,y1,y0: in STD_LOGIC_VECTOR(N-1 downto 0);
	 s: in STD_LOGIC_VECTOR(1 downto 0);
	 f: out STD_LOGIC_VECTOR(N-1 downto 0) );
end component;

    component genericMux8x1 is
        generic(N: integer := 8);
        port(y7,y6,y5,y4,y3,y2,y1,y0: in STD_LOGIC_VECTOR(N-1 downto 0);
             s: in STD_LOGIC_VECTOR(2 downto 0);
             f: out STD_LOGIC_VECTOR(N-1 downto 0) );
    end component;

	component genericRegister is
        	generic(N: integer := 4);
        	port (  clk, resetn,load: in std_logic;
         	       d: in  std_logic_vector(N-1 downto 0);
          	      q: out std_logic_vector(N-1 downto 0) );
	end component;

	component genericRegister_Signed is
		generic(N: integer := 4);
		port (  clk, resetn,load: in std_logic;
         	       d: in  SIGNED(N-1 downto 0);
          	      q: out SIGNED(N-1 downto 0) );
	
	component decode3x8 is
            port(   dataIn :in STD_LOGIC;
                    sel :in STD_LOGIC_VECTOR(2 downto 0);
                    y : out STD_LOGIC_VECTOR(7 downto 0));
            end component;

           
    component generic8RegisterFile is
            generic(N: integer := 16);
            port (  clk, resetn: in STD_LOGIC;
                    write: in STD_LOGIC;
                    wrAddr: in  STD_LOGIC_VECTOR(2 downto 0);
                    rdAddr: in  STD_LOGIC_VECTOR(2 downto 0);
                    D: in STD_LOGIC_VECTOR(N-1 downto 0);
                    Q: out STD_LOGIC_VECTOR(N-1 downto 0) );
    end component;
            

end package;


