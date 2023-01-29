LIBRARY ieee;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;

-------------------------------------------------------------------------------
-- UART
-- Implements a universal asynchronous receiver transmitter
-------------------------------------------------------------------------------
-- CLOCK
--      Input CLOCK, must match frequency value given on clock_frequency
--      generic input.
-- CE
--      Clock Enable
-- RX_SIGNAL
--      RX incoming stream of data
-- TX_DV
--      TX Data Validity port. Note: Read it but transferring data
-- TX_DATA
--      Data input port for byte that need to be transferred.
-- FE
--      FRAME ERROR
-- RX_DV
--      RX Data Validity port.
-- RX_DATA
--      Data output port for received bytes.
-- TX_SIGNAL
--      TX outgoing stream of data
-------------------------------------------------------------------------------

ENTITY UART_3Wires IS
	GENERIC (
		CLOCK_PER_BIT : INTEGER := 434; 			-- Number of clocks per bit
		SAMPLING_LOCATION_X : INTEGER := 217	-- Center location
	);
	PORT (
		CLOCK :        IN std_logic;                          -- clock
		CE :           IN std_logic;                          -- Clock Enable
		RX_SIGNAL:     IN std_logic;                          -- RX signal
		TX_DV:         IN std_logic;                          -- TX DATA Valid
		TX_DATA:       IN std_logic_vector(7 downto 0);       -- TX DATA 
		FE:            OUT std_logic;                         -- FRAME ERROR
		RX_DV:         OUT std_logic;                         -- RX DATA Valid
		RX_DATA:       OUT std_logic_vector(7 downto 0);      -- RX DATA 
		TX_SIGNAL:     OUT std_logic                          -- TX signal 
	);            		
END UART_3Wires;

ARCHITECTURE RTL_Design of UART_3Wires is
type RX_UART_STATES is (RX_STATE_IDLE, RX_STATE_START, RX_STATE_DATA, RX_STATE_STOP);
signal rx_main_fsm_state : RX_UART_STATES  := RX_STATE_IDLE; 
signal rx_bit_rising_edges_count: INTEGER := 0;
signal rx_bit_index: INTEGER := 0;
signal internal_data_valid: std_logic := '0';
signal RX_STATE: std_logic_vector(1 downto 0) :="00"; 	-- FSM RX_STATE

