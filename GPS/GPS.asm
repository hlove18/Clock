; GPS
; HENRY LOVE
; 03/01/20
; This program tests the GPS.

; GPS OBTAIN FIX ==================
; timer 0 is configured to LPF GPS fix signal to detect when a fix is found
; timer 1 is configured to count down and timeout after 2 minutes

; GPS OBTAIN DATA =================
; timer 1 is used to set baud rate if a fix is found before 2 minutes expires

; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

; Timer 0 interrupt
.org 000Bh
TIMER_0_ISR:
	lcall TIMER_0_SERVICE 		; update the time
	reti 						; exit

; Timer 1 interrupt
.org 001Bh
TIMER_1_ISR:
	lcall TIMER_1_SERVICE 		; update the time
	reti 						; exit

; Serial Port interrupt
.org 0023h
SERIAL_ISR:
	lcall SERIAL_SERVICE 		; receive data
	clr RI 						; clear receive interrupt flag
	reti 						; exit

INIT:
; ====== GPS State Variables ======
	; State Variables:
	.equ GPS_STATE, 			7Dh
	.equ GPS_NEXT_STATE, 		7Ch

	; $GPRMC,hhmmss.sss,A,llll.llll,a,yyyyy.yyyy,a,speed,angle,ddmmyy,,,A*77
	; $GPRMC,040555.000,A,3725.4817,N,12209.5683,W,0.42,201.93,070320,,,D*78

	; State Space:
	.equ GPS_WAIT,	  	 				30h
	.equ GPS_WAIT_FOR_DOLLAR, 			31h
	.equ GPS_WAIT_FOR_G,	   			32h
	.equ GPS_WAIT_FOR_P,	   			33h
	.equ GPS_WAIT_FOR_R,	   			34h
	.equ GPS_WAIT_FOR_M,	   			35h
	.equ GPS_WAIT_FOR_C,	  		 	36h
	.equ GPS_WAIT_FOR_TIME,	 	 		37h
	.equ GPS_WAIT_FOR_A,	 	 		38h
	.equ GPS_WAIT_FOR_LATITUDE,	 	 	39h
	.equ GPS_WAIT_FOR_LONGITUDE,		40h
	.equ GPS_WAIT_FOR_DATE,				41h
	.equ GPS_WAIT_FOR_STAR,				42h
	.equ GPS_WAIT_FOR_CHECKSUM,			43h

	mov GPS_WAIT, 						#01h
	mov GPS_WAIT_FOR_DOLLAR,  			#02h
	mov GPS_WAIT_FOR_G, 	 			#03h
	mov GPS_WAIT_FOR_P,	   				#04h
	mov GPS_WAIT_FOR_R,	   				#05h
	mov GPS_WAIT_FOR_M,	   				#06h
	mov GPS_WAIT_FOR_C,	  		 		#07h
	mov GPS_WAIT_FOR_TIME,	 	 		#08h	
	mov GPS_WAIT_FOR_A,	 	 			#09h
	mov GPS_WAIT_FOR_LATITUDE,	 	 	#0Ah
	mov GPS_WAIT_FOR_LONGITUDE,			#0Bh
	mov GPS_WAIT_FOR_DATE,				#0Ch
	mov GPS_WAIT_FOR_STAR,				#0Dh
	mov GPS_WAIT_FOR_CHECKSUM,			#0Eh
; =============================

