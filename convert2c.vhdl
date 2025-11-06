library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.acquireToHDMI_package.all;	
use work.scopeToHdmi_package.all;
use IEEE.NUMERIC_STD.ALL;

entity toPixelValue is
    PORT (
        ad7606SLV : in STD_LOGIC_VECTOR(15 downto 0);
        currentPixelV : out STD_LOGIC_VECTOR(VIDEO_WIDTH_IN_BITS - 1 downto 0)
    );
end toPixelValue;

architecture behavior of toPixelValue is
    signal mult_result : SIGNED(31 downto 0);
    signal div_result : SIGNED(31 downto 0);
    signal ad7606Signed : SIGNED(15 downto 0) := SIGNED(ad7606SLV);
    signal delta_y : SIGNED(15 downto 0) := TO_SIGNED(-500,16);
    signal y_intercept : SIGNED(15 downto 0) := TO_SIGNED(350,16); -- don't hardcode the 350, this should be (600+100)/2
    signal currentPixelV32 : SIGNED(31 downto 0);
begin
    mult_result <= ad7606Signed * delta_y;
    div_result <= SHIFT_RIGHT(mult_result, 16);
    currentPixelV32 <= div_result + y_intercept;
    currentPixelV <= STD_LOGIC_VECTOR(currentPixelV32(VIDEO_WIDTH_IN_BITS - 1 downto 0));

end behavior;