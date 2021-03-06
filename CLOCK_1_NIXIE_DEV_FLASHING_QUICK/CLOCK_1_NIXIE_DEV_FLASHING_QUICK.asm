; CLOCK_0
; 07/09/19
; This program updates all displays and is the barebones structure for the clock

; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

; External interrupt 0
.org 0003h
ENC_A_ISR:
	lcall ENC_A
	reti

; Timer 0 interrupt
.org 000Bh
TIMER_0_ISR:
	lcall TIMER_0_SERVICE 		; update the time
	reti 						; exit
	
; External interrupt 1
.org 0013h
ENC_B_ISR:
	lcall ENC_B
	reti

; Timer 2 interrupt
.org 002Bh
DISPLAY_ISR:
	clr TF2					; clear timer 2 interrupt flag
	lcall UPDATE_DISPLAYS 	; update the displays
	reti 					; exit


.org 100h
INIT:
	mov R5, #0Ch			; move 12 into R5 for displays update (nixie is displayed 1/12 as often as VFD and decatron)

	mov R7, #090h 			; try toggling the flashing less often

	; ====== State Variables ======
	; State Variable:
	.equ CLOCK_STATE, 7Fh

	; State Space:
	.equ SHOW_TIME_STATE, 7Eh
	.equ SET_TIME_STATE,  7Dh
	.equ SHOW_ALARM_STATE, 7Ch
	
	.equ NEXT_CLOCK_STATE, 7Bh
	.equ TIMEOUT, 7Ah
	.equ SET_ALARM_STATE, 79h

	mov SHOW_TIME_STATE, #01h
	mov SET_TIME_STATE,  #02h
	mov SHOW_ALARM_STATE, #03h
	mov SET_ALARM_STATE, #04h
	mov NEXT_CLOCK_STATE, SHOW_TIME_STATE

	; !!!NOTE: THIS IS DIFFERENT THAN YOU WOULD EXPECT: MOV iram_addr1,iram_addr2 MOVES CONTENTS OF iram_addr1 INTO iram_addr2!!!
	; COULD BE WRONG!!:
	mov CLOCK_STATE, SHOW_TIME_STATE	; start in SHOW_TIME_STATE
	; mov CLOCK_STATE, SET_TIME_STATE		; start in SET_TIME_STATE (for testing SET_TIME function)
	; =============================

	; ====== VFD Variables ======
	; bytes:
	.equ GRID_EN_1, 30h
	.equ GRID_EN_2, 31h
	.equ GRID_INDX, 32h
	.equ GRID9, 	33h
	.equ GRID8, 	34h
	.equ GRID7, 	35h
	.equ GRID6, 	36h
	.equ GRID5, 	37h
	.equ GRID4, 	38h
	.equ GRID3, 	39h
	.equ GRID2, 	3Ah
	.equ GRID1, 	3Bh
	; Fill in with values
	mov GRID9, #0FFh
	mov GRID8, #00h
	mov GRID7, #01h
	mov GRID6, #0Ah
	mov GRID5, #03h
	mov GRID4, #01h
	mov GRID3, #0Ah
	mov GRID2, #01h
	mov GRID1, #09h
	; Initialize the VFD
	lcall VFD_RESET
	; ===========================

	; ====== Nixie Variables ======
	; bytes:
	.equ NIX_EN,	3Ch
	.equ NIX_INDX, 	3Dh
	.equ NIX4,		3Eh
	.equ NIX3, 		3Fh
	.equ NIX2, 		40h
	.equ NIX1,		41h
	; Fill in with values
	mov NIX4, #00h
	mov NIX3, #00h
	mov NIX2, #00h
	mov NIX1, #00h
	; Initialize the nixies
	lcall NIX_RESET
	; =============================

	; ====== Decatron Variables ======
	; bytes:
	.equ DECA_STATE,		42h
	.equ DECATRON,			43h
	.equ DECATRON_BUFFER, 	44h
	; bits:
	.equ DECA_FORWARDS?, 		20h.0
	.equ DECA_RESET_CALLED?, 	20h.1

	; Fill in with values
	mov DECATRON, #00h
	mov DECATRON_BUFFER, DECATRON
	clr DECA_RESET_CALLED?
	; ===============================

	; ====== Rotary Encoder Variables ======
	; A_FLAG: this bit is the A flag, to prevent one CW/CCW turn as registering as more than one turn
	; B_FLAG: this bit is the B flag, to prevent on CCW/CW turn as registering as more than on turn
	; BUTTON_FLAG: this bit is the button flag, to prevent going through states "too fast"
	; bytes:
	.equ UPPER_BOUND,		55h		; this register holds the max value of whichever value is currently getting set
									; (e.g. decimal 12 for month)
	.equ LOWER_BOUND, 		56h 	; this register holds the min value of whichever value is currently getting set
									; (e.g. decimal 1 for month)

	; bits:
	.equ A_FLAG, 			21h.0
	.equ B_FLAG, 			21h.1
	.equ BUTTON_FLAG, 		21h.2
	.equ INC_LEAP_YEAR?,	21h.3
	.equ ROT_FLAG, 			21h.4
	.equ TRANSITION_STATE?,	22h.0

	; Fill in with values
	clr A_FLAG
	clr B_FLAG
	clr BUTTON_FLAG
	clr INC_LEAP_YEAR?
	clr ROT_FLAG
	clr TRANSITION_STATE?

	; Setup for rotary enocder pull-up resistors
	setb P3.2 						; Set P3.2 high to use internal pull-up resistor
	setb P3.3						; Set P3.3 high to use internal pull-up resistor
	setb P3.6						; Set P3.6 high to use internal pull-up resistor
	; ======================================

	; ====== Time Variables ======
	.equ HOURS,   45h
	.equ MINUTES, 46h
	.equ SECONDS, 47h

	.equ HR_TENS,  48h
	.equ HR_ONES,  49h
	.equ MIN_TENS, 4Ah
	.equ MIN_ONES, 4Bh

	mov HOURS, 		#00h
	mov MINUTES, 	#00h
	;mov SECONDS, 	#37h
	mov SECONDS, 	#00h
	; ============================

	; ====== Date Variables ======
	.equ MONTH,		4Ch
	.equ DAY, 		4Dh
	.equ YEAR, 		4Eh

	.equ MM_TENS, 	4Fh
	.equ MM_ONES, 	50h

	.equ DD_TENS, 	51h
	.equ DD_ONES, 	52h

	.equ YY_TENS, 	53h
	.equ YY_ONES, 	54h

	; Initialize date as 01-01-19
	mov MONTH, 	#01h
	mov DAY, 	#1Fh
	mov YEAR, 	#13h
	; ============================

	; ====== Flash Variables ======
	.equ VFD_FLASH_MASK,	57h
	.equ NIX_FLASH_MASK,	58h

	.equ VFD_MASK, 			59h
	.equ NIX_MASK, 			5Ah

	; Initialize flash masks
	mov VFD_FLASH_MASK, 00h  	;FIX?? does this need "#"
	mov NIX_FLASH_MASK, 0Fh  	;FIX?? does this need "#"

	mov VFD_MASK, #0FFh
	mov NIX_MASK, #0FFh
	; ============================

	; ====== Alarm Variables ======
	.equ ALARM_HOURS,	5Bh
	.equ ALARM_MINUTES,	5Ch

	; Initialize alarm
	mov ALARM_HOURS, #00h
	mov ALARM_MINUTES, #05h
	; ============================

	; Clear the carry flag
	clr c

	; IE (interrupt enable) register
	; _____________________________________________
	; | EA | - | ET2 | ES | ET1 | EX1 | ET0 | EX0 |
	; |____|___|_____|____|_____|_____|_____|_____|
	; EA (IE.7): interrupt enable bit (must be set to use interrupts)
	; IE.6: reserved
	; ET2 (IE.5): timer 2 overflow interrupt enable bit (only 8052)
	; ES (IE.4): serial port interrupt enable bit
	; ET1 (IE.3): timer 1 overflow interrupt enable bit
	; EX1 (IE.2): external interrupt 1 enable bit
	; ET0 (IE.1): timer 0 overflow interrupt enable bit
	; EX0 (IE.0): external interrupt 0 enable bit

	; Interrupt initialization
	setb EA 				; enable interrupts
	setb ET0				; enable timer 0 overflow interrupt
	clr EX0					; disable external interrupt 0 (gets enabled when rotary encoder is used)
	setb IT0				; set external interrupt 0 to be triggered by falling edge
	clr EX1					; disable external interrupt 1 (gets enabled when rotary encoder is used)
	setb IT1				; set external interrupt 1 to be triggered by falling edge

	; Timer 2 interrupt initialization (for display interrupt)
	setb ET2				; enable timer 2 interrupt
	mov T2CON, #04h			; set timer 2 in auto reload
	mov RCAP2H, #0FFh		; set high byte of timer 2 reload
	mov RCAP2L, #00h		; set low byte of timer 2 reload

	; Timer 0 interrupt initialization (for seconds interrupt)
	mov TMOD, #06h 			; set timer0 as a counter for the seconds (00000110 bin = 06 hex)
	mov TL0, #0C4h 			; initialize TL0 (#C4h for 60Hz, #CEh for 50Hz)
	mov TH0, #0C4h 			; initialize TH0 (#C4h for 60Hz, #CEh for 50Hz) - reload value			
	setb TR0 				; start timer 0

	; IP (interrupt priority) register
	; ____________________________________________
	; | - | - | PT2 | PS | PT1 | PX1 | PT0 | PX0 |
	; |___|___|_____|____|_____|_____|_____|_____|
	; PT2 (IP.5): timer 2 interrupt priority bit (only 8052)
	; PS (IP.4): serial port interrupt priority bit
	; PT1 (IP.3): timer 1 overflow interrupt priority bit
	; PX1 (IP.2): external interrupt 1 priority bit
	; PT0 (IP.1): timer 0 overflow interrupt priority bit
	; PX0 (IP.0): external interrupt 0 priority bit

	; Interrupt priority initialization
	mov IP, #22h 		; make timer 0 interrpt (update time) highest priority

	; Serial port initialization (mode 0 - synchronous serial communication)
	mov SCON, #00h 		; initialize the serial port in mode 0

	sjmp MAIN

