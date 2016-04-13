--  ***************************************************************************
-- File Name: DSP_TX_FSM.vhd

-- File Description:
-- This module works on the received packet and sends a new packet to DSP.
-- The state machine(main if-else logic) has few states such as Initialization, receiver ready, 
-- packet test, error packet action1, error packet action2, packet unload and packet trasnmission.

-- INITIALIZATION: reset all signals to default

-- RECEIVER READY : wait untill rx K-car goes low and timer expires

-- PACKET TEST: test the packet valididty by partially comparing known predefined sections in packet

-- ERROR ACTION1: check if this is the third consecutive packet with error. If it is then MMC shut down due to
-- communication error. 

-- ERROR ACTION2: packet error has occured therefore prepare packet to send to DSP informing that 
-- previous received packet had error.

-- PACKET UNLOAD: No packet error occured(it is probabilistically good assumption), therfore unload the packet data into
-- BRAM4.

-- PACKET TRANSMISSION: transmitt the packet to DSP. HMB_tx module make the packet ready to send and 
-- loads into BRAM3. This module then simply sends it. This saves time for DSP communication. 
-- 
--  ***************************************************************************

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
LIBRARY UNISIM;
USE UNISIM.VCOMPONENTS.ALL;



entity DSP_TX_FSM is
	port
	(
		--%%%%%%%%%%%%%%%%%%%%% INPUT PORTS  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		
		USER_CLK      				: in std_logic;
		START_OPERATION			: in std_logic;
		MASTER						: in std_logic;		
		RX1_CHAR_IS_K     		: in std_logic;
		USE_BRAM4 					: in std_logic;											
		USE_BRAM3 					: in std_logic;
		
		HMB							: in std_logic_vector(1 downto 0); 
		
		BRAM2_DOB 					: in std_logic_vector(7 downto 0);		
		BRAM3_DOB 					: in std_logic_vector(7 downto 0);		
		BRAM4_DOA 					: in std_logic_vector(7 downto 0);
		
		
		--%%%%%%%%%%%%%%%%%%%%% OUTPUT PORTS  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		
		PACKET_ERROR				: out std_logic;											
		COMMUNICATION_ERROR		: out std_logic;											
		REQ_BRAM3 					: out std_logic;											
		DONE_BRAM3 					: out std_logic;											
		REQ_BRAM4 					: out std_logic;											
		DONE_BRAM4 					: out std_logic;		
		RECEIVER_READY	 			: out std_logic;											
		TX1_CHAR_IS_K          	: out std_logic;
		BRAM2_ENB 					: out std_logic;									
		BRAM3_ENB 					: out std_logic;	
		BRAM4_ENA 					: out std_logic;									
		BRAM2_WEB 					: out std_logic;
		BRAM3_WEB 					: out std_logic;
		BRAM4_WEA 					: out std_logic;

		TX1_DATA             	: out std_logic_vector(7 downto 0); 
		BRAM2_DIB 					: out std_logic_vector(7 downto 0);	
		BRAM3_DIB 					: out std_logic_vector(7 downto 0);		
		BRAM4_DIA 					: out std_logic_vector(7 downto 0);		
		BRAM2_ADDRB					: out std_logic_vector(11 downto 0);	
		BRAM3_ADDRB					: out std_logic_vector(11 downto 0);	
		BRAM4_ADDRA					: out std_logic_vector(11 downto 0);	
		CHIPSCOPE_DEBUG			: out	std_logic_vector(9 downto 0)

	);

  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of DSP_TX_FSM : entity is "v4fx_mgtwizard_v1_7, Coregen v12.1";

end DSP_TX_FSM;


architecture RTL of DSP_TX_FSM is

