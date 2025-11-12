library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.acquireToHDMI_package.all;
use work.scopeToHdmi_package.all;

entity toPixelValue is
    port (
        ad7606SLV     : in  std_logic_vector(15 downto 0);
        currentPixelV : out std_logic_vector(VIDEO_WIDTH_IN_BITS - 1 downto 0)
    );
end toPixelValue;

architecture behavior of toPixelValue is
    -- 16-bit signed signals
    signal ad7606_signed : signed(15 downto 0);
    signal delta_y       : signed(15 downto 0);
    signal y_intercept   : signed(15 downto 0);

    -- intermediate 32-bit signals for math
    signal mult_result   : signed(31 downto 0);
    signal div_result    : signed(31 downto 0);
    signal y_result      : signed(31 downto 0);
begin
    -- convert ADC input to signed
    ad7606_signed <= signed(ad7606SLV);

    -- scaling constants
    delta_y     <= to_signed(-500, 16);  -- slope
    y_intercept <= to_signed(350, 16);   -- vertical offset

    -- perform multiply and scale
    mult_result <= ad7606_signed * delta_y;
    div_result  <= shift_right(mult_result, 16);

    -- add offset
    y_result <= div_result + resize(y_intercept, 32);

    -- output as std_logic_vector (truncate to match video width)
    currentPixelV <= std_logic_vector(y_result(VIDEO_WIDTH_IN_BITS - 1 downto 0));
end behavior;