MAIN:
	mov a, CLOCK_STATE

	cjne a, SHOW_TIME_STATE, main_cont0
		ljmp SHOW_TIME
	main_cont0:

	cjne a, SET_TIME_STATE, main_cont1
		ljmp SET_TIME
	main_cont1:

	cjne a, SHOW_ALARM_STATE, main_cont2
		ljmp SHOW_ALARM
	main_cont2:

	cjne a, SET_ALARM_STATE, main_cont3
		ljmp SET_ALARM
	main_cont3:

	sjmp MAIN


SHOW_TIME:
	; Split the month
	mov a, MONTH
	mov b, #0Ah
	div ab
	mov MM_TENS, a
	mov MM_ONES, b

	; Split the day
	mov a, DAY
	mov b, #0Ah
	div ab
	mov DD_TENS, a
	mov DD_ONES, b

	; Split the year
	mov a, YEAR
	mov b, #0Ah
	div ab
	mov YY_TENS, a
	mov YY_ONES, b

	; Update the hours if 12/24 hour switch is flipped
	mov R1, #45h 		; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
	lcall TWLV_TWFR_HOUR_ADJ

	; Split the hours
	; mov a, HOURS
	; mov b, #0Ah
	; div ab
	; mov HR_TENS, a
	; mov HR_ONES, b

	; Split the minutes
	mov a, MINUTES
	mov b, #0Ah
	div ab
	mov MIN_TENS, a
	mov MIN_ONES, b

	; Display the numbers
	mov GRID9, #0FFh
	mov GRID8, MM_TENS
	mov GRID7, MM_ONES
	; mov GRID6, #0Ah --> set in INIT
	mov GRID5, DD_TENS
	mov GRID4, DD_ONES
	; mov GRID3, #0Ah --> set in INIT
	mov GRID2, YY_TENS
	mov GRID1, YY_ONES

	;mov NIX4, HR_TENS --> This is taken care of in TWLV_TWFR_HOUR_ADJ
	;mov NIX3, HR_ONES --> This is taken care of in TWLV_TWFR_HOUR_ADJ
	mov NIX2, MIN_TENS
	mov NIX1, MIN_ONES

	mov DECATRON, SECONDS

	; jb P3.6, cont14					; check if rotary encoder button is pressed
	; 	mov R2, #0FFh					; load R2 for 255 counts
	; 	mov R3, #0FFh					; load R3 for 255 counts
	; 	loop3:							; rotary encoder button must be depressed for ~130ms before time/date can be changed (also acts as debounce)
	; 		jb P3.6, cont14				; check if rotary encoder button is still pressed
	; 		djnz R3, loop3				; decrement count in R3
	; 	mov R3, #0FFh					; reload R3 in case loop is needed again
	; 	djnz R2, loop3					; count R3 down again until R2 counts down
	; 	setb BUTTON_FLAG				; set the rotary encoder button flag
	; 	;mov GRID9, #00Bh
	; 	clr IE1							; clear any "built up" hardware interrupt flags for external interrupt 1
	; 	clr IE0							; clear any "built up" hardware interrupt flags for external interrupt 0
	; 	setb EX0						; enable external interrupt 0

	; 	;mov IP, #01h 					; make timer external interrpt 0 (update time) highest priority
		
	; 	setb EX1						; enable external interrupt 1
	; 	; setb IT0						; make interrupt triggered on falling edge
	; 	; setb IT1						; make interrupt triggered on falling edge
	; 	;mov CLOCK_STATE, SET_TIME_STATE	; change state to SET_TIME_STATE
	; 	mov CLOCK_STATE, SHOW_ALARM_STATE	; change state to SET_TIME_STATE
	; cont14:

	; listen for rotary encoder press
	mov NEXT_CLOCK_STATE, SHOW_TIME_STATE
	lcall CHECK_FOR_ROT_ENC_SHORT_OR_LONG_PRESS
	
	; jnb P3.6, cont14					; check if rotary encoder is still pressed
	; 	clr BUTTON_FLAG					; if not, clear the encoder button flag
	; cont14:

	
	; jb BUTTON_FLAG, cont15			; check to make sure BUTTON_FLAG is cleared
	; 	jb P3.6, cont15					; check if rotary encoder button is pressed
	; 		mov R2, #0FFh					; load R2 for 255 counts
	; 		mov R3, #0FFh					; load R3 for 255 counts
	; 		loop3:							; rotary encoder button must be depressed for ~130ms before time/date can be changed
											; (also acts as debounce)
	; 			jb P3.6, cont15			; check if rotary encoder button is still pressed
	; 			djnz R3, loop3				; decrement count in R3
	; 		mov R3, #0FFh					; reload R3 in case loop is needed again
	; 		cjne R2, #0C8h, cont16								; check if R2 has been decrement enough for a "short press"
	; 			; Calculate timeout (10 seconds)
	; 			mov a, SECONDS 		; move SECONDS into acc 
	; 			mov b, #3Ch 		; move 60 (dec) into b
	; 			add a, #0Ah 		; add 10 (dec) to the acc
	; 			div ab 				; divide a by b
	; 			mov TIMEOUT, b    	; move b (the remainder from above) into TIMEOUT
	; 			mov NEXT_CLOCK_STATE, SHOW_ALARM_STATE			; next state = SHOW_ALARM_STATE
	; 		cont16:
	; 		djnz R2, loop3					; count R3 down again until R2 counts down
	; 		mov NEXT_CLOCK_STATE, SET_TIME_STATE				; next state = SET_TIME_STATE
	; 		setb BUTTON_FLAG				; set the rotary encoder button flag
	; 		;mov GRID9, #00Bh
	; 		clr IE1							; clear any "built up" hardware interrupt flags for external interrupt 1
	; 		clr IE0							; clear any "built up" hardware interrupt flags for external interrupt 0
	; 		setb EX0						; enable external interrupt 0
	; 		;mov IP, #01h 					; make timer external interrpt 0 (update time) highest priority
	; 		setb EX1						; enable external interrupt 1
	; 		; setb IT0						; make interrupt triggered on falling edge
	; 		; setb IT1						; make interrupt triggered on falling edge
	; 		;mov CLOCK_STATE, SET_TIME_STATE	; change state to SET_TIME_STATE
	; cont15:

	; Check the NEXT_CLOCK_STATE
	mov a, NEXT_CLOCK_STATE
	cjne a, SHOW_ALARM_STATE, show_time_cont0
		lcall SHOW_TIME_STATE_TO_SHOW_ALARM_STATE
	show_time_cont0:
	cjne a, SET_TIME_STATE, show_time_cont1
		lcall SHOW_TIME_STATE_TO_SET_TIME_STATE
	show_time_cont1:

	; change state if needed
	mov CLOCK_STATE, NEXT_CLOCK_STATE	

ljmp MAIN