----*********************************Signal Declarations********************************

	signal master_i				: std_logic := '0';
	signal start_operation_i	: std_logic := '0';
	signal packet_error_i		: std_logic := '0';
	signal tx1_char_is_k_i     : std_logic := '0';
	signal bram2_enb_i 			: std_logic := '0'; 							
	signal bram2_web_i 			: std_logic := '0';
	signal bram3_enb_i 			: std_logic := '0'; 							
	signal bram3_web_i 			: std_logic := '0';
	signal bram4_ena_i 			: std_logic := '0';							
	signal bram4_wea_i 			: std_logic := '0';
	signal req_bram3_i 			: std_logic := '0';							
	signal use_bram3_i 			: std_logic := '0';							
	signal done_bram3_i			: std_logic := '0';							
	signal req_bram4_i 			: std_logic := '0';							
	signal use_bram4_i 			: std_logic := '0';							
	signal done_bram4_i			: std_logic := '0';	
	signal communication_error_i: std_logic := '0';
	signal rx1_char_is_k_i    	: std_logic := '0';
	signal rx1_k_i   				: std_logic := '0';

	signal hmb_i					: std_logic_vector(1 downto 0) := "00";
	
	signal TX_STATE				: std_logic_vector(3 downto 0) := x"0";
	
	signal tx1_data_i			  	: std_logic_vector(7 downto 0) := x"00";
	signal tx1_data1_i			: std_logic_vector(7 downto 0) := x"00";
	signal test_packet_i		  	: std_logic_vector(7 downto 0) := x"00";
	signal test_reg_i		  		: std_logic_vector(7 downto 0) := x"00";
	signal bram2_dob_i 			: std_logic_vector(7 downto 0) := x"00";
	signal bram2_dib_i 			: std_logic_vector(7 downto 0) := x"00"; 
	signal bram3_dob_i 			: std_logic_vector(7 downto 0) := x"00";
	signal bram3_dib_i 			: std_logic_vector(7 downto 0) := x"00"; 
	signal bram4_doa_i 			: std_logic_vector(7 downto 0) := x"00";
	signal bram4_dia_i 			: std_logic_vector(7 downto 0) := x"00";
	
	signal bram4_addra_i			: std_logic_vector(11 downto 0) := x"000";
	signal bram2_addrb_i			: std_logic_vector(11 downto 0) := x"000";
	signal bram3_addrb_i			: std_logic_vector(11 downto 0) := x"000";
  	signal chipscope_debug_i	: std_logic_vector(9 downto 0)  := "0000000000";

	constant byte_00					: std_logic_vector(7 downto 0):= x"00";
	constant byte_FF					: std_logic_vector(7 downto 0):= x"FF";
	constant addr_000					: std_logic_vector(11 downto 0):= x"000";
	constant addr_001					: std_logic_vector(11 downto 0):= x"001";

	signal TOKEN_TIMER			: integer range 0 to 1000 := 0;                                     

	signal S2_COUNT				: integer range 0 to 100 := 0;                                                
	signal S3_COUNT				: integer range 0 to 10 := 0;                                                
	signal S4_COUNT				: integer range 0 to 10 := 0;                                                
	signal S4_LOAD_BRAM4_COUNT	: integer range 0 to 500 := 0;                                                
	signal S5_TX_COUNT			: integer range 0 to 500 := 0;                                                
		

		
	--*********************************Main Body of Code**********************************


	------------------------------------------------------
	begin
	
	--%%%%%%%%%%%  signal connections for INPUT PORTS  %%%%%%%%%%%%%%%%%%%%%%%

		start_operation_i	   <= START_OPERATION;	
		master_i				   <= MASTER;				
		use_bram4_i 			<= USE_BRAM4; 			
		use_bram3_i 			<= USE_BRAM3; 			
		hmb_i					   <= HMB;
		rx1_char_is_k_i      <= RX1_CHAR_IS_K;  
		bram2_dob_i 			<= BRAM2_DOB; 			
		bram3_dob_i 			<= BRAM3_DOB; 			
		bram4_doa_i 			<= BRAM4_DOA;
		
	--%%%%%%%%%%%  signal connections for OUTPUT PORTS  %%%%%%%%%%%%%%%%%%%%%%%
	
		REQ_BRAM3 			   <= req_bram3_i; 			
		DONE_BRAM3 			   <= done_bram3_i; 			
		REQ_BRAM4 			   <= req_bram4_i; 			
		DONE_BRAM4 			   <= done_bram4_i; 			
		TX1_CHAR_IS_K        <= tx1_char_is_k_i;     
		BRAM2_ENB 			   <= bram2_enb_i; 			
		BRAM3_ENB 			   <= bram3_enb_i; 			
		BRAM4_ENA 			   <= bram4_ena_i; 			
		BRAM2_WEB 	         <= bram2_web_i;
		BRAM3_WEB 	         <= bram3_web_i;
		BRAM4_WEA 	         <= bram4_wea_i;
		
		TX1_DATA             <= tx1_data1_i;          
		BRAM2_DIB 			   <= bram2_dib_i; 			
		BRAM3_DIB 			   <= bram3_dib_i; 			
		BRAM4_DIA 			   <= bram4_dia_i; 			
		BRAM2_ADDRB			   <= bram2_addrb_i;		 		
		BRAM3_ADDRB			   <= bram3_addrb_i;		 	
		BRAM4_ADDRA			   <= bram4_addra_i;		 	
		CHIPSCOPE_DEBUG 		<= chipscope_debug_i;
		PACKET_ERROR	 		<= packet_error_i;
		COMMUNICATION_ERROR	<= communication_error_i;
		tx1_data1_i 			<= tx1_data_i;

	process(USER_CLK)
	begin
	
		if (rising_edge(USER_CLK)) then
			
			chipscope_debug_i(0) 	<= TX_STATE(0);
			chipscope_debug_i(1) 	<= TX_STATE(1);
			chipscope_debug_i(2) 	<= TX_STATE(2);
			chipscope_debug_i(3) 	<= TX_STATE(3);

			rx1_k_i 						<= rx1_char_is_k_i;
	
