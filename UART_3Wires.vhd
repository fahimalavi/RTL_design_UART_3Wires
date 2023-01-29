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
-- DV
--      Data Valid.
-- FE
--      FRAME ERROR
-- RX_DATA
--      Data output port for received bytes.
-------------------------------------------------------------------------------

ENTITY UART_3Wires IS
	GENERIC (
		CLOCK_PER_BIT : INTEGER := 434; 			-- Number of clocks per bit
		SAMPLING_LOCATION_X : INTEGER := 217	-- Center location
	);
	PORT (
   CLOCK : 		IN std_logic; 								-- clock
	RX_SIGNAL: 	IN std_logic; 								-- RX signal 
	CE : 			IN std_logic; 								-- Clock Enable
   DV:  			OUT std_logic; 							-- DATA Valid
   FE:  			OUT std_logic; 							-- FRAME ERROR
	RX_DATA: 	OUT std_logic_vector(7 downto 0) 	-- RX DATA 
);            		
END UART_3Wires;

ARCHITECTURE RTL_Design of UART_3Wires is
type uart_state is (STATE_IDLE, STATE_START, STATE_DATA, STATE_STOP);
signal main_fsm_state : uart_state  := STATE_IDLE; 
signal rising_edges_this_bit: INTEGER := 0;
signal bit_index: INTEGER := 0;
signal internal_data_valid: std_logic := '0';
signal STATE: std_logic_vector(1 downto 0) :="00"; 	-- FSM State
BEGIN
	UART_RX_PROCESS : process(CLOCK)
	begin
		if(rising_edge(CLOCK)) then
			case (main_fsm_state) is
			WHEN STATE_IDLE =>
				-- Check of Start bit generated
				if(RX_SIGNAL='0') then
					-- Increase the count value of sampling point.
					rising_edges_this_bit <= rising_edges_this_bit+1;
				
					-- Check valid sampling point
					if(rising_edges_this_bit=SAMPLING_LOCATION_X) then
						main_fsm_state <= STATE_START; -- Confirmed Start bit
						STATE <= "01";
						DV <= '0'; -- Reset data validity as new frame starts
						internal_data_valid <= '0';
					else
					end if;
				else
				end if;
			WHEN STATE_START =>
				-- Increase the count value of sampling point.
				rising_edges_this_bit <= rising_edges_this_bit+1;
				-- Here add code for errornous Start bit based on if(RX_SIGNAL='1') 
				-- Check valid sampling point
				if(rising_edges_this_bit = CLOCK_PER_BIT) then
					main_fsm_state <= STATE_DATA;
					STATE <= "10";
					-- Set sampling point to zero.
					rising_edges_this_bit <= 0;
				else
				end if;
			WHEN STATE_DATA =>
				-- Increase the count value of sampling point.
				rising_edges_this_bit <= rising_edges_this_bit+1;

				-- Get value at valid sampling point
				if(rising_edges_this_bit=SAMPLING_LOCATION_X) then
					RX_DATA(bit_index) <= RX_SIGNAL;
				elsif(rising_edges_this_bit=CLOCK_PER_BIT) then
					-- Set sampling point to zero.
					rising_edges_this_bit <= 0;
					-- Now parity or stop bit can come only!
					if(bit_index=7) then
						main_fsm_state <= STATE_STOP;
						STATE <= "11";
					else
						bit_index <= bit_index+1;
					end if;
				end if;
			WHEN STATE_STOP =>
				-- Increase the count value of sampling point.
				rising_edges_this_bit <= rising_edges_this_bit+1;
				-- Check  Stop bit
				-- Get value at valid sampling point
				if(rising_edges_this_bit=SAMPLING_LOCATION_X and RX_SIGNAL='1') then
						DV <= '1';
						internal_data_valid <= '1';
						main_fsm_state <= STATE_IDLE;
						STATE <= "00";
						-- Set sampling point to zero.
						rising_edges_this_bit <= 0;
						bit_index <= 0;
				end if;


			end case;
		end if;
	END process UART_RX_PROCESS;
	FE <= '0'; -- TBD
END ARCHITECTURE RTL_Design;