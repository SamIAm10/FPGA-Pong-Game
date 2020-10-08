--------------------------------------------------------------------------------
-- Company: UNIVERSITY OF CONNECTICUT
-- Engineer: John A. Chandy
--
-- Create Date:    08/04/05
-- Module Name:    clock_divider - Behavioral
-- Additional Comments:
--   This clock_divider module takes in a clock and divides by the generic
--   divisor parameter.  If divisor is a power of 2, this code may not
--   synthesize to the most efficient implementation.
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity clock_divider is
	generic  (divisor : positive := 2);
	port ( clk_in : in std_logic;
			 reset : in std_logic;
          clk_out : out std_logic);
end clock_divider;


architecture Behavioral of clock_divider is
	signal clk : std_logic;
begin													 

	process(clk_in,reset)
		variable vcount : natural range 0 to divisor/2-1;
	begin
		if ( reset='0' ) then
			vcount := 0;
			clk <= '0';
		elsif (clk_in'event and clk_in = '1' ) then
			if ( vcount = divisor/2-1 ) then
				vcount := 0;
				clk <= not clk;
			else
				vcount := vcount + 1;
			end if;
		end if;
	end process;

	clk_out <= clk;

end Behavioral;