--###################################################################################################################################################
--###################################################################################################################################################
--###################################################################################################################################################
--##################################################### State Machine for DSP comunication ############################################################
--###################################################################################################################################################
--###################################################################################################################################################
--###################################################################################################################################################
		
	
	
	
	
--###################################################################################################################################################
--##################################################### Initialization state #############################################################
--###################################################################################################################################################
			-- reset all to their default values
			case TX_STATE is
			
			when x"0" =>
				-- reset unused signals to default value or keep last value
				test_reg_i					<= byte_00;
				test_packet_i				<= byte_00;
				tx1_data_i					<= x"BC";
				tx1_char_is_k_i			<= '1';
				communication_error_i	<= '0';	
				bram2_enb_i 				<= '0'; 				 
				bram2_web_i					<= '0';					
				bram2_dib_i 				<= byte_00; 				
				bram2_addrb_i 				<= addr_000; 				
				bram3_enb_i 				<= '0'; 				
				bram3_web_i					<= '0';					
				bram3_dib_i 				<= byte_00; 				
				bram3_addrb_i 				<= addr_000; 				
				bram4_ena_i 				<= '0'; 				
				bram4_wea_i					<= '0';					
				bram4_dia_i 				<= byte_00; 				
				bram4_addra_i 				<= addr_000; 				
				req_bram3_i 				<= '0'; 				
				done_bram3_i 				<= '0'; 				
				req_bram4_i 				<= '0'; 				
				done_bram4_i 				<= '0'; 						
				S2_COUNT 					<=	0; 				
				S3_COUNT 					<=	0; 				
				S4_COUNT 					<=	0; 				
				S4_LOAD_BRAM4_COUNT		<= 0;	
				S5_TX_COUNT 				<= 0; 
				TOKEN_TIMER					<= 0;
				
				-- during power ON this state would wait for start operation but to go high.
				-- the initial power on time delay is defined in MMC_top_level module using 3 cascaded counters.
				if(start_operation_i = '0')then
					TX_STATE 	<= x"0";
				elsif(start_operation_i = '1' and master_i = '0')then
					TX_STATE 	<= x"0";
				else -- only go to state 1 if the board is master(meaning connected to DSP)
					TX_STATE 	<= x"1";
				end if;	
					
		------------------------------------------------------------------------------------------------------------------------------------*/