type TX_UART_STATES is (TX_STATE_IDLE, TX_STATE_START, TX_STATE_DATA, TX_STATE_STOP);
signal tx_main_fsm_state : TX_UART_STATES  := TX_STATE_IDLE; 
signal tx_bit_rising_edges_count: INTEGER := 0;
signal tx_bit_index: INTEGER := 0;
signal TX_STATE: std_logic_vector(1 downto 0) :="00"; 	-- FSM TX_STATE
BEGIN
	UART_RX_PROCESS : process(CLOCK)
	begin
		if(rising_edge(CLOCK)) then
			case (rx_main_fsm_state) is
			WHEN RX_STATE_IDLE =>
				-- Check of Start bit generated
				if(RX_SIGNAL='0') then
					-- Increase the count value of sampling point.
					rx_bit_rising_edges_count <= rx_bit_rising_edges_count+1;
				
					-- Check valid sampling point
					if(rx_bit_rising_edges_count=SAMPLING_LOCATION_X) then
						rx_main_fsm_state <= RX_STATE_START; -- Confirmed Start bit
						RX_STATE <= "01";
						RX_DV <= '0'; -- Reset data validity as new frame starts
						internal_data_valid <= '0';
					else
					end if;
				else
				end if;
			WHEN RX_STATE_START =>
				-- Increase the count value of sampling point.
				rx_bit_rising_edges_count <= rx_bit_rising_edges_count+1;
				-- Here add code for errornous Start bit based on if(RX_SIGNAL='1') 
				-- Check valid sampling point
				if(rx_bit_rising_edges_count = CLOCK_PER_BIT) then
					rx_main_fsm_state <= RX_STATE_DATA;
					RX_STATE <= "10";
					-- Set sampling point to zero.
					rx_bit_rising_edges_count <= 0;
				else
				end if;
			WHEN RX_STATE_DATA =>
				-- Increase the count value of sampling point.
				rx_bit_rising_edges_count <= rx_bit_rising_edges_count+1;

				-- Get value at valid sampling point
				if(rx_bit_rising_edges_count=SAMPLING_LOCATION_X) then
					RX_DATA(rx_bit_index) <= RX_SIGNAL;
				elsif(rx_bit_rising_edges_count=CLOCK_PER_BIT) then
					-- Set sampling point to zero.
					rx_bit_rising_edges_count <= 0;
					-- Now parity or stop bit can come only!
					if(rx_bit_index=7) then
						rx_main_fsm_state <= RX_STATE_STOP;
						RX_STATE <= "11";
					else
						rx_bit_index <= rx_bit_index+1;
					end if;
				end if;
			WHEN RX_STATE_STOP =>
				-- Increase the count value of sampling point.
				rx_bit_rising_edges_count <= rx_bit_rising_edges_count+1;
				-- Check  Stop bit
				-- Get value at valid sampling point
				if(rx_bit_rising_edges_count=SAMPLING_LOCATION_X and RX_SIGNAL='1') then
						RX_DV <= '1';
						internal_data_valid <= '1';
						rx_main_fsm_state <= RX_STATE_IDLE;
						RX_STATE <= "00";
						-- Set sampling point to zero.
						rx_bit_rising_edges_count <= 0;
						rx_bit_index <= 0;
				end if;


			end case;
		end if;
	END process UART_RX_PROCESS;
	
	-- TX implementation of UART
	UART_TX_PROCESS : process(CLOCK)
	begin
		if(rising_edge(CLOCK)) then
			case (tx_main_fsm_state) is
				WHEN TX_STATE_IDLE =>
					-- In Idle state line should be asserted
					TX_SIGNAL <= '1';
					if(TX_DV ='1') then
						-- Generate start condition
						TX_SIGNAL <= '0';
						tx_main_fsm_state <= TX_STATE_START;
						tx_bit_rising_edges_count <=  tx_bit_rising_edges_count + 1;
						TX_STATE <= "01";
					end if;
				WHEN TX_STATE_START =>
					tx_bit_rising_edges_count <=  tx_bit_rising_edges_count + 1;
					if(tx_bit_rising_edges_count = CLOCK_PER_BIT) then
						TX_STATE <= "10";
						tx_main_fsm_state <= TX_STATE_DATA;
						tx_bit_rising_edges_count <= 0;
					end if;
				WHEN TX_STATE_DATA =>
					tx_bit_rising_edges_count <=  tx_bit_rising_edges_count + 1;
					TX_SIGNAL <= TX_DATA(tx_bit_index);
					if(tx_bit_rising_edges_count = CLOCK_PER_BIT) then
						tx_bit_rising_edges_count <= 0;
						-- Full byte transferred
						if(tx_bit_index = 7) then
							TX_STATE <= "11";
							tx_main_fsm_state <= TX_STATE_STOP;
							-- send next byte
							tx_bit_index <= 0;
						elsif(tx_bit_index < 7) then
							tx_bit_index <= tx_bit_index+1;
						end if;
					end if;
				WHEN TX_STATE_STOP =>
					tx_bit_rising_edges_count <=  tx_bit_rising_edges_count + 1;
					-- Generate start condition
					TX_SIGNAL <= '1';
					if(tx_bit_rising_edges_count = CLOCK_PER_BIT) then
						tx_bit_rising_edges_count <= 0;
						TX_STATE <= "00";
						tx_main_fsm_state <= TX_STATE_IDLE;
						tx_bit_index <= 0;
					end if;
				end case;
		end if;
	END process UART_TX_PROCESS;
	FE <= '0'; -- TBD
END ARCHITECTURE RTL_Design;