SET_TIME:
	; Disable 60/50Hz timing interrupt
	; clr ET0										; disable timer 0 overflow interrupt
	; clr TR0 										; stop timer0

	; clr P0.4										; turn off the decatron
	; mov DECATRON, #1Eh								; move 30 into decatron (to light up full)

	clr ROT_FLAG									; clear the ROT_FLAG

	; Enable external interrupts for rotary encoder
	;clr IE1							; clear any "built up" hardware interrupt flags for external interrupt 1
	;clr IE0							; clear any "built up" hardware interrupt flags for external interrupt 0
	;setb EX0						; enable external interrupt 0
	;setb EX1						; enable external interrupt 1

	; Set the month
	SET_MM:

		; Clear the TRANSITION_STATE? bit
		clr TRANSITION_STATE?

		; Move in mask values
		mov VFD_FLASH_MASK, #0FCh
		mov NIX_FLASH_MASK, #0FFh

		; Set the upper and lower bounds
		mov UPPER_BOUND, #0Ch 					; months can be 12 max
		mov LOWER_BOUND, #01h 					; months can be 1 min

		mov R0, #4Ch							; corresponds to memory address of MONTH

		set_mm_loop1:

		; Check for timeout event
		mov a, SECONDS
		cjne a, TIMEOUT, set_mm_cont2
			; check for valid day, given month
			lcall DD_ADJ
			; check for valid year, given month and day
			lcall YY_ADJ
			; clear the leap year bit
			clr INC_LEAP_YEAR?
			ljmp SET_SECONDS
		set_mm_cont2:

		; check for a rotary encoder short press
		lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
		jnb TRANSITION_STATE?, set_mm_cont3
			ljmp SET_DD 						; if there was a short press (TRANSITION_STATE? bit is set), go to next state
		set_mm_cont3:

		; Operations to dispay MONTH register in decimal format: MM
		mov a, MONTH
		mov b, #0Ah
		div ab
		mov MM_TENS, a
		mov MM_ONES, b

		; Display MONTH:
		mov GRID8, MM_TENS
		mov GRID7, MM_ONES

		; Update the hours if 12/24 hour switch is flipped
		mov R1, #45h 		; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
		lcall TWLV_TWFR_HOUR_ADJ

		sjmp set_mm_loop1
		
	; Set the day
	SET_DD:

		; Clear the TRANSITION_STATE? bit
		clr TRANSITION_STATE?

		; Move in mask values
		mov VFD_FLASH_MASK, #0E7h
		mov NIX_FLASH_MASK, #0FFh

		lcall DD_ADJ

		mov R0, #4Dh							; corresponds to memory address of DAY

		set_dd_loop1:

		; check for a rotary encoder short press
		lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
		jnb TRANSITION_STATE?, set_dd_cont3
			ljmp SET_YY 						; if there was a short press (TRANSITION_STATE? bit is set), go to next state
		set_dd_cont3:

		; Operations to dispay DAY register in decimal format: DD
		mov a, DAY
		mov b, #0Ah
		div ab
		mov DD_TENS, a
		mov DD_ONES, b

		; Display DAY:
		mov GRID5, DD_TENS
		mov GRID4, DD_ONES

		; Update the hours if 12/24 hour switch is flipped
		mov R1, #45h 		; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
		lcall TWLV_TWFR_HOUR_ADJ

		ljmp set_dd_loop1



	; Set the year
	SET_YY:

		; Clear the TRANSITION_STATE? bit
		clr TRANSITION_STATE?

		; Move in mask values
		mov VFD_FLASH_MASK, #3Fh
		mov NIX_FLASH_MASK, #0FFh

		lcall YY_ADJ

		mov R0, #4Eh							; corresponds to memory address of YEAR

		set_yy_loop1:

		; check for a rotary encoder short press
		lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
		jnb TRANSITION_STATE?, set_yy_cont3
			ljmp SET_HR 						; if there was a short press (TRANSITION_STATE? bit is set), go to next state
		set_yy_cont3:

		; Operations to dispay YEAR register in decimal format: YY
		mov a, YEAR
		mov b, #0Ah
		div ab
		mov YY_TENS, a
		mov YY_ONES, b

		; Display YEAR:
		mov GRID2, YY_TENS
		mov GRID1, YY_ONES

		; Update the hours if 12/24 hour switch is flipped
		mov R1, #45h 		; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
		lcall TWLV_TWFR_HOUR_ADJ

		ljmp set_yy_loop1


	; Set the hours
	SET_HR:

		; Clear the TRANSITION_STATE? bit
		clr TRANSITION_STATE?

		; Move in mask values
		mov VFD_FLASH_MASK, #0FFh
		mov NIX_FLASH_MASK, #0CFh

		; clear the leap year bit
		clr INC_LEAP_YEAR?

		; Set the upper and lower bounds
		mov UPPER_BOUND, #17h 					; hours can be 23 max
		mov LOWER_BOUND, #00h 					; hours can be 0 min

		mov R0, #45h							; corresponds to memory address of HOURS

		set_hr_loop1:

		; check for a rotary encoder short press
		lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
		jnb TRANSITION_STATE?, set_hr_cont3
			ljmp SET_MIN 						; if there was a short press (TRANSITION_STATE? bit is set), go to next state
		set_hr_cont3:

		mov R1, #45h 		; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
		lcall TWLV_TWFR_HOUR_ADJ

		; Operations to dispay HOURS register in decimal format: HR
		; mov a, HOURS
		; mov b, #0Ah
		; div ab
		; mov HR_TENS, a
		; mov HR_ONES, b

		; ; Display HOURS:
		; mov NIX4, HR_TENS
		; mov NIX3, HR_ONES

		sjmp set_hr_loop1


	; Set the minutes
	SET_MIN:

		; Clear the TRANSITION_STATE? bit
		clr TRANSITION_STATE?

		; Move in mask values
		mov VFD_FLASH_MASK, #0FFh
		mov NIX_FLASH_MASK, #3Fh

		; Set the upper and lower bounds
		mov UPPER_BOUND, #3Bh 					; minutes can be 59 max
		mov LOWER_BOUND, #00h 					; minutes can be 0 min

		mov R0, #46h							; corresponds to memory address of MINUTES

		set_min_loop1:

		; check for a rotary encoder short press
		lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
		jnb TRANSITION_STATE?, set_min_cont3
			ljmp SET_SECONDS					; if there was a short press (TRANSITION_STATE? bit is set), go to next state
		set_min_cont3:

		; Operations to dispay MINUTES register in decimal format: MIN
		mov a, MINUTES
		mov b, #0Ah
		div ab
		mov MIN_TENS, a
		mov MIN_ONES, b

		; Display MINUTES:
		mov NIX2, MIN_TENS
		mov NIX1, MIN_ONES

		; Update the hours if 12/24 hour switch is flipped
		mov R1, #45h 		; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
		lcall TWLV_TWFR_HOUR_ADJ

		sjmp set_min_loop1


	; Set the seconds (defaults to zeroing the seconds)
	SET_SECONDS:

		; Clear the TRANSITION_STATE? bit
		clr TRANSITION_STATE?

		; mov SECONDS, #00h 						; set seconds back to 0
		; mov DECATRON, SECONDS 					; move the seconds back into decatron

		; WORKED THE BEST BUT IMMEDIATELY INCREMENTS MINUTES
		;mov SECONDS, #3Bh 						; set seconds back to 0
		;clr P0.4

		mov SECONDS, #00h 						; set seconds back to 0
		;mov DECATRON, SECONDS 					; move the seconds back into decatron
		; mov DECA_STATE, #02h
		; mov R4, #01h

		;setb P0.4								; turn the decatron back on

	; Restart timer 0
	; setb ET0									; enable timer 0 overflow interrupt
	; mov TL0, #0C4h 							; initialize TL0 (#C4h for 60Hz, #CEh for 50Hz)
	; setb TR0 									; start timer0

	clr EX0						; disable external interrupt 0
	clr EX1						; disable external interrupt 1

	; Change the clock state
	mov CLOCK_STATE, SHOW_TIME_STATE			; change state to SHOW_TIME_STATE
	lcall DECA_TRANSITION  						; transition the decatron (MUST HAPPEN AFTER STATE CHANGE, 
	         									; OR FLASHING WILL CONTINUE IN DECA_TRANSITION)

ljmp MAIN