--###################################################################################################################################################
--#################################################### Receiver ready state ##################################################################
--###################################################################################################################################################
				
			when x"1" =>
				-- reset unused signals to default value or keep last value
				test_reg_i					<= byte_00;
				test_packet_i				<= byte_00;
				tx1_data_i					<= x"BC";
				tx1_char_is_k_i			<= '1';
				communication_error_i	<= '0';	
				bram2_enb_i 				<= '0'; 				 
				bram2_web_i					<= '0';					
				bram2_dib_i 				<= byte_00; 				
				bram2_addrb_i 				<= addr_000; 				
				bram3_enb_i 				<= '0'; 				
				bram3_web_i					<= '0';					
				bram3_dib_i 				<= byte_00; 				
				bram3_addrb_i 				<= addr_000; 				
				bram4_ena_i 				<= '0'; 				
				bram4_wea_i					<= '0';					
				bram4_dia_i 				<= byte_00; 				
				bram4_addra_i 				<= addr_000; 				
				req_bram3_i 				<= '0'; 				
				done_bram3_i 				<= '0'; 				
				req_bram4_i 				<= '0'; 				
				done_bram4_i 				<= '0'; 						
				S2_COUNT 					<=	0; 				
				S3_COUNT 					<=	0; 				
				S4_COUNT 					<=	0; 				
				S4_LOAD_BRAM4_COUNT		<= 0;	
				S5_TX_COUNT 				<= 0; 
				
				-- when k-char goes low start timer and wait for 300 cycles during which
				-- dsp_rx would load packet data into BRAM2
				if(rx1_k_i = '0' or(TOKEN_TIMER > 0 and TOKEN_TIMER < 300))then
					TOKEN_TIMER		<= TOKEN_TIMER+1;
					TX_STATE 		<= x"1";
				elsif(rx1_k_i = '1' and TOKEN_TIMER = 300)then -- go to next state
					TOKEN_TIMER		<= 0;
					TX_STATE 		<= x"2";
				else
					TOKEN_TIMER		<= 0;
					TX_STATE 		<= x"1";
				end if;	
				
--###################################################################################################################################################
--##################################################### Packet testing state #####################################################################
--###################################################################################################################################################
			-- test part of the packet with predefined expected data. Any mismatch in this test would
			-- mean the packet has error.	
			when x"2" =>
				-- reset unused signals to default value or keep last value
				test_reg_i					<= byte_00;
				tx1_data_i					<= x"BC";
				tx1_char_is_k_i			<= '1';
				communication_error_i	<= '0';	
				bram3_enb_i 				<= '0'; 				
				bram3_web_i					<= '0';					
				bram3_dib_i 				<= byte_00; 				
				bram3_addrb_i 				<= addr_000; 				
				bram4_ena_i 				<= '0'; 				
				bram4_wea_i					<= '0';					
				bram4_dia_i 				<= byte_00; 				
				bram4_addra_i 				<= addr_000; 				
				req_bram3_i 				<= '0'; 				
				done_bram3_i 				<= '0'; 				
				req_bram4_i 				<= '0'; 				
				done_bram4_i 				<= '0'; 						
				
				TOKEN_TIMER					<= 0;
				S3_COUNT 					<=	0; 				
				S4_COUNT 					<=	0; 				
				S4_LOAD_BRAM4_COUNT		<= 0;	
				S5_TX_COUNT 				<= 0; 
					
				bram2_enb_i 				<= '1'; 				 
				bram2_web_i					<= '0';					
				bram2_dib_i 				<= byte_00; 				
				test_packet_i				<= bram2_dob_i;
				
				
				--- this if logic tells which memory location to read packet from.
				-- predefined data sequence is distributed over the length of packet.
				if(S2_COUNT = 16)then
					S2_COUNT 		<= S2_COUNT+1;
					bram2_addrb_i 	<= x"023";
				elsif(S2_COUNT = 28)then
					S2_COUNT 		<= 0;
					bram2_addrb_i	<= addr_001;
				else
					S2_COUNT 		<= S2_COUNT+1;
					bram2_addrb_i 	<= bram2_addrb_i+ addr_001;
				end if;
				
				
				-- this if logic compares the BRAM data with predefined data
				-- if any mismatch occurs then remaining comparison is bypassed and it goes to next state 
				if(S2_COUNT <= 2)then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 3 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 4 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 5 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 6 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 7 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 8 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 9 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 10 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 11 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 12 and test_packet_i = x"55")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 13 and test_packet_i = x"68")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 14 and test_packet_i = x"12")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 15 and test_packet_i = x"04")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 16 and test_packet_i = byte_00)then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 17 and test_packet_i = byte_00)then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 18 and test_packet_i = byte_00)then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 19 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 20 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 21 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 22 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 23 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 24 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 25 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 26 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 27 and test_packet_i = x"AA")then
					TX_STATE			<= x"2";
				elsif(S2_COUNT = 28 and test_packet_i = x"AA")then
					TX_STATE			<= x"5";
				else
					TX_STATE			<= x"3";
				end if;
				
				