; ====== Received GPS Variables ======
	.equ CALCULATED_GPS_CHECKSUM,				57h
	.equ GPS_WAIT_TIME,							58h


	; !!!!!!! IMPORTANT: DO NOT MOVE THESE MEMORY LOCATIONS (pointers are used to update)
	; Time
	.equ RECEIVED_GPS_HRS_TENS,					59h 		; data stored here is in hex!
	.equ RECEIVED_GPS_HRS_ONES,					5Ah			; data stored here is in hex!
	.equ RECEIVED_GPS_MINS_TENS,				5Bh			; data stored here is in hex!
	.equ RECEIVED_GPS_MINS_ONES,				5Ch			; data stored here is in hex!
	.equ RECEIVED_GPS_SECS_TENS,				5Dh			; data stored here is in hex!
	.equ RECEIVED_GPS_SECS_ONES,				5Eh			; data stored here is in hex!

	; Latitude
	.equ RECEIVED_GPS_LAT_DEGS_TENS,			5Fh			; data stored here is in hex!
	.equ RECEIVED_GPS_LAT_DEGS_ONES,			60h			; data stored here is in hex!
	.equ RECEIVED_GPS_LAT_MINS_TENS,			61h			; data stored here is in hex!
	.equ RECEIVED_GPS_LAT_MINS_ONES,			62h			; data stored here is in hex!
	.equ RECEIVED_GPS_LAT_MINS_TENTHS,			63h			; data stored here is in hex!
	.equ RECEIVED_GPS_LAT_MINS_HNDRTHS,			64h			; data stored here is in hex!
	.equ RECEIVED_GPS_LAT_MINS_THSNDTHS,		65h			; data stored here is in hex!
	.equ RECEIVED_GPS_LAT_MINS_TEN_THSNDTHS,	66h			; data stored here is in hex!
	.equ RECEIVED_GPS_LAT_DIRECTION,			67h			; data stored here is in ASCII! (either "N" for North, or "S" for South)

	; Longitude
	.equ RECEIVED_GPS_LONG_DEGS_HNDRS,			68h			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_DEGS_TENS,			69h			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_DEGS_ONES,			6Ah			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_MINS_TENS,			6Bh			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_MINS_ONES,			6Ch			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_MINS_TENTHS,			6Dh			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_MINS_HNDRTHS,		6Eh			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_MINS_THSNDTHS,		6Fh			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_MINS_TEN_THSNDTHS,	70h			; data stored here is in hex!
	.equ RECEIVED_GPS_LONG_DIRECTION,			71h			; data stored here is in ASCII! (either "E" for East, or "W" for West)

	; Date
	.equ RECEIVED_GPS_DAY_TENS,					72h 		; data stored here is in hex!
	.equ RECEIVED_GPS_DAY_ONES,					73h			; data stored here is in hex!
	.equ RECEIVED_GPS_MONTH_TENS,				74h			; data stored here is in hex!
	.equ RECEIVED_GPS_MONTH_ONES,				75h			; data stored here is in hex!
	.equ RECEIVED_GPS_YEAR_TENS,				76h			; data stored here is in hex!
	.equ RECEIVED_GPS_YEAR_ONES,				77h			; data stored here is in hex!

	; Checksum 
	.equ RECEIVED_GPS_CHECKSUM,					78h			; data stored here is in hex!

; =============================

lcall GPS_OBTAIN_FIX_INIT
; setb EA 				; enable interrupts
; clr P1.6
; clr P1.7
; lcall GPS_OBTAIN_DATA_INIT

ljmp MAIN
	
MAIN:

ljmp MAIN

GPS_OBTAIN_FIX_INIT:
	; Use timer 0 for GPS "FIX" pin (in the main clock program, timer 0 is used to update time - i.e. count seconds.  This is not needed during sync)
	; User timer 1 for baud rate generation.

	; Interrupt initialization
	setb EA 				; enable interrupts
	setb ET0				; enable timer 0 overflow interrupt
	setb ET1				; enable timer 1 overflow Interrupt

	; Configure timer 0 in 16 bit mode (NOT autoreload) - For counting GPS fix LOW level duration (when GPS has a fix, GPS fix pin is constantly low)
	; Configure timer 1 in auto-reload mode (mode 2) - For baud rate generation.
	; NOTE: high nibble of TMOD is for timer 1, low nibble is for timer 0
	mov TMOD, #11h
	; Initialize TL0 and TH0 for timer 0 16 bit timing for maximum count
	mov TL0, #00h
	mov TH0, #00h
	; Initialize TL1 and TH1 for timer 1 16 bit timing for maximum count
	mov TL1, #00h
	mov TH1, #00h
	; start timer 0
	setb TR0
	; Start timer 1
	setb TR1

	; Initialize R0 to keep track of how many times timer 0 has counted to 65536 (for LPF of GPS fix)
	mov R0, #14h	; move 20 (decimal) into R0 (20 * 0.065536 seconds = ~1.31 seconds)
	; Initialize R1 to keep track of how many times timer 1 has counted to 65536 (for GPS Sync timeout)
	mov R1, #0F1h
	; Initialize R2 to keep track of how many times timer 1 has counted to 65536 used in conjuction with R1 (for GPS Sync timeout)
	mov R2, #07h
	; Pull P1.3 HIGH (input used for GPS fix)
	setb P1.3
	; Turn off GPS SYNC light
	clr P1.7
	; Turn off GPS TIMEOUT light
	clr P1.6
