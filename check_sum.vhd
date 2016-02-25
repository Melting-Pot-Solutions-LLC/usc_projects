-- simplest check sum

-- receiver
	signal have_seen_start_packet: std_logic := '0';
	signal current_check_sum		: std_logic_vector(7 downto 0);
	signal check_sum_error			: std_logic := '0';
	signal rx_data_counter       : std_logic_vector(7 downto 0) := x"00";

	attribute keep : string;
	attribute keep of check_sum_error : signal is "true";
	attribute keep of rx_data_counter : signal is "true";

    -- State registers
    process (USER_CLK)
    begin
	 --delayed_rx_data_r <= rx_data_r;
	 
        if (USER_CLK 'event and USER_CLK = '1') then
            if (RESET = '1') then
                begin_r          <= '1' after DLY;
                start_toggling_r <= '0' after DLY;
					 have_seen_start_packet <= '0';
					 --check_sum_error <= '0';
            else
                begin_r          <= next_begin_c     after DLY;
                start_toggling_r <= start_toggling_c after DLY;
            end if;
			
			
				if (RX_CHAR_IS_K_IN = '0') then -- if it is not BC
				--if (RX_CHAR_IS_K = '0') then-- if it is not BC
				
				
					if (have_seen_start_packet = '0') then -- if we have not detected the start of the packet yet
					
						if(RX_DATA = x"0A") then -- if the data is "0A" - it is start of the packet
							rx_data_counter <= x"01";
							--MGT_FRAME_CHECK_PACKET_RECEIVED <= '0';
							have_seen_start_packet <= '1';
							current_check_sum <= x"0A";
							check_sum_error <= '0';
						end if;
						
					else -- if we have seen the start of the packet - we are currently receiving the packet
						if (rx_data_counter >= x"01") and (rx_data_counter < x"07") then
							rx_data_counter <= rx_data_counter + x"01";
							have_seen_start_packet <= '1';
							current_check_sum <= current_check_sum xor RX_DATA;
						elsif (rx_data_counter = x"07") then -- when the counter reaches B3 - end of packet, calculate the checksum
							rx_data_counter <= rx_data_counter + x"01";
							
							if(check_sum_error = '0') and (RX_DATA /= current_check_sum) then
								check_sum_error <= '1';
							end if;
							
							have_seen_start_packet <= '1';
							--MGT_FRAME_CHECK_PACKET_RECEIVED <= '1';
							
						elsif (rx_data_counter >= x"07") and (rx_data_counter < x"BA") then -- keep the current value for some time
							rx_data_counter <= rx_data_counter + x"01";
							have_seen_start_packet <= '1';
							--MGT_FRAME_CHECK_PACKET_RECEIVED <= '1';
						else
							rx_data_counter <= x"00";
							--MGT_FRAME_CHECK_PACKET_RECEIVED <= '0';
							have_seen_start_packet <= '0';
						end if;
					end if;
					
					
				end if;
		end if;

    end process;
	
-- transmitter

    signal tx_d_r                : std_logic_vector(7 downto 0);	 
	signal counter					: integer := 0;	
	signal current_check_sum		: std_logic_vector(7 downto 0);
	signal STATE_i	            : std_logic_vector(3 downto 0);
	
    --____________________________ Data Generation  __________________________________    

    --Transmit data when send_align_r is de-asserted. Data is right shifted every cycle. 
    process(USER_CLK)
    begin
        if(USER_CLK'event and USER_CLK = '1') then
            if(RESET = '1') then
                tx_d_r          <=  x"BC" after DLY;
					 counter			  <= 0;
					 STATE_i				<= x"0"; 
            elsif (send_align_r = '0') then
					
					if (send_align_r='0') then -- if the data is not special character "BC"
						case STATE_i is
							when x"0" => --wait for about 2 seconds
								if(counter < 500000000) then -- wait for 4 seconds
									counter <= counter + 1; 
									tx_d_r  <=  shift_reg_r & shift_reg_r;
									STATE_i <= x"0";
								else -- 4 seconds past
									counter <= 0;
									STATE_i <= x"3";
									tx_d_r  <=  shift_reg_r & shift_reg_r;
								end if;
								
							when x"3" =>
								case counter is
								when 0 to 9 => tx_d_r <= shift_reg_r & shift_reg_r; counter <= counter + 1; current_check_sum <= x"00";
								when 10 => tx_d_r <= x"0A"; counter <= counter + 1; current_check_sum <= x"00";
								--when 11 to 191 => tx_d_r <= tx_d_r + x"01"; counter <= counter + 1; tx_charisk_i <= '0'; current_check_sum <= current_check_sum xor tx_d_r;
								when 11 to 16 => tx_d_r <= x"5D"; counter <= counter + 1; current_check_sum <= current_check_sum xor tx_d_r;
								when 17 => current_check_sum <= current_check_sum xor tx_d_r; tx_d_r <= current_check_sum xor tx_d_r; counter <= counter + 1;
								--when 192 => current_check_sum <= current_check_sum xor tx_d_r; tx_d_r <= x"00"; counter <= counter + 1;  tx_charisk_i <= '0'; -- screwed up checsum
									
								when 18 to 27 => tx_d_r <= shift_reg_r & shift_reg_r; counter <= counter + 1;
								when others => tx_d_r  <=  shift_reg_r & shift_reg_r; STATE_i <= x"3"; counter <= 0;
								end case;	
									
							when others =>  tx_d_r  <=  shift_reg_r & shift_reg_r; counter <= 0;
						end case;	
						
					end if;
            end if;
        end if;

    end process;