--###################################################################################################################################################
--##################################################### error packet action 1 state ########################################################
--###################################################################################################################################################				
			-- every time packet error occurs increment a counter value in BRAM.
			-- If this value is 3 then communication error has occured. MMC should shut down now.
			
			when x"3" =>
				-- reset unused signals to default value or keep last value
				test_packet_i			<= byte_00;
				tx1_data_i					<= x"BC";
				tx1_char_is_k_i			<= '1';
				bram3_enb_i 				<= '0'; 				
				bram3_web_i					<= '0';					
				bram3_dib_i 				<= byte_00; 				
				bram3_addrb_i 				<= addr_000; 				
				bram4_ena_i 				<= '0'; 				
				bram4_wea_i					<= '0';					
				bram4_dia_i 				<= byte_00; 				
				bram4_addra_i 				<= addr_000; 				
				req_bram3_i 				<= '0'; 				
				done_bram3_i 				<= '0'; 				
				req_bram4_i 				<= '0'; 				
				done_bram4_i 				<= '0'; 						

				TOKEN_TIMER					<= 0;
				S2_COUNT						<= 0;
				S4_COUNT 					<=	0; 				
				S4_LOAD_BRAM4_COUNT		<= 0;	
				S5_TX_COUNT 				<= 0; 
					
				bram2_enb_i 				<= '1'; 				 
				test_reg_i					<= bram2_dob_i;
				
				if(S3_COUNT <= 2)then
					bram2_web_i					<= '0';					
					communication_error_i	<= '0';	
					TX_STATE 					<= x"3";
					bram2_dib_i 				<= byte_00; 				
					bram2_addrb_i				<= x"100";
					S3_COUNT 					<= S3_COUNT+1;
					
				elsif(S3_COUNT = 3)then
					bram2_web_i					<= '1';					
					communication_error_i	<= '0';	
					TX_STATE 					<= x"3";
					bram2_dib_i 				<= test_reg_i + x"01"; -- increment value in memory to keep track of consecutive packet errors
					bram2_addrb_i				<= x"100";
					S3_COUNT 					<= S3_COUNT+1;	
					
				elsif(S3_COUNT = 4 and bram2_dob_i >= x"03")then
					bram2_web_i					<= '0';					
					communication_error_i	<= '1';	-- communication error occured due to 3 straight error packets
					TX_STATE 					<= x"4";
					bram2_dib_i 				<= byte_00; 
					bram2_addrb_i				<= addr_000;
					S3_COUNT 					<= 0;					
				else
					bram2_web_i					<= '0';					
					communication_error_i	<= '0';	
					TX_STATE 					<= x"4";
					bram2_dib_i 				<= byte_00; 
					bram2_addrb_i				<= addr_000;
					S3_COUNT 					<= 0;
				end if;
				
				
