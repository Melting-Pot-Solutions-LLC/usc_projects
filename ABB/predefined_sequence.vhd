-- predefined sequence

-- receiver
entity FRAME_CHECK is
port
(
    -- User Interface
    RX_DATA         : in  std_logic_vector(7 downto 0); 
	 RX_CHAR_IS_K_IN : in std_logic;

    -- System Interface
    USER_CLK        : in  std_logic;   
    RESET           : in  std_logic;
    ERROR_COUNT     : out std_logic_vector(7 downto 0)
  
);

--...
	 signal error				      : std_logic := '0';
	 signal STATE_i	            : std_logic_vector(3 downto 0);

	attribute keep: string;
	attribute keep of error : signal is "true";
	attribute keep of rx_data_r : signal is "true";

--...
    --We count the total number of errors we detect. By keeping a count we make it less likely that we will miss
    --errors we did not directly observe. This counter must be reset when it reaches its max value
    process(USER_CLK)
    begin
        if(USER_CLK'event and USER_CLK = '1') then
            if(start_toggling_r = '0') then
                error_count_r   <=  (others=>'0') after DLY;
            elsif(error_detected_r='1') then
                error_count_r   <=  error_count_r + 1 after DLY;
            end if;
        end if;
		  
		  if (USER_CLK 'event and USER_CLK = '1') then
				if (RX_CHAR_IS_K_IN = '0') then -- if it is not BC
					if ((RX_DATA /= x"AA") and (RX_DATA /= x"55") and (RX_DATA /= x"0F") and (RX_DATA /= x"F0") and (RX_DATA /= x"CC") and  (RX_DATA /= x"33") and (RX_DATA /= x"BC") and (RX_DATA /= x"F7")) then
						error <= '1';
					else
						error <= '0';
					end if;
				end if;
		  end if;
		  
    end process;  
	
-- transmitter


	signal STATE_i	            : std_logic_vector(3 downto 0);
	signal counter					: std_logic_vector(31 downto 0);
	
	
	
    --______________________________ Transmit Data  __________________________________    

    --Assign TX_DATA to data register or align char based on the value

    TX_DATA     <= tx_d_r when (send_align_r='0') else
                   align_char_c;

    TX_CHARISK  <= tied_to_ground_i when (send_align_r='0') else
                   control_bits_c;

    --Transmit data when send_align_r is de-asserted. Data is right shifted every cycle. 
    process(USER_CLK)
    begin
        if(USER_CLK'event and USER_CLK = '1') then
            if(RESET = '1') then
                tx_d_r          <=  x"BC" after DLY;
                counter                <=  x"00000000";
                STATE_i            <= x"0";
            elsif (send_align_r = '0') then
                    if (STATE_i    = x"0") then 
                        STATE_i <= x"1";
                        tx_d_r <= x"F0";
                    else
                        case counter is
                            when x"00000000" => tx_d_r <= x"AA"; counter <= counter + x"00000001";
                            when x"00000001" => tx_d_r <= x"55"; counter <= counter + x"00000001";
                            when x"00000002" => tx_d_r <= x"0F"; counter <= counter + x"00000001";
                            when x"00000003" => tx_d_r <= x"CC"; counter <= counter + x"00000001";
                            when x"00000004" => tx_d_r <= x"F7"; counter <= counter + x"00000001";
									 when x"00000005" => tx_d_r <= x"F7"; counter <= counter + x"00000001";
									 when x"00000006" => tx_d_r <= x"33"; counter <= counter + x"00000001";
                            when x"00000007" => tx_d_r <= x"AA"; counter <= counter + x"00000001";
                            when x"00000008" => tx_d_r <= x"55"; counter <= counter + x"00000001";
                            when x"00000009" => tx_d_r <= x"0F"; counter <= counter + x"00000001";
                            when x"0000000A" => tx_d_r <= x"CC"; counter <= counter + x"00000001";
                            when x"0000000B" => tx_d_r <= x"F7"; counter <= counter + x"00000001";
									 when x"0000000C" => tx_d_r <= x"F7"; counter <= counter + x"00000001";
									 when x"0000000D" => tx_d_r <= x"33"; counter <= counter + x"00000001";
                            when others => tx_d_r <= x"F0"; counter    <=  x"00000000"; STATE_i <= x"0";    
                        end case;
                    end if;

            end if;
        end if;
    end process;
