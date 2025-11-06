library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.acquireToHDMI_package.all;	
use work.scopeToHdmi_package.all;

entity toPixelValue is
    PORT (
        dataOutput : in STD_LOGIC_VECTOR(15 downto 0);
        currentPixelV : out STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0);
    );
end toPixelValue;

architecture behavior of toPixelValue is

begin


end behavior;