SHOW_ALARM:

	; Update the hours if 12/24 hour switch is flipped
	mov R1, #5Bh 		; move the address of ALARM_HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
	lcall TWLV_TWFR_HOUR_ADJ

	; Split the minutes
	mov a, ALARM_MINUTES
	mov b, #0Ah
	div ab
	mov MIN_TENS, a
	mov MIN_ONES, b

	;mov NIX4, HR_TENS --> This is taken care of in TWLV_TWFR_HOUR_ADJ
	;mov NIX3, HR_ONES --> This is taken care of in TWLV_TWFR_HOUR_ADJ
	mov NIX2, MIN_TENS
	mov NIX1, MIN_ONES

	mov DECATRON, SECONDS

	; listen for rotary encoder press
	mov NEXT_CLOCK_STATE, SHOW_ALARM_STATE
	lcall CHECK_FOR_ROT_ENC_SHORT_OR_LONG_PRESS

	; Check the NEXT_CLOCK_STATE
	mov a, NEXT_CLOCK_STATE
	cjne a, SHOW_TIME_STATE, show_alarm_cont0
		lcall SHOW_ALARM_STATE_TO_SHOW_TIME_STATE
	show_alarm_cont0:
	cjne a, SET_ALARM_STATE, show_alarm_cont1
		lcall SHOW_ALARM_STATE_TO_SET_ALARM_STATE
	show_alarm_cont1:

	; Check for timeout event
	mov a, SECONDS
	cjne a, TIMEOUT, show_alarm_cont2
		lcall SHOW_ALARM_STATE_TO_SHOW_TIME_STATE
		mov NEXT_CLOCK_STATE, SHOW_TIME_STATE
	show_alarm_cont2:

	; change state if needed
	mov CLOCK_STATE, NEXT_CLOCK_STATE

ljmp MAIN

SET_ALARM:

ljmp MAIN



TIMER_0_SERVICE:
	
	; push any used SFRs onto the stack to preserve their values
	push acc
	push PSW

	; mov a, CLOCK_STATE									; move CLOCK_STATE into the accumulator

	; cjne a, SET_TIME_STATE, timer_0_service_cont0		; check if CLOCK_STATE is SET_TIME_STATE
	; 	cpl P0.4										; if CLOCK_STATE is SET_TIME_STATE, flash the decatron

	; 	jb P0.4, timer_0_service_cont2
	; 		; if P0.4 is low (decatron is off), turn off all grids/nixies except for the one being set
	; 		mov VFD_MASK, VFD_FLASH_MASK
	; 		mov NIX_MASK, NIX_FLASH_MASK
	; 		ljmp timer_0_service_cont1					; jump to the end of ISR
	; 	timer_0_service_cont2:
	; 		; if P0.4 is high (decatron is on), turn on all grids/nixies
	; 		mov VFD_MASK, #0FFh
	; 		mov NIX_MASK, #0FFh

	; 	ljmp timer_0_service_cont1						; jump to the end of ISR

	; timer_0_service_cont0:
	
	; ; Move in mask values (so displays turn on after flashing in set mode)
	; mov VFD_MASK, #0FFh
	; mov NIX_MASK, #0FFh

	inc SECONDS 			; increment the seconds
	mov R6, SECONDS
	cjne R6, #3Ch, timer_0_service_cont1
		mov SECONDS, #00h
		inc MINUTES
		mov R6, MINUTES
		cjne R6, #3Ch, timer_0_service_cont1
			mov MINUTES, #00h
			inc HOURS
			mov R6, HOURS
			cjne R6, #18h, timer_0_service_cont1  ; if hours is 24 decimal, new day
				mov HOURS, #00h
	timer_0_service_cont1:

	; pop the original SFR values back into their place and restore their values
	pop PSW
	pop acc
ret 			 			; exit

; ====== State Transition Functions ======
CHECK_FOR_ROT_ENC_SHORT_PRESS:
	; This function is used to transisiton between sub-states, such as SET_MM, SET_DD, etc. in SET_TIME_STATE
	jnb P3.6, check_short_press_cont0				; check if rotary encoder is still pressed
		clr BUTTON_FLAG								; if not, clear the encoder button flag
	check_short_press_cont0:

	jb BUTTON_FLAG, check_short_press_cont1			; check to make sure BUTTON_FLAG is cleared
		jb P3.6, check_short_press_cont1			; check if rotary encoder button is pressed
			mov R2, #28h							; load R2 for 40 counts
			mov R3, #0FFh							; load R3 for 255 counts
			check_short_press_loop0:				; rotary encoder button must be depressed for ~20ms before time/date can be
													; changed (also acts as debounce)
				jb P3.6, check_short_press_cont1	; check if rotary encoder button is still pressed
				djnz R3, check_short_press_loop0	; decrement count in R3
			mov R3, #0FFh							; reload R3 in case loop is needed again
			djnz R2, check_short_press_loop0		; count R3 down again until R2 counts down
			setb BUTTON_FLAG						; set the BUTTON_FLAG
			setb TRANSITION_STATE?					; set the TRANSITION_STATE? bit
	check_short_press_cont1:
ret


CHECK_FOR_ROT_ENC_SHORT_OR_LONG_PRESS:
	; This function is used to transisiton between states, such as SET_TIME_STATE, SHOW_ALARM_STATE, etc.
	; This function listens for a rotary encoder short or long button press and determines which state to go to next based on the current CLOCK_STATE

	jnb P3.6, cont14					; check if rotary encoder is still pressed
		clr BUTTON_FLAG					; if not, clear the encoder button flag
	cont14:

	mov a, CLOCK_STATE 					; move the CLOCK_STATE into the accumulator

	jb BUTTON_FLAG, cont15			; check to make sure BUTTON_FLAG is cleared
		jb P3.6, cont15					; check if rotary encoder button is pressed
			mov R2, #0FFh					; load R2 for 255 counts
			mov R3, #0FFh					; load R3 for 255 counts
			loop3:							; rotary encoder button must be depressed for ~130ms before time/date can be changed (also acts as debounce)
				jb P3.6, cont15			; check if rotary encoder button is still pressed
				djnz R3, loop3				; decrement count in R3
			mov R3, #0FFh					; reload R3 in case loop is needed again
			cjne R2, #0E1h, cont16								; check if R2 has been decrement enough for a "short press"
				; if there has been a rot enc short press, determine next state based on current state
				cjne a, SHOW_TIME_STATE, cont17
					; if CLOCK_STATE = SHOW_TIME_STATE:
					;lcall SHOW_TIME_STATE_TO_SHOW_ALARM_STATE
					mov NEXT_CLOCK_STATE, SHOW_ALARM_STATE
					ljmp cont16
				cont17:
				; only other possibility is that we are in SHOW_ALARM_STATE
				;lcall SHOW_ALARM_STATE_TO_SHOW_TIME_STATE
				mov NEXT_CLOCK_STATE, SHOW_TIME_STATE		
			cont16:
			djnz R2, loop3					; count R3 down again until R2 counts down
			; if there has been a rot enc long press, determine next state based on current state
			cjne a, SHOW_TIME_STATE, cont18 
				;if CLOCK_STATE = SHOW_TIME_STATE
				;lcall SHOW_TIME_STATE_TO_SET_TIME_STATE
				mov NEXT_CLOCK_STATE, SET_TIME_STATE
				ljmp cont19
			cont18:
			; only other possibility is that we are in SHOW_ALARM_STATE
			;lcall SHOW_ALARM_STATE_TO_SET_ALARM_STATE
			mov NEXT_CLOCK_STATE, SET_ALARM_STATE
			cont19:
			setb BUTTON_FLAG				; set the rotary encoder button flag
	cont15:
ret

SHOW_TIME_STATE_TO_SHOW_ALARM_STATE:
	; set timeout (10 seconds)
	mov a, SECONDS 		; move SECONDS into acc 
	mov b, #3Ch 		; move 60 (dec) into b
	add a, #0Ah 		; add 10 (dec) to the acc
	div ab 				; divide a by b
	mov TIMEOUT, b    	; move b (the remainder from above) into TIMEOUT

	; Have VFD display "ALarnn"
	mov GRID9, #0FFh    ; BLANK
	mov GRID8, #0FFh	; BLANK
	mov GRID7, #0FFh	; BLANK
	mov GRID6, #0Ch 	; "A"
	mov GRID5, #0Dh 	; "L"
	mov GRID4, #0Eh 	; "a"
	mov GRID3, #0Fh 	; "r"		
	mov GRID2, #011h 	; "n"
	mov GRID1, #011h 	; "n"
ret