--###################################################################################################################################################
--########################################################## Error packet action 2 state  ################################################################
--##################################################################################################################################################
			-- the only action this state takes is to write '02' at '00F' memory address(or packet) location which would 
			-- let DSP know that there was an error detected in previous packet. The DSP should send the paket again
			-- upon detecting 02 at that location in packet.
			
			when x"4" =>
				-- reset unused signals to default value or keep last value
				tx1_data_i				<= x"BC";
				tx1_char_is_k_i		<= '1';
				communication_error_i<= '0';	
				bram2_enb_i 			<= '1'; 				 
				bram2_web_i				<= '0';					
				bram2_dib_i 			<= byte_00; 				
				bram2_addrb_i 			<= addr_000; 				
				bram4_ena_i 			<= '0'; 				
				bram4_wea_i				<= '0';					
				bram4_dia_i 			<= byte_00; 				
				bram4_addra_i 			<= addr_000; 				
				req_bram4_i 			<= '0'; 				
				done_bram4_i 			<= '0'; 						
				TOKEN_TIMER				<= 0;
				S2_COUNT 				<=	0; 				
				S3_COUNT 				<=	0; 				
				S4_LOAD_BRAM4_COUNT	<= 0;
				test_packet_i			<= byte_00;
				test_reg_i				<= byte_00;
				
				if(use_bram3_i = '0')then				
					-- request BRAM3 access.
					-- It will stay in this condition untill acess is granted.
					TX_STATE 			<= x"4";
					bram3_enb_i 		<= '0'; 				
					bram3_web_i			<= '0';					
					bram3_dib_i 		<= byte_00; 				
					bram3_addrb_i 		<= addr_000; 				
					req_bram3_i 		<= '1'; 	-- request access to BRAM3			
					done_bram3_i 		<= '0'; 				
					S4_COUNT 			<= 0;						
				
				else -- BRAM3 access granted
					
					if(S4_COUNT	= 0)then
						req_bram3_i 		<= '1'; 				
						done_bram3_i 		<= '0'; 		
						bram3_enb_i 		<= '1'; 				
						bram3_web_i			<= '0';					
						bram3_dib_i 		<= byte_00; 				
						bram3_addrb_i 		<= addr_000;
						S4_COUNT				<= S4_COUNT+1;
						TX_STATE 			<= x"4";
						
					elsif(S4_COUNT	= 1)then
						req_bram3_i 		<= '1'; 				
						done_bram3_i 		<= '0'; 		
						bram3_enb_i 		<= '1'; 				
						bram3_web_i			<= '1';		-- BRAM3 write enable				
						bram3_dib_i 		<= x"02"; 	-- write 02 indicating prev packet error to DSP			
						bram3_addrb_i 		<= x"00F";
						S4_COUNT				<= S4_COUNT+1;
						TX_STATE 			<= x"4";
						
					else
						req_bram3_i 		<= '0'; 				
						done_bram3_i 		<= '1'; -- done using BRAM3
						bram3_enb_i 		<= '0'; 				
						bram3_web_i			<= '0';					
						bram3_dib_i 		<= byte_00; 				
						bram3_addrb_i 		<= addr_000;
						S4_COUNT				<= 0;
						TX_STATE 			<= x"6";					
					end if;
				end if;
				
