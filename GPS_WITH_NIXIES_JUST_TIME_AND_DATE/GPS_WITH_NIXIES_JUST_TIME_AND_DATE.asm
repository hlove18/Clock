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

; Timer 2 interrupt
.org 002Bh
TIMER_2_SERVICE:
	clr TF2						; clear timer 2 interrupt flag
	lcall UPDATE_NIX
	reti

INIT:
	; !!!IMPORTANT!!! The following line moves the stack pointer to use upper 128bytes of data memory which is ONLY indirectly addressable
	; Note the stack pointer (SP) gets intialized to one bellow where the stack actually begins.  This change prevents the stack from over
	; writing our stored variables in addresss 20h to 7Fh (our directly addressable space).  This line fixes the bug that would cause the
	; set time sub state to transition spuriously.
	mov SP, #7Fh			; move the stack pointer to 7Fh. this is a big brain line of code.


	; ====== GPS State Variables ======
	; State Variables:
	.equ GPS_OBTAIN_DATA_SUB_STATE, 			7Dh
	.equ GPS_OBTAIN_DATA_NEXT_SUB_STATE, 		7Ch

	; $GPRMC,hhmmss.sss,A,llll.llll,a,yyyyy.yyyy,a,speed,angle,ddmmyy,,,A*77
	; $GPRMC,040555.000,A,3725.4817,N,12209.5683,W,0.42,201.93,070320,,,D*78

	GPS_WAIT equ 						1
	GPS_WAIT_FOR_DOLLAR equ  			2
	GPS_WAIT_FOR_G equ 	 				3
	GPS_WAIT_FOR_P equ	   				4
	GPS_WAIT_FOR_R equ	   				5
	GPS_WAIT_FOR_M equ	   				6
	GPS_WAIT_FOR_C equ	  		 		7
	GPS_WAIT_FOR_TIME equ	 	 		8	
	GPS_WAIT_FOR_A equ	 	 			9
	GPS_WAIT_FOR_LATITUDE equ	 	 	10
	GPS_WAIT_FOR_LONGITUDE equ			11
	GPS_WAIT_FOR_DATE equ				12
	GPS_WAIT_FOR_STAR equ				13
	GPS_WAIT_FOR_CHECKSUM equ			14

	; =============================

	; ====== Received GPS Variables ======
	.equ CALCULATED_GPS_CHECKSUM,				57h
	.equ GPS_WAIT_TIME,							58h
	.equ GPS_POINTER, 71h
	mov GPS_POINTER, #08h


	; !!!!!!! IMPORTANT: DO NOT MOVE THESE MEMORY LOCATIONS (pointers are used to update)
	; Time
	.equ RECEIVED_GPS_HRS_TENS,					08h ;59h 		; data stored here is in hex!
	.equ RECEIVED_GPS_HRS_ONES,					09h ;5Ah			; data stored here is in hex!
	.equ RECEIVED_GPS_MINS_TENS,				0Ah ;5Bh			; data stored here is in hex!
	.equ RECEIVED_GPS_MINS_ONES,				0Bh ;5Ch			; data stored here is in hex!
	.equ RECEIVED_GPS_SECS_TENS,				0Ch ;5Dh			; data stored here is in hex!
	.equ RECEIVED_GPS_SECS_ONES,				0Dh ;5Eh			; data stored here is in hex!

	; Date
	.equ RECEIVED_GPS_DAY_TENS,					0Eh ;5Fh 		; data stored here is in hex!
	.equ RECEIVED_GPS_DAY_ONES,					0Fh ;60h			; data stored here is in hex!
	.equ RECEIVED_GPS_MONTH_TENS,				10h ;61h			; data stored here is in hex!
	.equ RECEIVED_GPS_MONTH_ONES,				11h ;62h			; data stored here is in hex!
	.equ RECEIVED_GPS_YEAR_TENS,				12h ;63h			; data stored here is in hex!
	.equ RECEIVED_GPS_YEAR_ONES,				13h ;64h			; data stored here is in hex!

	; Checksum 
	.equ RECEIVED_GPS_CHECKSUM,					14h ;65h			; data stored here is in hex!

	; =============================

	; ====== Nixie Variables ======

	; These hold the values each nixie bulb will display
	.equ NIX4, 20h
	.equ NIX3, 21h
	.equ NIX2, 22h
	.equ NIX1, 23h

	; These registers keep track of which VFD grid should be on
	.equ NIX_EN, 24h

	; This variable is used to index through memory to access the correct numeral to display on each repsective nixie
	.equ NIX_INDX, 25h

	; Initialize
	mov NIX4, #00h
	mov NIX3, #00h
	mov NIX2, #00h
	mov NIX1, #00h

	; =============================

	; Initialize the Nixies
	lcall NIX_RESET
	lcall NIXIE_INIT

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
	
	; Initialize GPS_OBTAIN_DATA_SUB_STATE
	; !!!NOTE: THIS IS DIFFERENT THAN YOU WOULD EXPECT: MOV iram_addr1,iram_addr2 MOVES CONTENTS OF iram_addr1 INTO iram_addr2!!!
	mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_DOLLAR			; Reset GPS_OBTAIN_DATA_SUB_STATE
	; mov GPS_OBTAIN_DATA_SUB_STATE, #02h 							; Reset GPS_OBTAIN_DATA_SUB_STATE
	; Initialize data pointer
	mov R0, #08h ;#59h 									; load R0 (pointer) with memory address of RECEIVED_GPS_HRS_TENS