SHOW_TIME_STATE_TO_SET_TIME_STATE:
	; set timeout (59 seconds)
	mov a, SECONDS 		; move SECONDS into acc 
	mov b, #3Ch 		; move 60 (dec) into b
	add a, #3Bh 		; add 59 (dec) to the acc
	div ab 				; divide a by b
	mov TIMEOUT, b    	; move b (the remainder from above) into TIMEOUT

	; initalize external interrupts for rotary encoder
	clr IE1							; clear any "built up" hardware interrupt flags for external interrupt 1
	clr IE0							; clear any "built up" hardware interrupt flags for external interrupt 0
	setb EX0						; enable external interrupt 0
	;mov IP, #01h 					; make timer external interrpt 0 (update time) highest priority
	setb EX1						; enable external interrupt 1
ret

SHOW_ALARM_STATE_TO_SET_ALARM_STATE:
	; initalize external interrupts for rotary encoder
	clr IE1							; clear any "built up" hardware interrupt flags for external interrupt 1
	clr IE0							; clear any "built up" hardware interrupt flags for external interrupt 0
	setb EX0						; enable external interrupt 0
	;mov IP, #01h 					; make timer external interrpt 0 (update time) highest priority
	setb EX1						; enable external interrupt 1
ret

SHOW_ALARM_STATE_TO_SHOW_TIME_STATE:
	; Display "-" in grids 3 & 6
	mov GRID6, #0Ah 	; write dash to grid 6 for date
	mov GRID3, #0Ah 	; write dash to grid 3 for date
ret
; ========================================

; ====== Display Functions ======
UPDATE_DISPLAYS:
	lcall UPDATE_DECA					; update the decatron
	lcall UPDATE_VFD					; update the VFD

	; ISSUE?
	djnz R5, update_displays_cont0		; decrement the display update count, if it is zero, update the nixies
		lcall UPDATE_NIX				; update the nixies
		lcall FLASH_DISPLAYS 			; flash displays for set modes
		mov R5, #0Ch					; reset R5 with a value of 12
	update_displays_cont0:
ret


FLASH_DISPLAYS:
	push acc

	mov a, CLOCK_STATE									; move CLOCK_STATE into the accumulator
	cjne a, SET_TIME_STATE, flash_displays_cont0		; check if in SET_TIME_STATE, otherwise skip this

	djnz R7, flash_displays_cont1						; decrement the flash display count, if it is zero, toggle mask
		mov R7, #090h									; reset R7 for next interrupt
		cpl P0.4										; if CLOCK_STATE is SET_TIME_STATE, flash the decatron
		mov DECATRON, #1Eh								; move 30 into decatron (to light up full)

		jb P0.4, flash_displays_cont0
			; if P0.4 is low (decatron is off), check if we should flash displays (i.e. if ROT_FLAG is not set)
			jb ROT_FLAG, flash_displays_cont0
				; if P0.4 is low (decatron is off) and ROT_FLAG is not set, blink the display being set
				mov VFD_MASK, VFD_FLASH_MASK
				mov NIX_MASK, NIX_FLASH_MASK
				ljmp flash_displays_cont1					; jump to the end of routine

	flash_displays_cont0:
		; if P0.4 is high (decatron is on), turn on all grids/nixies
		mov VFD_MASK, #0FFh
		mov NIX_MASK, #0FFh

		clr ROT_FLAG				; clear the rotation flag (gets set in ENC_A or ENC_B ISR)

	flash_displays_cont1:
	pop acc
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
	push PSW

	clr c 						; clear the carry flag

	mov R1, NIX_INDX 			; move NIX_INDX into R1
	inc NIX_INDX				; increment NIX_INDX (to access next nixie bulb memory location)

	mov a, NIX_EN 				; move NIX_EN into accumulator
	orl a, @R1 					; bitwise OR the accumulator (NIX_EN) with @R1 (@NIX_INDX)
	anl a, NIX_MASK 			; bitwise AND the accumulator with NIX_MASK
	mov P2, #00h 				; clear all nixies
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
	pop PSW
	pop acc
	pop 1
ret


NIX_RESET:
	; This function resets the nixie registers after a complete cycle
	mov NIX_EN, #10h			; initialize nixie enable nibble
	mov NIX_INDX, #3Eh 			; initalize nixie index (start with nixie 4). This should reflect the memory location of NIX4.
ret


UPDATE_VFD:
	; This function squentially cycles through each VFD grid and applies the appropriate
	; signal to display the correct number (illuminate the correct segments) for each grid.
	; For each numeral/grid, three bytes of data are sent:
	; Byte 1 (GRID_EN_1):
	; | grid 9 | 0 | 0 | 0 | lost | lost | lost | lost |
	; Byte 2 (GRID_EN_2):
	; | grid 1 | grid 2 | grid 3 | grid 4 | grid 5 | grid 6 | grid 7 | grid 8 |
	; Byte 3:
	; | a | b | c | d | e | f | g | dp |
	; A VFD_NUM (@R1) value of #0Ah corresponds to a "-" for grids 1-9
	; A VFD_NUM (@R1) value of #0Bh corresponds to a "*" for grid 9
	; A VFD_NUM (@R1) value of #0Ch corresponds to a "A" for grids 1-9
	; A VFD_NUM (@R1) value of #0Dh corresponds to a "L" for grids 1-9
	; A VFD_NUM (@R1) value of #0Eh corresponds to a "a" for grids 1-9
	; A VFD_NUM (@R1) value of #0Fh corresponds to a "r" for grids 1-9
	; A VFD_NUM (@R1) value of #10h bugs out (flickers "-" in grid 9)
	; A VFD_NUM (@R1) value of #11h corresponds to a "n" for grids 1-9

	push 1							; push R1 onto the stack to preserve its value
	push acc						; push a onto the stack to preserve its value
	push PSW

	; move the contents of the respective grid into VFD_NUM (the number to be displayed - @R1)
	mov R1, GRID_INDX 			; move GRID_INX into R1
	inc GRID_INDX				; increment the grid index (to access next grid memory location)


	; The first two bytes of serial data are the independent of the numeral
	mov SBUF, GRID_EN_1 		; send the first byte down the serial line
	jnb TI, $ 					; wait for the entire byte to be sent
	clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software

	mov a, GRID_EN_2			; move GRID_EN_2 into the accumulator for bitwise AND operation
	anl a, VFD_MASK 			; bitwise AND accumutor (which stores GRID_END_2) with VFD_MASK (result is stored in the accumulator)
	mov SBUF, a					; send the second byte down the serial line
	jnb TI, $ 					; wait for the entire byte to be sent
	clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software

	; The third byte of serial data depends on the numeral to be shown
	
	; "0" numeral
	cjne @R1, #00h, vfd_cont0
		mov SBUF, #0FCh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont0:

	; "1" numeral
	cjne @R1, #01h, vfd_cont1
		mov SBUF, #060h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont1:

	; "2" numeral
	cjne @R1, #02h, vfd_cont2
		mov SBUF, #0DAh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont2:

	; "3" numeral
	cjne @R1, #03h, vfd_cont3
		mov SBUF, #0F2h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont3:

	; "4" numeral
	cjne @R1, #04h, vfd_cont4
		mov SBUF, #66h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont4:

	; "5" numeral
	cjne @R1, #05h, vfd_cont5
		mov SBUF, #0B6h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont5:

	; "6" numeral
	cjne @R1, #06h, vfd_cont6
		mov SBUF, #0BEh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont6:

	; "7" numeral
	cjne @R1, #07h, vfd_cont7
		mov SBUF, #0E0h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont7:

	; "8" numeral
	cjne @R1, #08h, vfd_cont8
		mov SBUF, #0FEh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont8:

	; "9" numeral
	cjne @R1, #09h, vfd_cont9
		mov SBUF, #0E6h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont9:

	; "-" numeral
	cjne @R1, #0Ah, vfd_cont10
		mov SBUF, #02h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont10:

	; "*" numeral
	cjne @R1, #0Bh, vfd_cont11
		mov SBUF, #01h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont11:

	; "BLANK" numeral
	cjne @R1, #0FFh, vfd_cont12
		mov SBUF, #00h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont12:

	; "A" numeral
	cjne @R1, #0Ch, vfd_cont13
		mov SBUF, #0EEh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont13:

	; "L" numeral
	cjne @R1, #0Dh, vfd_cont14
		mov SBUF, #1Ch				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont14:

	; "a" numeral
	cjne @R1, #0Eh, vfd_cont15
		mov SBUF, #0FAh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont15:

	; "r" numeral
	cjne @R1, #0Fh, vfd_cont16
		mov SBUF, #0Ah				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont16:

	; "n" numeral
	cjne @R1, #11h, vfd_cont17
		mov SBUF, #2Ah				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	vfd_cont17:

	
	setb P3.5						; load the MAX6921
	clr P3.5						; latch the MAX6921

	; Now we prepare for the next cycle
	mov a, GRID_EN_1					; move GRID_EN_1 into accumulator
	rlc a 								; rotate the accumlator left through carry (NOTE! the carry flag gets rotated into bit 0)
	mov GRID_EN_1, a 					; move the rotated result back into GRID_EN_1
	mov a, GRID_EN_2					; move GRID_EN_2 into the accumlator
	rlc a 								; rotate the acculator left through carry (NOTE! the carry flag gest rotated into bit 0)
	mov GRID_EN_2, a 					; move the rotated result back into GRID_EN_2
	clr c 								; clear the carry flag
	cjne R1, #3Ch, vfd_cont18 			; check if a complete grid cycle has finished (GRID_INDX == #3Ch)
		lcall VFD_RESET					; reset the VFD cycle
	vfd_cont18:

	pop PSW
	pop acc					; restore value of a to value before UPDATE_VFD was called
	pop 1					; restore value of R1 to value before UPDATE_VFD was called