--###################################################################################################################################################
--##################################################### Packet Unload (Copy packet to BRAM4) ########################################################
--###################################################################################################################################################
			
			-- in this state the some packet data from BRAM2 is loaded into BRAM4(which is shared by HMB_tx module) 
			-- HMB doesn't need entire packet came from DSP. It only needs te Vrefs and Commands.
			-- Those necessary bytes are copied from BRAM2 to BRAM4.
			
			when x"5" =>
				-- reset unused signals to default value or keep last value
				test_reg_i					<= byte_00;
				test_packet_i				<= byte_00;
				tx1_data_i					<= x"BC";
				tx1_char_is_k_i			<= '1';
				communication_error_i	<= '0';	
				bram3_enb_i 				<= '0'; 				
				bram3_web_i					<= '0';					
				bram3_dib_i 				<= byte_00; 				
				bram3_addrb_i 				<= addr_000; 				
				req_bram3_i 				<= '0'; 				
				done_bram3_i 				<= '0'; 				
				TOKEN_TIMER					<= 0;
				S2_COUNT 					<=	0; 				
				S3_COUNT 					<=	0; 				
				S4_COUNT 					<=	0; 				
				S5_TX_COUNT 				<= 1; 
				
				if(use_bram4_i = '0')then
					-- request BRAM4 access.
					-- It will stay in this if condition untill acess is granted.
					TX_STATE 				<= x"5";
					bram2_enb_i 			<= '1'; 				 
					bram2_web_i				<= '0';					
					bram2_dib_i 			<= byte_00; 				
					bram2_addrb_i 			<= addr_000;
					bram4_ena_i 			<= '0'; 				
					bram4_wea_i				<= '0';					
					bram4_dia_i 			<= byte_00; 				
					bram4_addra_i 			<= addr_000;
					req_bram4_i 			<= '1'; 		
					done_bram4_i 			<= '0'; 						
					S4_LOAD_BRAM4_COUNT	<= 1;
						
				else						
					bram2_enb_i 			<= '1'; 				 
					
					-- use counter to 
					if(S4_LOAD_BRAM4_COUNT = 23)then
						TX_STATE 				<= x"6";
						req_bram4_i 			<= '1'; 				
						done_bram4_i 			<= '0'; 								
						S4_LOAD_BRAM4_COUNT	<= 1;
					else
						TX_STATE 				<= x"5";
						req_bram4_i 			<= '0'; 				
						done_bram4_i 			<= '1'; 
						S4_LOAD_BRAM4_COUNT	<= S4_LOAD_BRAM4_COUNT+1;
					end if;
					
					-- at each count increment BRAM address and 
					if(S4_LOAD_BRAM4_COUNT = 1)then
						bram2_addrb_i 			<= addr_000;
						bram2_web_i				<= '0';					
						bram2_dib_i 			<= byte_00;
						bram4_ena_i 			<= '1'; 				
						bram4_wea_i				<= '0';					
						bram4_dia_i 			<= byte_00; 				
						bram4_addra_i 			<= addr_000;
						
					elsif(S4_LOAD_BRAM4_COUNT = 2)then
						bram2_addrb_i 			<= x"011";	
						bram2_web_i				<= '0';					
						bram2_dib_i 			<= byte_00;
						bram4_ena_i 			<= '1'; 				
						bram4_wea_i				<= '1';	--write enable				
						bram4_dia_i 			<= x"FF";-- "FF" means new data from DSP is available(to let hmb_tx module know) 	
						bram4_addra_i 			<= addr_000;
	
					elsif(S4_LOAD_BRAM4_COUNT = 3)then
						bram2_addrb_i 			<= bram2_addrb_i + addr_001;	
						bram2_web_i				<= '0';					
						bram2_dib_i 			<= byte_00;
						bram4_ena_i 			<= '1'; 				
						bram4_wea_i				<= '1';					
						bram4_dia_i				<= x"FF";	
						bram4_addra_i 			<= addr_000;
 	
					elsif(S4_LOAD_BRAM4_COUNT = 4)then
						bram2_addrb_i 			<= bram2_addrb_i + addr_001;	
						bram2_web_i				<= '0';					
						bram2_dib_i 			<= byte_00;
						bram4_ena_i 			<= '1'; 				
						bram4_wea_i				<= '1';					
						bram4_dia_i				<= bram2_dob_i;	
						bram4_addra_i 			<= addr_001;
					
					-- transfer all required data from BRAM2 to BRAM4	
					elsif(S4_LOAD_BRAM4_COUNT >= 5 and S4_LOAD_BRAM4_COUNT <= 21)then
						bram2_addrb_i 			<= bram2_addrb_i+ addr_001;	
						bram2_web_i				<= '0';					
						bram2_dib_i 			<= byte_00;
						bram4_ena_i 			<= '1'; 				
						bram4_wea_i				<= '1';					
						bram4_dia_i				<= bram2_dob_i;	
						bram4_addra_i 			<= bram4_addra_i+ addr_001;
						
					elsif(S4_LOAD_BRAM4_COUNT = 22)then							
						bram2_addrb_i 			<= x"100";	
						bram2_web_i				<= '1';					
						bram2_dib_i 			<= byte_00; 
						bram4_ena_i 			<= '0';
						bram4_wea_i				<= '0';
						bram4_dia_i				<= byte_00;	
						bram4_addra_i 			<= addr_000;

					else
						bram2_addrb_i 			<= addr_000;	
						bram2_web_i				<= '0';					
						bram4_ena_i 			<= '0';
						bram4_wea_i				<= '0';
						bram4_dia_i				<= byte_00;	
						bram4_addra_i 			<= addr_000;
						
					end if;
				end if;
				
				
