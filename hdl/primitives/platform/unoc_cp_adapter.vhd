library IEEE; use IEEE.std_logic_1164.all, IEEE.numeric_std.all;
library ocpi; use ocpi.all, ocpi.types.all;
library work; use work.platform_pkg.all;

entity unoc_cp_adapter is
  port(
    -- I'm a unoc client, connecting to the NOC
    client_in  : in  unoc_master_out_t;
    client_out : out unoc_master_in_t;
    -- I'm connecting to occp
    cp_in      : in  occp_out_t;
    cp_out     : out occp_in_t
    );
end entity unoc_cp_adapter;

architecture rtl of unoc_cp_adapter is
  -- The verilog being wrapped
  component mkTLPSerializer is
    port(
      pciDevice               : in  std_logic_vector(15 downto 0);
      CLK                     : in  std_logic;
      RST_N                   : in  std_logic;
      -- action method server_request_put
      server_request_put      : in  std_logic_vector(unoc_data_width-1 downto 0);
      EN_server_request_put   : in  std_logic ;
      RDY_server_request_put  : out std_logic;

      -- actionvalue method server_response_get
      EN_server_response_get  : in  std_logic ;
      server_response_get     : out std_logic_vector(unoc_data_width-1 downto 0);
      RDY_server_response_get : out std_logic;

      -- actionvalue method client_request_get
      EN_client_request_get   : in  std_logic ;
      client_request_get      : out std_logic_vector(58 downto 0);
      RDY_client_request_get  : out std_logic;

      -- action method client_response_put
      client_response_put     : in  std_logic_vector(39 downto 0);
      EN_client_response_put  : in  std_logic;
      RDY_client_response_put : out std_logic
      );
  end component mkTLPSerializer;
  signal RDY_server_request_put  : std_logic;
  signal EN_server_request_put   : std_logic;
  signal RDY_client_response_put : std_logic;
  signal EN_client_response_put  : std_logic;
  signal server_response_get     : std_logic_vector(unoc_data_width-1 downto 0);
  -- Our request and response bundles
  signal request : std_logic_vector(58 downto 0);
  signal response : std_logic_vector(39 downto 0);
begin
  -- The outoing take signal is a DEQ to the producer side computed by us
  -- The incoming valid signal is an indication of not empty from the producer side
  EN_server_request_put <= client_in.valid and RDY_server_request_put;
  client_out.take       <= EN_server_request_put;
  client_out.data       <= to_unoc(server_response_get);
  EN_client_response_put <= cp_in.valid and RDY_client_response_put;

  -- Using this adapter means using the unoc clk and reset as the control clk and reset
  cp_out.clk          <= client_in.clk;
  cp_out.reset        <= not client_in.reset_n;
  -- request fields to occp
  cp_out.is_read      <= request(58);
  cp_out.address      <= request(25 downto 4)
                         when request(58) = '1' else
                         request(57 downto 36);
  cp_out.byte_en      <= request(3 downto 0)
                         when request(58) = '1' else
                         request(35 downto 32);
  cp_out.data         <= x"000000" & request(33 downto 26)
                         when request(58) = '1' else
                         request(31 downto 0);
  cp_out.take         <= EN_client_response_put;

  response            <= cp_in.tag & cp_in.data;


  tlps : mkTLPSerializer
    port map(
      CLK                    => client_in.clk,
      RST_N                  => client_in.reset_n,
      pciDevice              => client_in.id,
      -- action method server_request_put - we are the consumer of these requests
      server_request_put     => to_slv(client_in.data),
      EN_server_request_put  => EN_server_request_put,
      RDY_server_request_put => RDY_server_request_put,

      -- actionvalue method server_response_get - we are the producer of these responses
      EN_server_response_get  => client_in.take,
      server_response_get     => server_response_get,
      RDY_server_response_get => client_out.valid,

      -- actionvalue method client_request_get - we are the producer of these requests
      EN_client_request_get   => cp_in.take,
      client_request_get      => request,
      RDY_client_request_get  => cp_out.valid,

      -- action method client_response_put - we are the consumer of these responses
      client_response_put     => response,
      EN_client_response_put  => EN_client_response_put,
      RDY_client_response_put => RDY_client_response_put
      
   );
end architecture rtl;