ret

NIXIE_INIT:
	setb EA 				; enable interrupts

	; Timer 2 interrupt initialization
	setb ET2			; enable timer 2 interrupt
	mov T2CON, #04h		; set timer 2 in auto reload
	mov RCAP2H, #0F4h	; set high byte of timer 2 reload
	mov RCAP2L, #048h	; set low byte of timer 2 reload 

	; Serial port initialization (mode 0 - synchronous serial communication)
	; mov SCON, #00h 		; initialize the serial port in mode 0

	; Turn on the NIXIE Colon:
	setb P1.4
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
	; Uses R3 to store the GPS_OBTAIN_DATA_SUB_STATE
	; Uses R4 as a counter (for loops)
	; Uses R0 as a data pointer
	
	; push registers/accumulator
	push acc 
	push 0
	push 3
	; push 4

	; NMEA $GPRMC sentence after fix:
	; $GPRMC,hhmmss.sss,A,llll.llll,a,yyyyy.yyyy,a,v.vv,ttt.tt,ddmmyy,,,A*77
	; $GPRMC,040555.000,A,3725.4817,N,12209.5683,W,0.42,201.93,070320,,,D*78

	mov a, SBUF										; move SBUF into a
	mov R3, GPS_OBTAIN_DATA_SUB_STATE								; move GPS_OBTAIN_DATA_SUB_STATE into R3

	; We use the GPS_WAIT state for information not needed, like commas, speed, or magnetic variation
	; Wait uses GPS_WAIT_TIME to determine how many received bytes to wait out
	; GPS_WAIT:
	; cjne R3, #01h, serial_service_cont0
	cjne R3, #GPS_WAIT, serial_service_cont0
		mov R4, #00h 													; R4 keeps track of how many times things loop (like how long to loop in the GPS_WAIT_FOR_TIME state)	
		xrl CALCULATED_GPS_CHECKSUM, a									; keep updating the CALCULATED_GPS_CHECKSUM
		djnz GPS_WAIT_TIME, gps_wait_cont0								; decrement until done waiting
			mov GPS_OBTAIN_DATA_SUB_STATE, GPS_OBTAIN_DATA_NEXT_SUB_STATE								; if wait is over, load GPS_OBTAIN_DATA_SUB_STATE with the next state.
		gps_wait_cont0:
			ljmp serial_service_end										; jump to end
	serial_service_cont0:

	; "$"
	; GPS_WAIT_FOR_DOLLAR:
	; cjne R3, #02h, serial_service_cont1
	cjne R3, #GPS_WAIT_FOR_DOLLAR, serial_service_cont1
		cjne a, #24h, gps_wait_for_dollar_cont0							; check if received serial data is "$"
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_G								; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			; inc GPS_OBTAIN_DATA_SUB_STATE 		 										; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
		gps_wait_for_dollar_cont0:
			ljmp serial_service_end										; jump to end
	serial_service_cont1:

	; "G"
	; GPS_WAIT_FOR_G:
	; cjne R3, #03h, serial_service_cont2
	cjne R3, #GPS_WAIT_FOR_G, serial_service_cont2
		cjne a, #47h, gps_wait_for_g_cont0								; check if received serial data is "G"
			mov CALCULATED_GPS_CHECKSUM, a								; initialize the CALCULATED_GPS_CHECKSUM (check sum does NOT include the "$" or "*" delimiters)
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_P								; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			; inc GPS_OBTAIN_DATA_SUB_STATE 												; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_g_cont0:
			ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE 								; reset GPS_OBTAIN_DATA_SUB_STATE
	serial_service_cont2:

	; "P"
	; GPS_WAIT_FOR_P:
	; cjne R3, #04h, serial_service_cont3
	cjne R3, #GPS_WAIT_FOR_P, serial_service_cont3
		cjne a, #50h, gps_wait_for_p_cont0								; check if received serial data is "P"
			xrl CALCULATED_GPS_CHECKSUM, a 								; update the CALCULATED_GPS_CHECKSUM
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_R								; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			; inc GPS_OBTAIN_DATA_SUB_STATE 												; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_p_cont0:
			ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE 								; reset GPS_OBTAIN_DATA_SUB_STATE
	serial_service_cont3:

	; "R"
	; GPS_WAIT_FOR_R:
	; cjne R3, #05h, serial_service_cont4
	cjne R3, #GPS_WAIT_FOR_R, serial_service_cont4
		cjne a, #52h, gps_wait_for_r_cont0								; check if received serial data is "R"
			xrl CALCULATED_GPS_CHECKSUM, a 								; update the CALCULATED_GPS_CHECKSUM
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_M								; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			; inc GPS_OBTAIN_DATA_SUB_STATE 												; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_r_cont0:
			ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE 								; reset GPS_OBTAIN_DATA_SUB_STATE
	serial_service_cont4:

	; "M"
	; GPS_WAIT_FOR_M:
	; cjne R3, #06h, serial_service_cont5
	cjne R3, #GPS_WAIT_FOR_M, serial_service_cont5
		cjne a, #4Dh, gps_wait_for_m_cont0								; check if received serial data is "M"
			xrl CALCULATED_GPS_CHECKSUM, a 								; update the CALCULATED_GPS_CHECKSUM
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_C								; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			; inc GPS_OBTAIN_DATA_SUB_STATE 												; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_m_cont0:
			ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE 								; reset GPS_OBTAIN_DATA_SUB_STATE
	serial_service_cont5:

	; "C"
	; GPS_WAIT_FOR_C:
	; cjne R3, #07h, serial_service_cont6
	cjne R3, #GPS_WAIT_FOR_C, serial_service_cont6
		cjne a, #43h, gps_wait_for_c_cont0								; check if received serial data is "C"
			xrl CALCULATED_GPS_CHECKSUM, a 								; update the CALCULATED_GPS_CHECKSUM
			mov GPS_WAIT_TIME, #01h										; wait out "," (one byte)
			mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_TIME						; load next state for after un-needed byte(s) are received
			; mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #08h   									; load next state for after un-needed byte(s) are received
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT									; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			; mov GPS_OBTAIN_DATA_SUB_STATE, #01h											; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_c_cont0:
			ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE 								; reset GPS_OBTAIN_DATA_SUB_STATE
	serial_service_cont6:

	; Time
	; GPS_WAIT_FOR_TIME:
	; cjne R3, #08h, serial_service_cont7
	cjne R3, #GPS_WAIT_FOR_TIME, serial_service_cont7
		; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
		; ascii code for 0: #30h -> hex code for 0: #00h
		; ascii code for 1: #31h -> hex code for 1: #01h
		; ascii code for 2: #32h -> hex code for 1: #02h
		; etc....
		xrl CALCULATED_GPS_CHECKSUM, a 		  							; update the CALCULATED_GPS_CHECKSUM
		inc R4 															; increment R4
		anl a, #0Fh 													; bitwise AND received ascii with 00001111 (result is stored in a)
		mov R0, GPS_POINTER
		mov @R0, a 														; move the data in a into location R0 is pointing
		inc GPS_POINTER ;R0															; update R0 pointer to next memory location
		cjne R4, #06h, gps_wait_for_time_cont0	 						; check if R4 (number of times we have looped) is equal to 6 (6 = number of received bytes for HH MM SS)
			mov GPS_WAIT_TIME, #05h										; wait out ".000," (5 bytes)
			mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_A 						; load next state for after un-needed byte(s) are received
			; mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #09h 		 							; load next state for after un-needed byte(s) are received
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT									; update GPS_OBTAIN_DATA_SUB_STATE
			; mov GPS_OBTAIN_DATA_SUB_STATE, #01h 										; update GPS_OBTAIN_DATA_SUB_STATE
		gps_wait_for_time_cont0:
			ljmp serial_service_end										; jump to end
	serial_service_cont7:

	; "A"
	; GPS_WAIT_FOR_A:
	; cjne R3, #09h, serial_service_cont8
	cjne R3, #GPS_WAIT_FOR_A, serial_service_cont8
		cjne a, #41h, gps_wait_for_a_cont0 								; check if received serial data is "A"
			xrl CALCULATED_GPS_CHECKSUM, a								; update the CALCULATED_GPS_CHECKSUM
			; mov GPS_WAIT_TIME, #01h										; wait out "," (one byte)
			mov GPS_WAIT_TIME, #26h

			; mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, GPS_WAIT_FOR_LATITUDE					; load next state for after un-needed byte(s) are received
			; mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #0Ah									; load next state for after un-needed byte(s) are received
			; mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #0Ch
			mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_DATE

			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT									; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			; mov GPS_OBTAIN_DATA_SUB_STATE, #01h 										; update GPS_OBTAIN_DATA_SUB_STATE
			ljmp serial_service_end										; jump to end
		gps_wait_for_a_cont0:
			ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE 								; reset GPS_OBTAIN_DATA_SUB_STATE
	serial_service_cont8:

	; Date
	; GPS_WAIT_FOR_DATE:
	; cjne R3, #0Ch, serial_service_cont11
	cjne R3, #GPS_WAIT_FOR_DATE, serial_service_cont11
		; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
		; ascii code for 0: #30h -> hex code for 0: #00h
		; ascii code for 1: #31h -> hex code for 1: #01h
		; ascii code for 2: #32h -> hex code for 2: #02h 
		; etc....
		xrl CALCULATED_GPS_CHECKSUM, a				 					; update the CALCULATED_GPS_CHECKSUM
		inc R4 															; increment R4
		anl a, #0Fh 													; bitwise AND received ascii with 00001111 (result is stored in a)
		mov R0, GPS_POINTER
		mov @R0, a 														; move the data in a into location R0 is pointing
		inc GPS_POINTER ;R0															; update R0 pointer to next memory location
		cjne R4, #06h, serial_service_end 								; check if R4 (number of times we have looped) is equal to 6 (6 = number of received bytes for ddmmyy)
			mov GPS_WAIT_TIME, #04h										; wait out ",,,A" (4 bytes)
			mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_STAR						; load next state for after un-needed byte(s) are received
			; mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #0Dh 									; load next state for after un-needed byte(s) are received
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT									; update GPS_OBTAIN_DATA_SUB_STATE
			; mov GPS_OBTAIN_DATA_SUB_STATE, #01h 										; update GPS_OBTAIN_DATA_SUB_STATE
			ljmp serial_service_end										; jump to end
	serial_service_cont11:

	; "*"
	; GPS_WAIT_FOR_STAR:
	; cjne R3, #0Dh, serial_service_cont12
	cjne R3, #GPS_WAIT_FOR_STAR, serial_service_cont12
		cjne a, #2Ah, serial_service_end	 ;3/14/2020 SHOULD THIS GO TO serial_reset_GPS_OBTAIN_DATA_SUB_STATE?????!!!!!!!!!!							; check if received serial data is "*"
			mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_CHECKSUM						; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			; mov GPS_OBTAIN_DATA_SUB_STATE, #0Eh 										; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
			ljmp serial_service_end										; jump to end
	serial_service_cont12:

	; Checksum
	; GPS_WAIT_FOR_CHECKSUM:
	; cjne R3, #0Eh, serial_service_cont13
	cjne R3, #GPS_WAIT_FOR_CHECKSUM, serial_service_cont13
		inc R4 															; increment R4
		lcall ASCII_TO_HEX 												; convert ascii to hex
		cjne R4, #01h, append_low_nibble								; check if we received our first checksum byte
			swap a 														; if this is our first checksum byte, we want to swap accumulator nibbles (i.e. #01h -> #10h)
			mov RECEIVED_GPS_CHECKSUM, a 								; move partial result into RECEIVED_GPS_CHECKSUM
			ljmp serial_service_end										; jump to end
		append_low_nibble:
			orl a, RECEIVED_GPS_CHECKSUM								; append the low nibble by bitwise OR (NOTE: the lower nibble of RECEIVED_GPS_CHECKSUM should be 0)!
			mov RECEIVED_GPS_CHECKSUM, a 								; move the final result into RECEIVED_GPS_CHECKSUM
			cjne a, CALCULATED_GPS_CHECKSUM, serial_reset_GPS_OBTAIN_DATA_SUB_STATE		; compare RECEIVED_GPS_CHECKSUM (which should still be in a) with the CALCULATED_GPS_CHECKSUM
				; HAVE RECEIVED COMPLETE GPS NMEA $GPRMC SENTENCE
				setb P1.7 												; turn on GPS SYNC light
				;lcall NIXIE_INIT
				mov NIX4, RECEIVED_GPS_HRS_TENS
				mov NIX3, RECEIVED_GPS_HRS_ONES
				mov NIX2, RECEIVED_GPS_MINS_TENS
				mov NIX1, RECEIVED_GPS_MINS_ONES
				; mov NIX4, #04h
				; mov NIX3, #03h
				; mov NIX2, #02h
				; mov NIX1, #01h
				; stop serial interrupt
				clr ES
				; stop timer 1
				clr TR1
				ljmp serial_service_end
	serial_service_cont13:

	; Reset
	serial_reset_GPS_OBTAIN_DATA_SUB_STATE:
		mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_DOLLAR							; Reset GPS_OBTAIN_DATA_SUB_STATE
		; mov GPS_OBTAIN_DATA_SUB_STATE, #02h												; Reset GPS_OBTAIN_DATA_SUB_STATE
		; mov R0, #08h ;#59h 													; load R0 (pointer) with memory address of RECEIVED_GPS_HRS_TENS
		mov GPS_POINTER, #08h 												; load GPS_POINTER (pointer) with memory address of RECEIVED_GPS_HRS_TENS

	; End
	serial_service_end:

	; pop registers/accumulator
	; pop 4
	pop 3
	pop 0
	pop acc
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

UPDATE_NIX:
	; This function sequentially cycles through each nixie bulb and applies the appropriate
	; signal to display the correct number (illuminate the correct cathode) for each bulb.
	; For each bulb, one byte of data is sent:
	; Byte 1:
	; |<- High Nibble ->|<- Low Nibble ->|
	; |      NIX_EN     |     number     |
	; NIX_EN:
	;   1000 - NIX1 displays number
	;   0100 - NIX2 displays number
	;   0010 - NIX3 displays number
	;   0001 - NIX4 displays number

	; R1 stores NIX_INDX.

	; push any used SFRs onto the stack to preserve their values
	push 1
	push acc

	clr c 						; clear the carry flag

	mov R1, NIX_INDX 			; move NIX_INDX into R1
	inc NIX_INDX				; increment NIX_INDX (to access next nixie bulb memory location)

	mov a, NIX_EN 				; move NIX_EN into accumulator
	orl a, @R1 					; bitwise or the accumulator (NIX_EN) with @R1 (@NIX_INDX)
	mov P2, #00h 				; clear all nixies
	lcall DELAY 				; wait
	mov P2, a 					; light up the appropriate nixie

	; prepare for the next cycle
	mov a, NIX_EN				; move NIX_EN into accumulator
	rlc a 						; rotate the accumulator left through carry (NOTE! the carry flag gets rotated into bit 0)
	mov NIX_EN, a 				; move the rotated result back into NIX_EN
	jnc update_nix_cont1 		; check if a complete nixie cycle has finished (the carry flag has been set)
		clr c 					; clear the carry flag
		lcall NIX_RESET			; reset the nixie cycle
	update_nix_cont1:

	; pop the original SFR values back into their place and restore their values
	pop acc
	pop 1

ret


DELAY:
	push 0 						; push R0 onto the stack to preserve its value
	
	mov R0, #0FFh				; load R0 for 255 counts
	delay_loop1:
	djnz R0, delay_loop1
	
	pop	0						; restore value of R0 to value before DELAY was called
	
ret


NIX_RESET:
	; This function resets the nixie registers after a complete cycle
	mov NIX_EN, #10h			; initialize nixie enable nibble
	mov NIX_INDX, #20h 			; initalize nixie index (start with nixie 4). This should reflect the memory location of NIX4.

ret

end


