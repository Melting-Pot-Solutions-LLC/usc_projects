--  ***************************************************************************
-- File Name: DSP_RX_FSM.vhd

-- File Description: 
-- This module receives the packet from DSP connected to RocketIO module. 
-- The reason why dsp_tx and dsp_rx are different processess is because ideally 
-- rocketio incoming data would be coming at slightly different phase/freq clock than onboard clock.
-- Therefore the received data must be read using rx recovered clock. 
-- The clock to this module should be eventually be the MGT rx recovered clock.
-- As long as the RX K-Char is high nothing happens. The moment k-Char goes low it indicates
-- that the packet is being received. Ideally the K-char should be low for the entire lenght of
-- received packet. But in this case the DSP is unable send packet in such format instead the K-char
-- goes high and low many time during the length of packet. 
-- The incoming packet bytes are immediately stored in BRAM2 one by one every clk cycle 
-- Since the lenght of packet is known a timer is used to decide when to stop writing in BRAM2.
-- After that timer the k-char should be always high untill the next packet arrives. Also this avoids
-- interprocess handshake sigals which are suspected to be one of the possible reasons for data corruption.

--  ***************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
LIBRARY UNISIM;
USE UNISIM.VCOMPONENTS.ALL;



entity DSP_RX_FSM is
	port
	(
		--%%%%%%%%%%%%%%%%%%%%% INPUT PORTS  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

		USER_CLK      		: in std_logic;
		MASTER				: in std_logic;
		START_OPERATION	: in std_logic;
		RECEIVER_READY 	: in std_logic;
		RX1_CHAR_IS_K     : in std_logic;
		
		HMB					: in std_logic_vector(1 downto 0); 
		RX1_DATA         	: in std_logic_vector(7 downto 0); 
		BRAM2_DOA 			: in std_logic_vector(7 downto 0);	
		
		--%%%%%%%%%%%%%%%%%%%%% OUTPUT PORTS  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		PACKET_RECEIVED	: out std_logic;			
		BRAM2_ENA 			: out std_logic;									
		
		BRAM2_WEA 			: out std_logic;		
		BRAM2_DIA 			: out std_logic_vector(7 downto 0);		
		BRAM2_ADDRA			: out std_logic_vector(11 downto 0);	
		CHIPSCOPE_DEBUG	: out	std_logic_vector(9 downto 0)


	);

  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of DSP_RX_FSM : entity is "v4fx_mgtwizard_v1_7, Coregen v12.1";

end DSP_RX_FSM;


architecture RTL of DSP_RX_FSM is