ret


VFD_RESET:
	; This function resets the VFD registers after a complete cycle

	; Initalize grid index (start with grid 9)
	mov GRID_EN_1, #80h
	mov GRID_EN_2, #00h
	mov GRID_INDX, #33h 	; corresponds to memory location of GRID9
ret


UPDATE_DECA:
	; This function sequentially cycles through any active (as dictated by DECATRON)
	; decatron cathodes to ravel and unravel the appropriate number of seconds.
	; DECA_STATE points to the next cathode (Kx, G1, or G2) that is to be illuminated.
	; DECA_TOGGLE is called when the direction of the cathode swiping is to be flipped (R4 = 0).
	; On a change of direction, the end cathode remains illuminated for the next cycle.
	; DECA_FORWARDS? keeps track of the direction of the cathode swiping.
	; DECATRON_BUFFER ensures the correct direction of raveling/unraveling.

	; R4 stores the count of how many cathodes need to be lit up before switching directions.
	; R3 stores DECA_STATE.

	; push any used SFRs onto the stack to preserve their values
	push 3
	; push 4
	push acc
	push PSW 
	
	; jb DECA_RESET_CALLED?, update_deca_cont0	; check if the decatron needs to be initialized
	; 	lcall DECA_RESET 						; call the decatron init function
	; 	setb DECA_RESET_CALLED?					; set DECA_RESET_CALLED? flag
	; update_deca_cont0:

	mov R3, DECA_STATE							; move DECA_STATE to R3

	;============
	mov a, DECATRON   							; move DECATRON into the accumulator
	cjne a, #00h, deca_test_cont0				; if DECATRON = 0, then no need to toggle, blank the decatron and skip to the end, otherwise, continue
		
		; FIX -- FOR FAST MODE
		;mov DECATRON, #01						; move 1 into decatron (don't blank in fast mode, so the decatron always starts in the same spot)
		;lcall DECA_RESET 						; reset the decatron (light up K0)
		;sjmp deca_toggle_cont1 				; exit (NOTE: "ret" DOES NOT work for some reason...)

		clr P0.4								; turn off the decatron
		clr P0.0								; turn off K0
		clr P0.1								; turn off G1
		clr P0.2								; turn off G2
		clr P0.3								; turn off Kx
		ljmp update_deca_cont6 					; exit (NOTE: "ret" DOES NOT work for some reason...)
	deca_test_cont0:

	; mov a, DECATRON   							; move DECATRON into the accumulator
	cjne a, #01h, deca_test_cont1				; if DECATRON = 1, then no need to toggle, skip to the end, otherwise, continue
		;mov R4, DECATRON 						; reload R4
		lcall DECA_RESET 						; reset the decatron (light up K0)
		ljmp update_deca_cont6 					; exit (NOTE: "ret" DOES NOT work for some reason...)
	deca_test_cont1:
	;============

	djnz R4, update_deca_cont1 					; decrement R4 by 1, and check if it is zero
		lcall DECA_TOGGLE						; if R4 is zero, toggle the deca (call DECA_TOGGLE)
		sjmp update_deca_cont6 					; exit
	update_deca_cont1:

	cjne R3, #00h, update_deca_cont2 			; if we are in DECA_STATE 0, jump the arc to G1
		jb DECA_FORWARDS?, update_deca_cont3 	; check direction of swiping
			; if swiping counter-clockwise
			setb P0.1 							; pull G1 low (note inverter between 8051 pin and decatron)
			clr P0.2							; pull G2 high (note inverter between 8051 pin and decatron)
			mov DECA_STATE, #02h 				; DECA_STATE: 0 --> 2
			sjmp update_deca_cont6 				; exit
		update_deca_cont3:
		; if swiping clockwise
		setb P0.1 								; pull G1 low (note inverter between 8051 pin and decatron)
		clr P0.3 								; pull Kx high (note inverter between 8051 pin and decatron)
		clr P0.0 								; pull K0 high (note inverter between 8051 pin and decatron)
		inc DECA_STATE 							; DECA_STATE:  0 --> 1
		sjmp update_deca_cont6 					; exit
	update_deca_cont2:

	cjne R3, #01h, update_deca_cont4 			; if we are in DECA_STATE 1, jump the arc to G2
		jb DECA_FORWARDS?, update_deca_cont5 	; check direction of swiping
			; if swiping counter-clockwise
			setb P0.2 							; pull G2 low (note inverter between 8051 pin and decatron)
			clr P0.3 							; pull Kx high (note inverter between 8051 pin and decatron)
			clr P0.0 							; pull K0 high (note inverter between 8051 pin and decatron)
			dec DECA_STATE 						; DECA_STATE:  1 --> 0
			sjmp update_deca_cont6 				; exit
		update_deca_cont5:
		; if swiping clockwise
		setb P0.2 								; pull G2 low (note inverter between 8051 pin and decatron)
		clr P0.1 								; pull G1 high (note inverter between 8051 pin and decatron)
		inc DECA_STATE 							; DECA_STATE:  1 --> 2
		sjmp update_deca_cont6 					; exit
	update_deca_cont4:

	cjne R3, #02h, update_deca_cont6 			; if we are in DECA_STATE 2, jump the arc to Kx
		jb DECA_FORWARDS?, update_deca_cont7 	; check direction of swiping
			; if swiping counter-clockwise
			setb P0.3 							; pull Kx low (note inverter between 8051 pin and decatron)
			setb P0.0 							; pull K0 low (note inverter between 8051 pin and decatron)
			clr P0.1 							; pull G1 high (note inverter between 8051 pin and decatron)
			dec DECA_STATE 						; DECA_STATE:  2 --> 1
			sjmp update_deca_cont6 				; exit
		update_deca_cont7:
		; if swiping clockwise
		setb P0.3 								; pull Kx low (note inverter between 8051 pin and decatron)
		setb P0.0 								; pull K0 low (note inverter between 8051 pin and decatron)
		clr P0.2 								; pull G2 high (note inverter between 8051 pin and decatron)
		mov DECA_STATE, #00h 					; DECA_STATE:  2 --> 0
		sjmp update_deca_cont6 					; exit
	update_deca_cont6:

	; pop the original SFR values back into their place and restore their values
	pop PSW
	pop acc
	; pop 4
	pop 3
ret


