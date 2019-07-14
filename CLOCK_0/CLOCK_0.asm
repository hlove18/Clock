; CLOCK_0
; 07/09/19
; This program updates all displays and is the barebones structure for the clock

; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

; Timer 2 interrupt
.org 002Bh
DISPLAY_ISR:
	clr TF2					; clear timer 2 interrupt flag
	lcall UPDATE_DISPLAYS 	; update the displays
	reti 					; exit


.org 100h
INIT:
	mov R5, #0Ch			; move 12 into R5 for displays update (nixie is displayed 1/12 as often as VFD and decatron)

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
	mov GRID7, #06h
	mov GRID6, #0Ah
	mov GRID5, #00h
	mov GRID4, #07h
	mov GRID3, #0Ah
	mov GRID2, #01h
	mov GRID1, #08h
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
	mov NIX4, #04h
	mov NIX3, #03h
	mov NIX2, #02h
	mov NIX1, #01h
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
	mov DECATRON, #2Dh
	mov DECATRON_BUFFER, DECATRON
	clr DECA_RESET_CALLED?
	; ===============================

	; Clear the carry flag
	clr c

	; Interrupt initialization
	setb EA 				; enable interrupts

	; Timer 2 interrupt initialization
	setb ET2				; enable timer 2 interrupt
	mov T2CON, #04h			; set timer 2 in auto reload
	mov RCAP2H, #0FFh		; set high byte of timer 2 reload
	mov RCAP2L, #00h		; set low byte of timer 2 reload 

	; Serial port initialization (mode 0 - synchronous serial communication)
	mov SCON, #00h 		; initialize the serial port in mode 0

	sjmp MAIN

MAIN:
	sjmp MAIN



UPDATE_DISPLAYS:
	djnz R5, update_displays_cont0		; decrement the display update count, if it is zero, update the nixies
		lcall UPDATE_NIX				; update the nixies
		mov R5, #0Ch					; reset R5 with a value of 12
	update_displays_cont0:
	lcall UPDATE_VFD					; update the VFD
	lcall UPDATE_DECA					; update the decatron
	
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

	push 1							; push R1 onto the stack to preserve its value
	push acc						; push a onto the stack to preserve its value

	; move the contents of the respective grid into VFD_NUM (the number to be displayed - @R1)
	mov R1, GRID_INDX 			; move GRID_INX into R1
	inc GRID_INDX				; increment the grid index (to access next grid memory location)


	; The first two bytes of serial data are the independent of the numeral
	mov SBUF, GRID_EN_1 		; send the first byte down the serial line
	jnb TI, $ 					; wait for the entire byte to be sent
	clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	mov SBUF, GRID_EN_2			; send the second byte down the serial line
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
	
	setb P3.5						; load the MAX6921
	;lcall DELAY					; wait
	clr P3.5						; latch the MAX6921

	; Now we prepare for the next cycle
	mov a, GRID_EN_1					; move GRID_EN_1 into accumulator
	rlc a 								; rotate the accumlator left through carry (NOTE! the carry flag gets rotated into bit 0)
	mov GRID_EN_1, a 					; move the rotated result back into GRID_EN_1
	mov a, GRID_EN_2					; move GRID_EN_2 into the accumlator
	rlc a 								; rotate the acculator left through carry (NOTE! the carry flag gest rotated into bit 0)
	mov GRID_EN_2, a 					; move the rotated result back into GRID_EN_2
	clr c 								; clear the carry flag
	cjne R1, #3Ch, vfd_cont13 			; check if a complete grid cycle has finished (GRID_INDX == #3Ch)
		lcall VFD_RESET					; reset the VFD cycle
	vfd_cont13:

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
	
	jb DECA_RESET_CALLED?, update_deca_cont0	; check if the decatron needs to be initialized
		lcall DECA_RESET 						; call the decatron init function
		setb DECA_RESET_CALLED?					; set DECA_RESET_CALLED? flag
	update_deca_cont0:

	mov R3, DECA_STATE							; move DECA_STATE to R3

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
		setb P0.1 								; pull G1 high (note inverter between 8051 pin and decatron)
		inc DECA_STATE 							; DECA_STATE:  0 --> 1
		sjmp update_deca_cont6 					; exit
	update_deca_cont2:

	cjne R3, #01h, update_deca_cont4 			; if we are in DECA_STATE 1, jump the arc to G2
		jb DECA_FORWARDS?, update_deca_cont5 	; check direction of swiping
			; if swiping counter-clockwise
			setb P0.2 							; pull G2 low (note inverter between 8051 pin and decatron)
			dec DECA_STATE 						; DECA_STATE:  1 --> 0
			sjmp update_deca_cont6 				; exit
		update_deca_cont5:
		; if swiping clockwise
		setb P0.2 								; pull G2 high (note inverter between 8051 pin and decatron)
		clr P0.1 								; pull G1 high (note inverter between 8051 pin and decatron)
		inc DECA_STATE 							; DECA_STATE:  1 --> 2
		sjmp update_deca_cont6 					; exit
	update_deca_cont4:

	cjne R3, #02h, update_deca_cont6 			; if we are in DECA_STATE 1, jump the arc to Kx
		jb DECA_FORWARDS?, update_deca_cont7 	; check direction of swiping
			; if swiping counter-clockwise
			clr P0.1 							; pull G1 high (note inverter between 8051 pin and decatron)
			dec DECA_STATE 						; DECA_STATE:  2 --> 1
			sjmp update_deca_cont6 				; exit
		update_deca_cont7:
		; if swiping clockwise
		clr P0.2 								; pull G2 high (note inverter between 8051 pin and decatron)
		mov DECA_STATE, #00h 					; DECA_STATE:  2 --> 0
		sjmp update_deca_cont6 					; exit
	update_deca_cont6:

	; pop the original SFR values back into their place and restore their values
	pop acc
	; pop 4
	pop 3
	
ret



DECA_RESET:
	mov DECA_STATE, #00h   	; initialize the decatron

	mov R4, DECATRON     	; initialize R4
	
	setb P0.0				; reset decatron
	lcall LONG_DELAY
	clr P0.0
	lcall LONG_DELAY

	setb P0.0				; reset decatron
	lcall LONG_DELAY
	clr P0.0
	lcall LONG_DELAY

	setb P0.0				; reset decatron
	lcall LONG_DELAY
	clr P0.0
	lcall LONG_DELAY

	clr P0.1
	clr P0.2

	setb DECA_FORWARDS? 	; set the direction of the decatron

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

	mov a, DECATRON   							; move DECATRON into the accumulator
	cjne a, #01h, deca_toggle_cont0				; if DECATRON = 1, then no need to toggle, skip to the end, otherwise, continue
		mov R4, DECATRON 						; reload R4
		sjmp deca_toggle_cont1 					; exit (NOTE: "ret" DOES NOT work for some reason...)
	deca_toggle_cont0:

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

ret 	 										; exit


LONG_DELAY:
	mov R0, #0FFh								; load R0 for 255 counts
	mov R1, #0FFh								; load R1 for 255 counts		

	loop2:
		djnz R1, loop2							; decrement count in R1
	mov R1, #0FFh								; reload R1 in case loop is needed again
	
	djnz R0, loop2								; count R1 down again until R0 counts down
ret


end
