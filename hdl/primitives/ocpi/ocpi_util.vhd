library ieee; use ieee.std_logic_1164.all, ieee.numeric_std.all;
library ocpi; use ocpi.types.all;
package util is
function width_for_max (n : natural) return natural;
component FIFO2
  generic (width   : natural := 1; \guarded\ : natural := 1);
  port(    CLK     : in  std_logic;
           RST     : in  std_logic;
           D_IN    : in  std_logic_vector(width - 1 downto 0);
           ENQ     : in  std_logic;
           DEQ     : in  std_logic;
           CLR     : in  std_logic;
           FULL_N  : out std_logic;
           EMPTY_N : out std_logic;
           D_OUT   : out std_logic_vector(width - 1 downto 0));
end component FIFO2;

component message_bounds
  port(Clk          : in  std_logic;
       RST          : in  bool_t;
       -- input side interface
       som_in       : in  bool_t;
       valid_in     : in  bool_t;
       eom_in       : in  bool_t;
       take_in      : in  bool_t; -- input side is taking the input from the input port
       -- core facing signals
       core_out     : in  bool_t; -- output side has a valid value
       core_ready   : in  bool_t;
       core_enable  : out bool_t;
       -- output side interface
       ready_out    : in  bool_t; -- output side may produce
       som_out      : out bool_t;
       eom_out      : out bool_t;
       valid_out    : out bool_t;
       give_out     : out bool_t);
end component message_bounds;

component clock_limiter
  generic(width : natural);
  port(clk      : in std_logic;
       rst      : in bool_t;
       factor   : in unsigned(width-1 downto 0);
       enabled  : in bool_t;
       ready    : out bool_t);
end component clock_limiter;

end package util;