DECA_TOGGLE:
	; This function is called from UPDATE_DECA whenever the swiping direction has to change.
	; If going from forward to backwards, DECA_STATE is decremented by 2 (incremented by 1) (mod 3).
	; If going from backwards to forward, DECA_STATE is incremented by 2 (decremented by 1) (mod 3).
	; DECA_FORWARDS? is a bit that keeps track of swiping direction.
	; DECA_FORWARDS? = 1 when swiping is clockwise, = 0 when swiping is counter-clockwise.
	; DECATRON_BUFFER is loaded with the latest DECATRON count when swiping in the appropriate direction.
	; This prevents erratic raveling/unraveling patterns.

	; R4 stores the count of how many cathodes need to be lit up before switching directions.
	; R3 stores DECA_STATE.

	; No need to push SFRs onto the stack because this function is called only from UPDATE_DECA, which
	; does the pushing/popping.


	cpl DECA_FORWARDS? 							; toggle the swiping direction

	; mov a, DECATRON   							; move DECATRON into the accumulator
	; cjne a, #00h, deca_toggle_cont8				; if DECATRON = 0, then no need to toggle, blank the decatron and skip to the end, otherwise, continue
		
	; 	; FIX -- FOR FAST MODE
	; 	;mov DECATRON, #01						; move 1 into decatron (don't blank in fast mode, so the decatron always starts in the same spot)
	; 	;lcall DECA_RESET 						; reset the decatron (light up K0)
	; 	;sjmp deca_toggle_cont1 				; exit (NOTE: "ret" DOES NOT work for some reason...)

	; 	clr P0.4								; turn off the decatron
	; 	clr P0.0								; turn off K0
	; 	clr P0.1								; turn off G1
	; 	clr P0.2								; turn off G2
	; 	clr P0.3								; turn off Kx
	; 	sjmp deca_toggle_cont1 					; exit (NOTE: "ret" DOES NOT work for some reason...)
	; deca_toggle_cont8:

	; ; mov a, DECATRON   							; move DECATRON into the accumulator
	; cjne a, #01h, deca_toggle_cont0				; if DECATRON = 1, then no need to toggle, skip to the end, otherwise, continue
	; 	;mov R4, DECATRON 						; reload R4
	; 	lcall DECA_RESET 						; reset the decatron (light up K0)
	; 	sjmp deca_toggle_cont1 					; exit (NOTE: "ret" DOES NOT work for some reason...)
	; deca_toggle_cont0:

	; see if DECATRON is greater than or less than (or equal to) 30
	clr c 										; clear the carry bit
	mov a, #1Eh									; move 30 into the accumulator
	subb a, DECATRON							; perform 30-DECATRON.  if DECATRON is greater than 30, the carry flag (c) will be set

	jb DECA_FORWARDS?, deca_toggle_cont2
		; if going from forwards to backwards
		jnc deca_toggle_cont3 					; if the carry flag is set, DECATRON > 30
			; if seconds are greater than 30:
			clr c 								; clear the carry flag
			mov a, #3Ch							; move 60 into the accumulator
			subb a, DECATRON					; perform 60-DECATRON.
			mov DECATRON_BUFFER, a 				; move the result into DECATRON_BUFFER
		deca_toggle_cont3:
		; if seconds are less than or equal to 30:
		mov R4, DECATRON_BUFFER 				; reload R4 with DECATRON_BUFFER  (this prevents erratic raveling)

		; update the DECA_STATE
		mov R3, DECA_STATE 						; move DECA_STATE into R3
		inc R3 									; increment R3 (same as decrementing twice after mod 3)
		cjne R3, #03h, deca_toggle_cont4 		; check if DECA_STATE needs to roll over from 3 to 0
			mov R3, #00h 						; if DECA_STATE = 3, set it to 0
		deca_toggle_cont4:
		mov DECA_STATE, R3 						; update DECA_STATE
		sjmp deca_toggle_cont1 					; exit ("ret" did work here, but changed to sjmp in case of monkey business...)

	deca_toggle_cont2:
	; if going from backwards to forwards
	jnc deca_toggle_cont5 						; if the carry flag is set, DECATRON > 30
		; if seconds are greater than 30
		mov R4, DECATRON_BUFFER 				; move DECATRON_BUFFER into R4 (this prevents erratic unraveling)
		sjmp deca_toggle_cont6 					; jump to update DECA_STATE

	deca_toggle_cont5:
	; if seconds are less than or equal to 30:
	mov R4, DECATRON 							; move DECATRON into R4
	mov DECATRON_BUFFER, DECATRON 				; update the DECATRON_BUFFER with DECATRON

	deca_toggle_cont6:
	; update the DECA_STATE
	mov R3, DECA_STATE 							; move DECA_STATE into R3
	dec R3 										; decrement R3 (same as incrementing twice after mod 3)
	cjne R3, #0FFh, deca_toggle_cont7 			; check if DECA_STATE needs to wrap around from 255 to 2
		mov R3, #02h 							; if DECA_STATE = 255, set it to 2
	deca_toggle_cont7:

	mov DECA_STATE, R3 							; update DECA_STATE

	deca_toggle_cont1:
ret 											; exit


DECA_RESET:
	mov DECA_STATE, #00h   			; initialize the decatron

	mov R4, DECATRON     			; initialize R4
	mov DECATRON_BUFFER, DECATRON   ; reset the decatron DECATRON_BUFFER (!!! Important or the decatron will flash - reason for decatron bug after
									; coming out of the SET_TIME state)

	setb P0.0 						; turn on K0
	clr P0.1						; turn off G1
	clr P0.2 						; turn off G2
	clr P0.3 						; turn off Kx
	
	setb P0.4						; turn on the decatron

	setb DECA_FORWARDS? 			; set the direction of the decatron
ret

DECA_TRANSITION:
	; This function is used to start the decatron at an arbitrary number of seconds.  It does so by starting with DECATRON at zero,
	; then quickily incrementing DECATRON (fast mode) until DECATRON == SECONDS.  An example where this transistion would be used
	; is going from SET ALARM --> SHOW TIME

	mov DECATRON, #00h 								; start with DECATRON=0
	lcall MED_DELAY 								; delay

	deca_transition_loop:
		mov a, SECONDS 								; move seconds into the accumulator
		cjne a, DECATRON, deca_transition_cont0
			ljmp deca_transition_cont1 				; if SECONDS (a) == DECATRON, then exit
		deca_transition_cont0:
		; if SECONDS (a) != DECATRON:
		lcall MED_DELAY  							; delay 
		inc DECATRON 								; increment the DECATRON
		mov a, #01h
		cjne a, DECATRON, deca_transition_loop
			lcall DECA_RESET
			lcall SHORT_DELAY
			lcall DECA_RESET
			lcall SHORT_DELAY
			lcall DECA_RESET
			lcall SHORT_DELAY

	ljmp deca_transition_loop 						; loop
	deca_transition_cont1:
ret
; ===============================


ENC_A:
	; push any used SFRs onto the stack to preserve their values
	push acc

	clr c 										; clear the carry bit

	jnb P3.3, enc_a_cont0
		setb A_FLAG
		clr B_FLAG
		ljmp enc_a_cont2
	enc_a_cont0:
	jb A_FLAG, enc_a_cont2
		inc @R0
		setb ROT_FLAG								; set the rotation flag
		mov VFD_MASK, #0FFh							; make all displays visible
		mov NIX_MASK, #0FFh							; make all displays visible
		setb A_FLAG
	enc_a_cont1:

	; jb A_FLAG, enc_a_cont0 						; check if A_FLAG is set
	; 	; if A_FLAG is not set:
	; 	setb B_FLAG 							; set B_FLAG
	; 	sjmp enc_a_cont1 						; jump to exit
	; enc_a_cont0:
	; ; if A_FLAG is set:
	; clr A_FLAG 									; clear A_FLAG
	; inc @R0 									; increment the register R0 is pointing to

	jnb INC_LEAP_YEAR?, enc_a_cont2				; check if INC_LEAP_YEAR? bit is set
		;if INC_LEAP_YEAR? bit is set, increment @R0 (YEAR) three more times (for a total of 4 times) 
		inc @R0
		inc @R0
		inc @R0
	enc_a_cont2:

	; check if @R0 is greater than UPPER_BOUND
	mov a, UPPER_BOUND 							; move UPPER_BOUND into accumulator
	subb a, @R0 								; subtract a - @R0
	jnc enc_a_cont3 							; jump to end if carry is not set
		; if @R0 is greater than UPPER_BOUND:
		mov @R0, LOWER_BOUND 					; rollover @R0
	enc_a_cont3:

	; pop the original SFR values back into their place and restore their values
	pop acc
ret 											; exit