--###################################################################################################################################################
--########################################################## Packet Transmission state  ################################################################
--###################################################################################################################################################
			
			-- this state transmitts data from BRAM3 to RocketIO MGT3.
			-- after transmitting packet the state changes to receiver ready state.
			when others =>
				-- reset unused signals to default value or keep last value
				communication_error_i<= '0';	
				bram2_enb_i 			<= '0'; 				 
				bram2_web_i				<= '0';					
				bram2_dib_i 			<= byte_00; 				
				bram2_addrb_i 			<= addr_000; 				
				bram4_ena_i 			<= '0'; 				
				bram4_wea_i				<= '0';					
				bram4_dia_i 			<= byte_00; 				
				bram4_addra_i 			<= addr_000; 				
				req_bram4_i 			<= '0'; 				
				done_bram4_i 			<= '0'; 						
				TOKEN_TIMER				<= 0;
				S2_COUNT 				<=	0; 				
				S3_COUNT 				<=	0; 				
				S4_COUNT 				<=	0; 				
				S4_LOAD_BRAM4_COUNT	<= 0;
				test_packet_i			<= byte_00;
				
				if(use_bram3_i = '0')then				
					-- request BRAM3 access.
					-- It will stay in this condition untill acess is granted.
					TX_STATE 			<= x"6";
					tx1_data_i			<= x"BC";
					tx1_char_is_k_i	<= '1';	
					bram3_enb_i 		<= '0'; 				
					bram3_web_i			<= '0';					
					bram3_dib_i 		<= byte_00; 				
					bram3_addrb_i 		<= addr_000; 				
					req_bram3_i 		<= '1'; 				
					done_bram3_i 		<= '0'; 				
					S5_TX_COUNT 		<= 0;						
				
				else
					
					if(S5_TX_COUNT	<= 1)then
						req_bram3_i 		<= '1'; 				
						done_bram3_i 		<= '0'; 		
						bram3_enb_i 		<= '1'; 				
						bram3_web_i			<= '0';					
						bram3_dib_i 		<= byte_00; 				
						bram3_addrb_i 		<= addr_000;
						tx1_data_i			<= x"BC";
						tx1_char_is_k_i	<= '1'; -- comma character is being sent
						S5_TX_COUNT			<= S5_TX_COUNT+1;
						TX_STATE 			<= x"6";
						
					elsif(S5_TX_COUNT >= 2 and S5_TX_COUNT	<= 5)then 
						req_bram3_i 		<= '1'; 				
						done_bram3_i 		<= '0'; 
						bram3_enb_i 		<= '1'; 				
						bram3_web_i			<= '0';					
						bram3_dib_i 		<= byte_00; 				
						bram3_addrb_i 		<= addr_001;
						tx1_data_i			<= x"3C";-- send "3C" as comma character. 
															-- it was used to avoid some weird MGT receiver behaviour at the begining of packet receiption.  
						tx1_char_is_k_i	<= '1'; -- comma character is being sent
						S5_TX_COUNT			<= S5_TX_COUNT+1;
						TX_STATE 			<= x"6";
					elsif(S5_TX_COUNT	= 6)then
						req_bram3_i 		<= '1'; 				
						done_bram3_i 		<= '0'; 
						bram3_enb_i 		<= '1'; 				
						bram3_web_i			<= '0';					
						bram3_dib_i 		<= byte_00; 				
						bram3_addrb_i 		<= bram3_addrb_i+ addr_001;
						tx1_data_i			<= x"3C";
						tx1_char_is_k_i	<= '1'; -- comma character is being sent
						S5_TX_COUNT			<= S5_TX_COUNT+1;
						TX_STATE 			<= x"6";
						
					-- send the packet byte one by one to RocektIO	
					elsif(S5_TX_COUNT	>= 7 and S5_TX_COUNT <= 174)then
						req_bram3_i 		<= '1'; 				
						done_bram3_i 		<= '0'; 
						bram3_enb_i 		<= '1'; 				
						bram3_web_i			<= '0';					
						bram3_dib_i 		<= byte_00; 				
						bram3_addrb_i 		<= bram3_addrb_i+ addr_001;
						tx1_data_i			<= bram3_dob_i;
						tx1_char_is_k_i	<= '0'; -- packet data is being sent
						S5_TX_COUNT			<= S5_TX_COUNT+1;
						TX_STATE 			<= x"6";
					elsif(S5_TX_COUNT	>= 175 and S5_TX_COUNT <= 179)then	
						req_bram3_i 		<= '1'; 				
						done_bram3_i 		<= '0'; 
						bram3_enb_i 		<= '0'; 				
						bram3_web_i			<= '0';					
						bram3_dib_i 		<= byte_00; 				
						bram3_addrb_i 		<= addr_000;
						tx1_data_i			<= x"3C";
						tx1_char_is_k_i	<= '1'; -- comma character is being sent
						S5_TX_COUNT			<= S5_TX_COUNT+1;
						TX_STATE 			<= x"6";
					else
						req_bram3_i 		<= '0'; 				
						done_bram3_i 		<= '1'; -- done using BRAM3							
						bram3_enb_i 		<= '0'; 				
						bram3_web_i			<= '0';					
						bram3_dib_i 		<= byte_00; 				
						bram3_addrb_i 		<= addr_000;
						tx1_data_i			<= x"BC";
						tx1_char_is_k_i	<= '1'; -- comma character is being sent
						TX_STATE 			<= x"1";
						S5_TX_COUNT			<= 0;
					end if;
				end if;
			end case;
		end if;
	end process;

	
	 
	 
end RTL;

