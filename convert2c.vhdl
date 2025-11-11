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
    signal div_result16 : SIGNED(15 downto 0);
    signal ad7606Signed : SIGNED(15 downto 0);
    signal delta_y : SIGNED(15 downto 0);
    signal y_intercept : SIGNED(15 downto 0); -- don't hardcode the 350, this should be (600+100)/2
    signal currentPixelV16 : SIGNED(15 downto 0);
    signal currentPixelV_SLV : STD_LOGIC_VECTOR(15 downto 0);
begin
    delta_y <= TO_SIGNED(-500,16);
    y_intercept <= TO_SIGNED(350,16);
    ad7606Signed <= SIGNED(ad7606SLV);

    mult_result <= ad7606Signed * delta_y; -- generates 32 bit signal
    div_result <= SHIFT_RIGHT(mult_result, 16);
    div_result16 <= div_result(15 downto 0);
    currentPixelV16 <= div_result16 + y_intercept;
    currentPixelV_SLV <= STD_LOGIC_VECTOR(currentPixelV16);
    currentPixelV <= currentPixelV_SLV(VIDEO_WIDTH_IN_BITS - 1 downto 0);

end behavior;