ENC_B:
	; push any used SFRs onto the stack to preserve their values
	push acc

	clr c 										; clear the carry bit

	jnb P3.2, enc_b_cont0
		setb B_FLAG
		clr A_FLAG
		ljmp enc_b_cont2
	enc_b_cont0:
	jb B_FLAG, enc_b_cont2
		dec @R0
		setb ROT_FLAG								; set the rotation flag
		mov VFD_MASK, #0FFh							; make all displays visible
		mov NIX_MASK, #0FFh							; make all displays visible
		setb B_FLAG
	enc_b_cont1:

	; jb B_FLAG, enc_b_cont0 						; check if B_FLAG is set
	; 	; if B_FLAG is not set:
	; 	setb A_FLAG 							; set A_FLAG
	; 	sjmp enc_b_cont1 						; jump to exit
	; enc_b_cont0:
	; ; if B_FLAG is set:
	; clr B_FLAG 									; clear B_FLAG
	; dec @R0										; decrement the register R0 is pointing to

	jnb INC_LEAP_YEAR?, enc_b_cont2				; check if INC_LEAP_YEAR? bit is set
		;if INC_LEAP_YEAR? bit is set, decrement @R0 (YEAR) three more times (for a total of 4 times) 
		dec @R0
		dec @R0
		dec @R0
	enc_b_cont2:

	; check if @R0 is less than LOWER_BOUND
	mov a, @R0 									; move @R0 into accumulator
	subb a, LOWER_BOUND 						; subtract a - LOWER_BOUND
	jnc enc_b_cont4 							; jump to end if carry is not set
		; if @R0 is less than LOWER_BOUND:
		mov @R0, UPPER_BOUND 					; rollover @R0
	enc_b_cont4:

	; !! EDGE CASE: if the lower bound is zero, dec @R0 will rollover to 255, which still looks larger than LOWER_BOUND.
	; check if @R0 is greater than UPPER_BOUND
	mov a, UPPER_BOUND 							; move UPPER_BOUND into accumulator
	subb a, @R0 								; subtract a - @R0
	jnc enc_b_cont3 							; jump to end if carry is not set
		; if @R0 is greater than UPPER_BOUND:
		mov @R0, UPPER_BOUND 					; rollover @R0
	enc_b_cont3:

	; pop the original SFR values back into their place and restore their values
	pop acc
ret 											; exit

TWLV_TWFR_HOUR_ADJ:
	; push any used SFRs onto the stack to preserve their values
	push acc
	push PSW
	push b

	;mov a, HOURS
	mov a, @R1 									; move @R1 (i.e. HOURS, or ALARM_HOURS, etc.)
	jnb P0.6, twlv_twfr_hour_adj_cont1	 		; check if 12 or 24 hour time

	; Handle the 12-hour mode case
	cjne a, #00h, twlv_twfr_hour_adj_cont4		; check if time is 00:xx
		mov a, #0Ch 							; if hours are 00, 00 --> 12
		sjmp twlv_twfr_hour_adj_cont1
	twlv_twfr_hour_adj_cont4:
	cjne a, #0Ch, twlv_twfr_hour_adj_cont5		; check if time is 12:xx
		setb P1.5 								; turn on the PM light, and don't change the hours
		sjmp twlv_twfr_hour_adj_cont3
	twlv_twfr_hour_adj_cont5:
	subb a, #0Ch 								; check if current hour is > 12
	jc twlv_twfr_hour_adj_cont2
		setb P1.5 								; turn on the PM light
		sjmp twlv_twfr_hour_adj_cont3

	twlv_twfr_hour_adj_cont2:
	;mov a, HOURS
	mov a, @R1

	twlv_twfr_hour_adj_cont1:
	clr P1.5 									; turn off PM light

	twlv_twfr_hour_adj_cont3:
	; Operations to dispay HOURS register in decimal format: HR
	mov b, #0Ah
	div ab
	mov HR_TENS, a
	mov HR_ONES, b

	; Display HOURS:
	mov NIX4, HR_TENS
	mov NIX3, HR_ONES

	pop b
	pop PSW
	pop acc
ret

DD_ADJ:
	; This function adjust the day (DD) of the date such that the user cannot input an impossible date (i.e. 2/31/2019)
	; Set the upper and lower bounds
	mov R2, MONTH
	mov LOWER_BOUND, #01h 					; days can be 1 min

	January:
	cjne R2, #01h, February
		mov UPPER_BOUND, #1Fh 				; days can be 31 max
		ljmp set_dd_cont0 					; no need to check the day, continue

	February:
	cjne R2, #02h, March
		mov UPPER_BOUND, #1Dh 				; days can be 29 max
		ljmp set_dd_cont1 					; jump to check that the day is legal

	March:
	cjne R2, #03h, April
		mov UPPER_BOUND, #1Fh 				; days can be 31 max
		ljmp set_dd_cont0 					; no need to check the day, continue

	April:
	cjne R2, #04h, May
		mov UPPER_BOUND, #1Eh 				; days can be 30 max
		ljmp set_dd_cont1 					; jump to check that the day is legal

	May:
	cjne R2, #05h, June
		mov UPPER_BOUND, #1Fh 				; days can be 31 max
		ljmp set_dd_cont0 					; no need to check the day, continue

	June:
	cjne R2, #06h, July
		mov UPPER_BOUND, #1Eh 				; days can be 30 max
		ljmp set_dd_cont1 					; jump to check that the day is legal

	July:
	cjne R2, #07h, August
		mov UPPER_BOUND, #1Fh 				; days can be 31 max
		ljmp set_dd_cont0 					; no need to check the day, continue

	August:
	cjne R2, #08h, September
		mov UPPER_BOUND, #1Fh 				; days can be 31 max
		ljmp set_dd_cont0 					; no need to check the day, continue

	September:
	cjne R2, #09h, October
		mov UPPER_BOUND, #1Eh 				; days can be 30 max
		ljmp set_dd_cont1 					; jump to check that the day is legal

	October:
	cjne R2, #0Ah, November
		mov UPPER_BOUND, #1Fh 				; days can be 31 max
		ljmp set_dd_cont0 					; no need to check the day, continue

	November:
	cjne R2, #0Bh, December
		mov UPPER_BOUND, #1Eh 				; days can be 30 max
		ljmp set_dd_cont1 					; jump to check that the day is legal

	December:
	mov UPPER_BOUND, #1Fh 					; days can be 31 max
	ljmp set_dd_cont0 						; no need to check the day, continue

	set_dd_cont1:
	; check if DAY is greater than UPPER_BOUND
	mov a, UPPER_BOUND 						; move UPPER_BOUND into accumulator
	clr c 									; clear the carry bit
	subb a, DAY 							; subtract a - DAY
	jnc set_dd_cont0 						; jump to end if carry is not set
		; if DAY is greater than UPPER_BOUND:
		mov DAY, UPPER_BOUND 				; set the day to the max value
	set_dd_cont0:
ret

YY_ADJ:
	; This function adjust the day (DD) of the date such that the user cannot input an impossible date (i.e. 2/29/2019)
	; check for leap day condition

	; Set the upper and lower bounds
	mov LOWER_BOUND, #00h 					; years can be 00 min
	mov UPPER_BOUND, #63h					; years can be 99 max

	mov R2, MONTH

	cjne R2, #02h, set_yy_cont0				; if the month is february
		mov R2, DAY 						; move DAY into R2
		cjne R2, #1Dh, set_yy_cont0			; and if the day is the 29th 
			setb INC_LEAP_YEAR?				; set the INC_LEAP_YEAR? flag
			mov UPPER_BOUND, #60h 			; move 96 into UPPER_BOUND for leap day condition (don't want rollover to be 99)
			; adjust the year if it's not a multiple of 4
			mov a, YEAR 					; move the YEAR into the accumulator
			mov b, #04h						; move 4 into b
			div ab							; divide: a/b with the quotient in a and remainder in b
			mov a, b 						; move b into accumulator
			; decrement the YEAR until it is a multiple of 4
			set_yy_loop2:
			jz set_yy_cont0					; jump to set_yy_cont0 if the accumulator is zero (valid leap year)
				dec YEAR 					; decrement the YEAR
				dec a 						; decrement the accumulator
				sjmp set_yy_loop2 			; loop

	set_yy_cont0:
ret

SHORT_DELAY:
	push 0 					; push R0 onto the stack to preserve its value
	
	mov R0, #0FFh			; load R0 for 255 counts
	short_delay_loop:
	djnz R0, short_delay_loop
	
	pop	0					; restore value of R0 to value before DELAY was called
ret

MED_DELAY:
	push 0
	push 1

	mov R0, #08h					; load R0 for 8 counts
	mov R1, #0FFh					; load R1 for 255 counts		

	med_delay_loop:
		djnz R1, med_delay_loop		; decrement count in R1
	mov R1, #0FFh					; reload R1 in case loop is needed again
	
	djnz R0, med_delay_loop			; count R1 down again until R0 counts down

	pop 1
	pop 0
ret

LONG_DELAY:
	push 0
	push 1

	mov R0, #0FFh						; load R0 for 255 counts
	mov R1, #0FFh						; load R1 for 255 counts		

	long_delay_loop:
		djnz R1, long_delay_loop		; decrement count in R1
	mov R1, #0FFh						; reload R1 in case loop is needed again
	
	djnz R0, long_delay_loop			; count R1 down again until R0 counts down

	pop 1
	pop 0
ret

end