ret

GPS_OBTAIN_DATA_INIT:
	; Stop timer 0
	clr TR0
	; Stop timer 1
	clr TR1
	; Configure serial port to operate in mode 1 (8 bit UART with baud rate set by timer 1), with receive enabled
	mov SCON, #50h		;mode 1, receive enabled
	; Enable serial interrupt
	setb ES
	clr ET0				; clear timer 0 overflow interrupt
	clr ET1				; clear timer 1 overflow Interrupt
	; Configure timer 1 in auto-reload mode (mode 2) - For baud rate generation.
	; Configure timer 0 back to counting seconds (just so we don't have to do it when we transistion out of GPS state)
	; NOTE: high nibble of TMOD is for timer 1, low nibble is for timer 0
	mov TMOD, #26h
	; Initialize TH1 for 9600 baud
	mov TH1, #0FDh
	; Start timer 1
	setb TR1
	
	; Initialize GPS_STATE
	; !!!NOTE: THIS IS DIFFERENT THAN YOU WOULD EXPECT: MOV iram_addr1,iram_addr2 MOVES CONTENTS OF iram_addr1 INTO iram_addr2!!!
	; mov GPS_STATE, GPS_WAIT_FOR_DOLLAR			; Reset GPS_STATE
	mov GPS_STATE, #02h 							; Reset GPS_STATE
	; Initialize data pointer
	mov R0, #59h 									; load R0 (pointer) with memory address of RECEIVED_GPS_HRS_TENS
ret


TIMER_0_SERVICE:
	; Reset timer 0
	; Initialize TL0 and TH0 for timer 0 16 bit timing for maximum count
	mov TL0, #00h
	mov TH0, #00h

	jnb P1.3, timer_0_service_cont0		; check if GPS fix is HIGH/LOW
		; if GPS fix is high
		mov R0, #14h					; if GPS fix his HIGH (i.e. no GPS fix), reload R0 with 20 (decimal)
		;clr P1.7						; turn off GPS SYNC light
		ljmp timer_0_service_cont1		; jump to the end of the ISR
	timer_0_service_cont0:
		; if GPS fix is low:
		djnz R0, timer_0_service_cont1
			; GPS fix has been low for more than ~1.3 seconds
			setb P1.6
			lcall GPS_OBTAIN_DATA_INIT
			;setb P1.7 					; turn on GPS SYNC light
	timer_0_service_cont1:
ret 			 			; exit


TIMER_1_SERVICE:
	; Reset timer 1
	; Initialize TL1 and TH1 for timer 1 16 bit timing for maximum count
	mov TL1, #00h
	mov TH1, #00h

	; R1 is loaded with 255 (dec), R2 is loaded with 7 (dec).
	; This interrupt service is called every ~65536us.
	; When this service has been called 255 * 7 = 1785 times, the GPS sync will timeout
	; Total time for 1785 loops = 1785 * 0.065536 seconds = ~117 seconds = ~2 minutes
	; EXPERIMENTALLY:
	; It was found that 1785 loops = 127 seconds, so:
	; 127/1785 = 120/x --> x = 1687
	; 1687/7 = 241 --> R1 should have 241 (dec) = #0F1h
	
	djnz R1, timer_1_service_cont1			
		mov R1, #0F1h						; reload R1 with 241 counts
		djnz R2, timer_1_service_cont1
			; GPS FIX TIMEOUT!!!!!!!!!!!!!!!!!
			; setb P1.6
	timer_1_service_cont1:
ret 						; exit


SERIAL_SERVICE:
	; Uses a to store the received SBUF data
	; Uses R3 to store the GPS_STATE
	; Uses R4 as a counter (for loops)
	; Uses R0 as a data pointer
	

	; NMEA $GPRMC sentence after fix:
	; $GPRMC,hhmmss.sss,A,llll.llll,a,yyyyy.yyyy,a,v.vv,ttt.tt,ddmmyy,,,A*77
	; $GPRMC,040555.000,A,3725.4817,N,12209.5683,W,0.42,201.93,070320,,,D*78

	mov a, SBUF										; move SBUF into a
	mov R3, GPS_STATE								; move GPS_STATE into R3

	; We use the GPS_WAIT state for information not needed, like commas, speed, or magnetic variation
	; Wait uses GPS_WAIT_TIME to determine how many received bytes to wait out
	; GPS_WAIT:
	cjne R3, #01h, serial_service_cont0
		mov R4, #00h 													; R4 keeps track of how many times things loop (like how long to loop in the GPS_WAIT_FOR_TIME state)	
		xrl CALCULATED_GPS_CHECKSUM, a									; keep updating the CALCULATED_GPS_CHECKSUM
		djnz GPS_WAIT_TIME, gps_wait_cont0								; decrement until done waiting
			mov GPS_STATE, GPS_NEXT_STATE								; if wait is over, load GPS_STATE with the next state.
		gps_wait_cont0:
			ljmp serial_service_end										; jump to end
	serial_service_cont0:

	; "$"
	; GPS_WAIT_FOR_DOLLAR:
	cjne R3, #02h, serial_service_cont1
		cjne a, #24h, gps_wait_for_dollar_cont0							; check if received serial data is "$"
			; mov GPS_STATE, GPS_WAIT_FOR_G								; if received correct character, update GPS_STATE
			inc GPS_STATE 		 										; if received correct character, update GPS_STATE
		gps_wait_for_dollar_cont0:
			ljmp serial_service_end										; jump to end
	serial_service_cont1:

	; "G"
	; GPS_WAIT_FOR_G:
	cjne R3, #03h, serial_service_cont2
		cjne a, #47h, gps_wait_for_g_cont0								; check if received serial data is "G"
			mov CALCULATED_GPS_CHECKSUM, a								; initialize the CALCULATED_GPS_CHECKSUM (check sum does NOT include the "$" or "*" delimiters)
			; mov GPS_STATE, GPS_WAIT_FOR_P								; if received correct character, update GPS_STATE
			inc GPS_STATE 												; if received correct character, update GPS_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_g_cont0:
			ljmp serial_reset_GPS_STATE 								; reset GPS_STATE
	serial_service_cont2:

	; "P"
	; GPS_WAIT_FOR_P:
	cjne R3, #04h, serial_service_cont3
		cjne a, #50h, gps_wait_for_p_cont0								; check if received serial data is "P"
			xrl CALCULATED_GPS_CHECKSUM, a 								; update the CALCULATED_GPS_CHECKSUM
			; mov GPS_STATE, GPS_WAIT_FOR_R								; if received correct character, update GPS_STATE
			inc GPS_STATE 												; if received correct character, update GPS_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_p_cont0:
			ljmp serial_reset_GPS_STATE 								; reset GPS_STATE
	serial_service_cont3:

	; "R"
	; GPS_WAIT_FOR_R:
	cjne R3, #05h, serial_service_cont4
		cjne a, #52h, gps_wait_for_r_cont0								; check if received serial data is "R"
			xrl CALCULATED_GPS_CHECKSUM, a 								; update the CALCULATED_GPS_CHECKSUM
			; mov GPS_STATE, GPS_WAIT_FOR_M								; if received correct character, update GPS_STATE
			inc GPS_STATE 												; if received correct character, update GPS_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_r_cont0:
			ljmp serial_reset_GPS_STATE 								; reset GPS_STATE
	serial_service_cont4:

	; "M"
	; GPS_WAIT_FOR_M:
	cjne R3, #06h, serial_service_cont5
		cjne a, #4Dh, gps_wait_for_m_cont0								; check if received serial data is "M"
			xrl CALCULATED_GPS_CHECKSUM, a 								; update the CALCULATED_GPS_CHECKSUM
			; mov GPS_STATE, GPS_WAIT_FOR_C								; if received correct character, update GPS_STATE
			inc GPS_STATE 												; if received correct character, update GPS_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_m_cont0:
			ljmp serial_reset_GPS_STATE 								; reset GPS_STATE
	serial_service_cont5:

	; "C"
	; GPS_WAIT_FOR_C:
	cjne R3, #07h, serial_service_cont6
		cjne a, #43h, gps_wait_for_c_cont0								; check if received serial data is "C"
			xrl CALCULATED_GPS_CHECKSUM, a 								; update the CALCULATED_GPS_CHECKSUM
			mov GPS_WAIT_TIME, #01h										; wait out "," (one byte)
			; mov GPS_NEXT_STATE, GPS_WAIT_FOR_TIME						; load next state for after un-needed byte(s) are received
			mov GPS_NEXT_STATE, #08h   									; load next state for after un-needed byte(s) are received
			; mov GPS_STATE, GPS_WAIT									; if received correct character, update GPS_STATE
			mov GPS_STATE, #01h											; if received correct character, update GPS_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_c_cont0:
			ljmp serial_reset_GPS_STATE 								; reset GPS_STATE
	serial_service_cont6:

	; Time
	; GPS_WAIT_FOR_TIME:
	cjne R3, #08h, serial_service_cont7
		; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
		; ascii code for 0: #30h -> hex code for 0: #00h
		; ascii code for 1: #31h -> hex code for 1: #01h
		; ascii code for 2: #32h -> hex code for 1: #02h
		; etc....
		xrl CALCULATED_GPS_CHECKSUM, a 		  							; update the CALCULATED_GPS_CHECKSUM
		inc R4 															; increment R4
		anl a, #0Fh 													; bitwise AND received ascii with 00001111 (result is stored in a)
		mov @R0, a 														; move the data in a into location R0 is pointing
		inc R0															; update R0 pointer to next memory location
		cjne R4, #06h, gps_wait_for_time_cont0	 						; check if R4 (number of times we have looped) is equal to 6 (6 = number of received bytes for HH MM SS)
			mov GPS_WAIT_TIME, #05h										; wait out ".000," (5 bytes)
			; mov GPS_NEXT_STATE, GPS_WAIT_FOR_A 						; load next state for after un-needed byte(s) are received
			mov GPS_NEXT_STATE, #09h 		 							; load next state for after un-needed byte(s) are received
			; mov GPS_STATE, GPS_WAIT									; update GPS_STATE
			mov GPS_STATE, #01h 										; update GPS_STATE
		gps_wait_for_time_cont0:
			ljmp serial_service_end										; jump to end
	serial_service_cont7:

	; "A"
	; GPS_WAIT_FOR_A:
	cjne R3, #09h, serial_service_cont8
		cjne a, #41h, gps_wait_for_a_cont0 								; check if received serial data is "A"
			xrl CALCULATED_GPS_CHECKSUM, a								; update the CALCULATED_GPS_CHECKSUM
			mov GPS_WAIT_TIME, #01h										; wait out "," (one byte)
			; mov GPS_NEXT_STATE, GPS_WAIT_FOR_LATITUDE					; load next state for after un-needed byte(s) are received
			mov GPS_NEXT_STATE, #0Ah									; load next state for after un-needed byte(s) are received
			; mov GPS_STATE, GPS_WAIT									; if received correct character, update GPS_STATE
			mov GPS_STATE, #01h 										; update GPS_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_a_cont0:
			ljmp serial_reset_GPS_STATE 								; reset GPS_STATE
	serial_service_cont8:

	; Latitude
	; GPS_WAIT_FOR_LATITUDE:
	cjne R3, #0Ah, serial_service_cont9
		; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
		; ascii code for 0: #30h -> hex code for 0: #00h
		; ascii code for 1: #31h -> hex code for 1: #01h
		; ascii code for 2: #32h -> hex code for 1: #02h 
		; etc....
		xrl CALCULATED_GPS_CHECKSUM, a									; update the CALCULATED_GPS_CHECKSUM
		inc R4 															; increment R4
		cjne a, #2Eh, check_lat_for_comma								; check if "." was received
			ljmp serial_service_end										; if we receive a ".", we don't want to store it - jump to end
		check_lat_for_comma:
		cjne a, #2Ch, load_lat_data										; check if "," was received
			ljmp serial_service_end										; if we receive a ",", we don't want to store it - jump to end
		load_lat_data:													; keep loading data
		anl a, #0Fh 													; bitwise AND received ascii with 00001111 (result is stored in a)
		mov @R0, a 														; move the data in a into location R0 is pointing
		inc R0															; update R0 pointer to next memory location
		cjne R4, #0Bh, serial_service_end 								; check if R4 (number of times we have looped) is equal to 11 (11 = number of received bytes for llll.llll,a)
			; on the last latitude byte, we actually don't want to apply the 00001111 mask (the last byte is a letter), so re-write the final byte
			dec R0														; decrement pointer
			mov @R0, SBUF												; re-write ascii data (letter) into @R0
			inc R0														; update pointer
			mov GPS_WAIT_TIME, #01h										; wait out "," (1 byte)
			; mov GPS_NEXT_STATE, GPS_WAIT_FOR_LONGITUDE				; load next state for after un-needed byte(s) are received
			mov GPS_NEXT_STATE, #0Bh 									; load next state for after un-needed byte(s) are received
			; mov GPS_STATE, GPS_WAIT									; update GPS_STATE
			mov GPS_STATE, #01h 										; update GPS_STATE
			ljmp serial_service_end										; jump to end
	serial_service_cont9:

	; Longitude
	; GPS_WAIT_FOR_LONGITUDE:
	cjne R3, #0Bh, serial_service_cont10
		; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
		; ascii code for 0: #30h -> hex code for 0: #00h
		; ascii code for 1: #31h -> hex code for 1: #01h
		; ascii code for 2: #32h -> hex code for 1: #02h 
		; etc....
		xrl CALCULATED_GPS_CHECKSUM, a									; update the CALCULATED_GPS_CHECKSUM
		inc R4 															; increment R4
		cjne a, #2Eh, check_long_for_comma								; check if "." was received
			ljmp serial_service_end										; if we receive a ".", we don't want to store it - jump to end
		check_long_for_comma:
		cjne a, #2Ch, load_long_data									; check if "," was received
			ljmp serial_service_end										; if we receive a ",", we don't want to store it - jump to end
		load_long_data:													; keep loading data
		anl a, #0Fh 													; bitwise AND received ascii with 00001111 (result is stored in a)
		mov @R0, a 														; move the data in a into location R0 is pointing
		inc R0															; update R0 pointer to next memory location
		cjne R4, #0Ch, serial_service_end 								; check if R4 (number of times we have looped) is equal to 12 (12 = number of received bytes for yyyyy.yyyy,a)
			; on the last longitude byte, we actually don't want to apply the 00001111 mask (the last byte is a letter), so re-write the final byte
			dec R0														; decrement pointer
			mov @R0, SBUF												; re-write ascii data (letter) into @R0
			inc R0														; update pointer											
			mov GPS_WAIT_TIME, #0Dh										; wait out ",v.vv,ttt.tt," (13 bytes)
			mov GPS_NEXT_STATE, GPS_WAIT_FOR_DATE						; load next state for after un-needed byte(s) are received
			mov GPS_STATE, GPS_WAIT										; update GPS_STATE
			ljmp serial_service_end										; jump to end
	serial_service_cont10:

	; Date
	; GPS_WAIT_FOR_DATE:
	cjne R3, #0Ch, serial_service_cont11
		; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
		; ascii code for 0: #30h -> hex code for 0: #00h
		; ascii code for 1: #31h -> hex code for 1: #01h
		; ascii code for 2: #32h -> hex code for 1: #02h 
		; etc....
		xrl CALCULATED_GPS_CHECKSUM, a				 					; update the CALCULATED_GPS_CHECKSUM
		inc R4 															; increment R4
		anl a, #0Fh 													; bitwise AND received ascii with 00001111 (result is stored in a)
		mov @R0, a 														; move the data in a into location R0 is pointing
		inc R0															; update R0 pointer to next memory location
		cjne R4, #06h, serial_service_end 								; check if R4 (number of times we have looped) is equal to 6 (6 = number of received bytes for ddmmyy)
			mov GPS_WAIT_TIME, #04h										; wait out ",,,A" (4 bytes)
			; mov GPS_NEXT_STATE, GPS_WAIT_FOR_STAR						; load next state for after un-needed byte(s) are received
			mov GPS_NEXT_STATE, #0Dh 									; load next state for after un-needed byte(s) are received
			; mov GPS_STATE, GPS_WAIT									; update GPS_STATE
			mov GPS_STATE, #01h 										; update GPS_STATE
			ljmp serial_service_end										; jump to end
	serial_service_cont11:

	; "*"
	; GPS_WAIT_FOR_STAR:
	cjne R3, #0Dh, serial_service_cont12
		cjne a, #2Ah, serial_service_end								; check if received serial data is "*"
			; mov GPS_STATE, GPS_WAIT_FOR_CHECKSUM						; if received correct character, update GPS_STATE
			mov GPS_STATE, #0Eh 										; if received correct character, update GPS_STATE
			ljmp serial_service_end										; jump to end
	serial_service_cont12:

	; Checksum
	; GPS_WAIT_FOR_CHECKSUM:
	cjne R3, #0Eh, serial_service_cont13
		inc R4 															; increment R4
		lcall ASCII_TO_HEX 												; convert ascii to hex
		cjne R4, #01h, append_low_nibble								; check if we received our first checksum byte
			swap a 														; if this is our first checksum byte, we want to swap accumulator nibbles (i.e. #01h -> #10h)
			mov RECEIVED_GPS_CHECKSUM, a 								; move partial result into RECEIVED_GPS_CHECKSUM
			ljmp serial_service_end										; jump to end
		append_low_nibble:
			orl a, RECEIVED_GPS_CHECKSUM								; append the low nibble by bitwise OR (NOTE: the lower nibble of RECEIVED_GPS_CHECKSUM should be 0)!
			mov RECEIVED_GPS_CHECKSUM, a 								; move the final result into RECEIVED_GPS_CHECKSUM
			cjne a, CALCULATED_GPS_CHECKSUM, serial_reset_GPS_STATE		; compare RECEIVED_GPS_CHECKSUM (which should still be in a) with the CALCULATED_GPS_CHECKSUM
				; HAVE RECEIVED COMPLETE GPS NMEA $GPRMC SENTENCE
				setb P1.7 											; turn on GPS SYNC light
				loop1: 
				sjmp loop1 		; spin in place
	serial_service_cont13:

	; Reset
	serial_reset_GPS_STATE:
		; mov GPS_STATE, GPS_WAIT_FOR_DOLLAR							; Reset GPS_STATE
		mov GPS_STATE, #02h												; Reset GPS_STATE
		mov R0, #59h 													; load R0 (pointer) with memory address of RECEIVED_GPS_HRS_TENS

	; End
	serial_service_end:
ret 						; exit

ASCII_TO_HEX:
	; this routine is used for the GPS checksum
	; this routine takes a received ascii number/letter: 0 through F, and turns it into its hex equivalent:
	; (in)  ------- (out)
	; (acc) ------- (acc)
	; ASCII ------- HEX 
	; #30h	....... #00h
	; #31h	....... #01h
	; #32h	....... #02h
	; #33h	....... #03h
	; #34h	....... #04h
	; #35h	....... #05h
	; #36h	....... #06h
	; #37h	....... #07h
	; #38h	....... #08h
	; #39h	....... #09h
	; #41h	....... #0Ah
	; #42h	....... #0Bh
	; #43h	....... #0Ch
	; #44h	....... #0Dh
	; #45h	....... #0Eh
	; #46h	....... #0Fh
	push 0

	mov R0, a 					; save orignial a value in R0
	clr c 						; clear the carry flag
	subb a, #39h 				; compare the received SBUF (ascii) with #39h.  if the received data is less than #39h, then the carry flag is set
	jnc convert_alpha			; if the carry flag is NOT set, we are dealing with A, B, C, D, E, or F
		mov a, R0				; restore original a value
		anl a, #0Fh 			; convert numeric ascii to hex code
		ljmp ascii_to_hex_end	; jump to end
	convert_alpha:				
		mov a, R0				; restore original a value
		;subb a, #37h			; convert alpha ascii to hex code

	ascii_to_hex_end:

	pop 0
ret

end