----*********************************Signal Declarations********************************
	signal master_i						: std_logic := '0';
	signal start_operation_i			: std_logic := '0';
	signal packet_error_i				: std_logic := '0';
	signal rx1_char_is_k_i    			: std_logic := '0';
	signal rx1_k_i   						: std_logic := '0';
	signal packet_received_i			: std_logic := '0';
	signal receiver_ready_i				: std_logic := '0';
	signal bram2_ena_i 					: std_logic := '0';							
	signal bram2_wea_i 					: std_logic := '0';
	signal command_available_i			: std_logic := '0';
	signal command_checked_i			: std_logic := '0';
	
	signal hmb_i							: std_logic_vector(1 downto 0) := "00";
	
	signal RX_STATE					  	: std_logic_vector(3 downto 0) := x"0";
	signal temp_rx		  					: std_logic_vector(7 downto 0) := x"00";
	signal rx1_data_i			  			: std_logic_vector(7 downto 0) := x"00";
	signal bram2_doa_i 					: std_logic_vector(7 downto 0) := x"00";
	signal bram2_dia_i 					: std_logic_vector(7 downto 0) := x"00";
	
	signal bram2_addra_i					: std_logic_vector(11 downto 0) := x"000";
  	signal chipscope_debug_i			: std_logic_vector(9 downto 0) := "0000000000";

	signal TOKEN_TIMER					: integer range 0 to 1023 := 0;                                     


	--*********************************Main Body of Code**********************************


	------------------------------------------------------
	begin
	
	--%%%%%%%%%%%  signal connections for INPUT PORTS  %%%%%%%%%%%%%%%%%%%%%%%
	
		master_i					<=	MASTER;			
		start_operation_i    <= START_OPERATION;
		rx1_char_is_k_i      <= RX1_CHAR_IS_K;  
		hmb_i				      <= HMB;				
		rx1_data_i           <= RX1_DATA;       
		bram2_doa_i 		   <= BRAM2_DOA; 		

	--%%%%%%%%%%%  signal connections for OUTPUT PORTS  %%%%%%%%%%%%%%%%%%%%%%%

		BRAM2_ENA 		      <= bram2_ena_i; 		
		BRAM2_WEA 	         <= bram2_wea_i; 	 
		BRAM2_DIA 		      <= bram2_dia_i; 		
		BRAM2_ADDRA	         <= bram2_addra_i;		 
		CHIPSCOPE_DEBUG 		<= chipscope_debug_i;

	 
	
	process(USER_CLK)
	begin
		if (rising_edge(USER_CLK)) then
			
			chipscope_debug_i(0) 	<= RX_STATE(0);

			temp_rx 						<= rx1_data_i;
			rx1_k_i 						<= rx1_char_is_k_i;
			
			case RX_STATE is
			
			when x"0" => -- state 0
				
				bram2_ena_i 	<= '0'; 	
				bram2_wea_i		<= '0';		
				bram2_dia_i 	<= x"00"; 	
				bram2_addra_i 	<= x"000"; 
				TOKEN_TIMER		<= 0;
				
				-- during power ON this state would wait for start operation but to go high.
				-- the initial power on time delay is defined in MMC_top_level module using 3 cascaded counters.
				if(start_operation_i = '0')then
					RX_STATE 	<= x"0";
				elsif(start_operation_i = '1' and master_i = '0')then
					RX_STATE 	<= x"0";
				else -- only go to state 1 if the board is master(meaning connected to DSP)
					RX_STATE 	<= x"1";
				end if;	
					
			when others => -- state 1
				
				RX_STATE	<= x"1";
				
				--/*----------------------------------------------------------------
				-- when k-char goes low start timer and enable BRAM2 write and increament address every clk.
				if(rx1_k_i = '0' and  TOKEN_TIMER < 300)then
					TOKEN_TIMER		<= TOKEN_TIMER+1;
					bram2_ena_i 	<= '1';
					bram2_wea_i 	<= '1';
					bram2_dia_i 	<= temp_rx;
					bram2_addra_i 	<= bram2_addra_i + x"001";
				
				-- when k_char goes high before timer expires meaning that byte is framing character inserted
				-- by DSP and not actual data.therefore disable BRAM2 write for that particular clk cycle.		
				elsif(rx1_k_i = '1' and (TOKEN_TIMER > 0 and TOKEN_TIMER < 300))then
					TOKEN_TIMER		<= TOKEN_TIMER+1;
					bram2_ena_i 	<= '1';
					bram2_wea_i 	<= '0';
					bram2_dia_i 	<= x"00";
					bram2_addra_i 	<= bram2_addra_i;
				
				-- The received packet lenght is about 300byte or clk cycles
				-- after 300 cycles wait(no operation) until clk cycle 800.
				-- because during that time dsp_tx module would be using BRAM2 and therefore to prevent
				-- any overwriting on BRAM2(because of false triggering on receiving section) it would be better
				-- to wait untill BRAM2 is avaiablable again. 
				--  BRAM2 is available when dsp_tx finishes transmitting packet to DSP 
				elsif(TOKEN_TIMER >= 300 and TOKEN_TIMER < 800)then
					TOKEN_TIMER		<= TOKEN_TIMER+1;
					bram2_ena_i 	<= '0';
					bram2_wea_i 	<= '0';
					bram2_dia_i 	<= x"00";
					bram2_addra_i 	<= x"000";
					
				else -- reset to default in any other condition.
					TOKEN_TIMER		<= 0;
					bram2_ena_i 	<= '0';
					bram2_wea_i 	<= '0';
					bram2_dia_i 	<= x"00";
					bram2_addra_i 	<= x"000";
				end if;	
					
			end case;
		end if;
	end process;
--		
	 
end RTL;

