library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vga_generator is
    PORT (
      	VGA_R : out std_logic_vector(3 downto 0);
        VGA_G : out std_logic_vector(3 downto 0);
        VGA_B : out std_logic_vector(3 downto 0);
        VGA_HS : out std_logic;
        VGA_VS : out std_logic;
        ram_addr : out std_logic_vector(15 downto 0);
        ram_data : in std_logic_vector(31 downto 0);
        clk_in : in std_logic;
        resetn : in std_logic
);
end vga_generator;

architecture Behavioral of vga_generator is
-- 640x480 requires 25MHz pixel clock
	constant VISIBLE_LINES_PER_FRAME : integer := 480;
	constant LINES_PER_FRAME : integer := 521;
	constant VSYNC_FRONT_PORCH : integer := 10;
	constant VSYNC_WIDTH : integer := 2;
	constant VSYNC_BACK_PORCH : integer := 29;

	constant VISIBLE_PIXELS_PER_LINE : integer := 640;
	constant PIXELS_PER_LINE : integer := 800;
	constant HSYNC_FRONT_PORCH : integer := 16;
	constant HSYNC_WIDTH : integer := 96;
	constant HSYNC_BACK_PORCH : integer := 48;

	constant BITS_PER_PIXEL : integer := 4;
	constant PIXELS_PER_WORD : integer := 8;

	type state_type is (WAIT4ACK, EXTRAWAIT, WAIT4NEXT);
	signal state : state_type;

	signal pixel_clk : std_logic;
	signal line_count : integer range 0 to LINES_PER_FRAME;
	signal pixel_count : integer range 0 to 800;
	signal next_pixel_line : integer range 0 to LINES_PER_FRAME;
	signal next_pixel : integer range 0 to 800;
	signal hsync_internal : std_logic;
	signal display_valid, hdisplay_valid, vdisplay_valid : std_logic;

	signal pixel : std_logic_vector(BITS_PER_PIXEL-1 downto 0);
	signal pixnum : integer range 0 to PIXELS_PER_WORD-1;
	signal reg_pixel_data : std_logic_vector(BITS_PER_PIXEL*PIXELS_PER_WORD-1 downto 0);

begin

   clk_divider : entity work.clock_divider
       generic map ( divisor => 4 )
       port map ( clk_in => clk_in, reset => resetn, clk_out => pixel_clk );

   pixel_count_process: process( pixel_clk, resetn )
   begin
       if ( resetn = '0' ) then
           pixel_count <= 0;
       elsif ( pixel_clk'event and pixel_clk='1' ) then
         ------------------------------------------------
		 --complete the counter logic
		 ------------------------------------------------
		 if pixel_count = 800-1 then
		      pixel_count <= 0;
         else 
              pixel_count <= pixel_count + 1;
         end if;
       end if;
    end process;
    VGA_HS <= '0' when (pixel_count >= 640+16-1 and pixel_count < 640+16+96-1) else '1'; --change this

    line_count_process: process( pixel_clk, resetn, pixel_count )
    begin
        if ( resetn = '0' ) then
            line_count <= 0;
        elsif ( pixel_clk'event and pixel_clk='1' ) then
         ------------------------------------------------
		 --complete the counter logic
		 ------------------------------------------------
		 if line_count = 521-1 then
		      line_count <= 0;
         elsif pixel_count = 800-1 then
              line_count <= line_count + 1;
         end if;
        end if;
    end process;
    VGA_VS <= '0' when (line_count >= 480+10-1 and line_count < 480+10+2-1) else '1'; --change this

    vdisplay_valid <= '1' when line_count < 480 else '0'; -----------------------------------------------------------
    hdisplay_valid <= '1' when pixel_count < 640 else '0'; --give the assigments of the two valid siagnals
    display_valid  <= hdisplay_valid and vdisplay_valid;

    -- generate the address for the RAM based on the next pixel so that we get the data in time
    next_pixel <= (pixel_count+1) mod 800;
    next_pixel_line <= (line_count+1) mod 521;
    --give the assigments of these two siagnals
    
    ram_addr <= conv_std_logic_vector(((VISIBLE_PIXELS_PER_LINE/PIXELS_PER_WORD*next_pixel_line) +
                                         (next_pixel/PIXELS_PER_WORD)),16);
  
    -- the data from the memory is delayed by 3 pixels so delay it one more pixel to get it to line
    -- up with the pixel clock.
    process( clk_in )
    begin
        if (clk_in'event and clk_in='1') then
            reg_pixel_data <= ram_data;
        end if;
    end process;

    pixnum <= pixel_count mod PIXELS_PER_WORD;
    pixel <= reg_pixel_data(BITS_PER_PIXEL*pixnum+BITS_PER_PIXEL-1 downto BITS_PER_PIXEL*pixnum);

    VGA_R <= "1111" when display_valid = '1' and pixel(3 downto 2)="11" else
             "1011" when display_valid = '1' and pixel(3 downto 2)="10" else
             "0101" when display_valid = '1' and pixel(3 downto 2)="01" else
             "0000";
    VGA_G <= "1111" when display_valid = '1' and pixel(1)='1' else "0000";
    VGA_B <= "1111" when display_valid = '1' and pixel(0)='1' else "0000";
end Behavioral;
