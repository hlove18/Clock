; VFD
; HENRY LOVE
; 06/05/19
; This program uses timer 2 to update the vfd and a rotary enocder to set the date.

; ======Registers======
; R0 - used in delay fxn
; R0 - used in MAIN
; R1 - used in MAIN

; !!! MAKE SURE TO PUSH AND POP FOR ISRS !!!
; VFD ISR:
; R1 - used in VFD ISR
; a - used in VFD ISR

; ENC A ISR:
; R0 - used in ENC A ISR

; ENC B ISR:
; R0 - used in ENC B ISR

; ======Loops======
; loop0


; ======Continues======
; cont0
; cont1
; cont2
; cont3
; cont4
; cont5
; cont6
; cont7
; cont8
; cont9
; cont10
; cont11
; cont12
; cont13


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

; Timer 2 interrupt
.org 002Bh
VFD_ISR:
	clr TF2					; clear timer 2 interrupt flag
	lcall UPDATE_VFD
	reti

; External interrupt 1
.org 0013h
ENC_B_ISR:
	lcall ENC_B
	reti

.org 100h
INIT:
	; Variables

	; ======VFD variables======

	; Grid 9 is on the left, grid 1 is on the right.  These hold the values each
	; grid will display
	.equ GRID9, 20h
	.equ GRID8, 21h
	.equ GRID7, 22h
	.equ GRID6, 23h
	.equ GRID5, 24h
	.equ GRID4, 25h
	.equ GRID3, 26h
	.equ GRID2, 27h
	.equ GRID1, 28h

	; These registers keep track of which VFD grid should be on
	.equ GRID_EN_1, 29h
	.equ GRID_EN_2, 2Ah

	; This variable is used to index through memory to access the correct numeral
	; to display on each repsective VFD grid
	.equ GRID_INDX, 2Bh

	; Intilize date with sample date
	mov GRID9, #0FFh
	mov GRID8, #00h
	mov GRID7, #06h
	mov GRID6, #0Ah
	mov GRID5, #00h
	mov GRID4, #07h
	mov GRID3, #0Ah
	mov GRID2, #01h
	mov GRID1, #08h

	; Initalize the VFD
	lcall VFD_RESET

	; ======Rotary encoder variables======

	; This register holds variales for using the rotary encoder:
	; ENC.0: this bit is the A flag, to prevent one CW/CCW turn as registering as more than one turn
	; ENC.1: this bit is the B flag, to prevent on CCW/CW turn as registering as more than on turn
	; ENC.2: this bit is the button flag, to prevent going through states "too fast"
	.equ ENC, 2Ch

	; Rotary encoder registers
	; .equ ENC_VALUE, 2Dh
	; .equ ENC_ONES, 2Dh
	; .equ ENC_TENS, 2Eh

	; Modulus register
	; This register holds the max value of the count (i.e. for SET_MM, MOD should be decimal 12)
	.equ MODULUS, 2Fh

	; Date registers
	.equ MONTH, 30h
	.equ DAY, 31h
	.equ YEAR, 32h

	.equ MM_TENS, 33h
	.equ MM_ONES, 34h

	.equ DD_TENS, 35h
	.equ DD_ONES, 36h

	.equ YY_TENS, 37h
	.equ YY_ONES, 38h

	mov MONTH, #01h

	; Initialize date as 01-01-19
	mov MM_TENS, #00h
	mov MM_ONES, #01h

	mov DD_TENS, #00h
	mov DD_ONES, #01h

	mov YY_TENS, #01h
	mov YY_ONES, #09h

	; Initialize VFD with sample date
	mov GRID9, #0FFh
	mov GRID8, MM_TENS
	mov GRID7, MM_ONES
	mov GRID6, #0Ah
	mov GRID5, DD_TENS
	mov GRID4, DD_ONES
	mov GRID3, #0Ah
	mov GRID2, YY_TENS
	mov GRID1, YY_ONES


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
	setb EA 			; enable interrupts

	; Set interrupt priority
	; mov IP, #01h 		; Set external interrupt 0 as highest priority

	; External interrupt 0 initialization
	clr EX0				; disable external interrupt 0
	setb IT0			; set external interrupt 0 to be triggered by falling edge

	; External interrupt 1 initialization
	clr EX1				; disable external interrupt 1
	setb IT1			; set external interrupt 1 to be triggered by falling edge

	; Timer 2 interrupt initialization
	setb ET2			; enable timer 2 interrupt
	mov T2CON, #04h		; set timer 2 in auto reload
	mov RCAP2H, #0FFh	; set high byte of timer 2 reload
	mov RCAP2L, #00h	; set low byte of timer 2 reload 

	; Serial port initialization (mode 0 - synchronous serial communication)
	mov SCON, #00h 		; initialize the serial port in mode 0

	sjmp MAIN

MAIN:									; default/main state of the program

	jnb P1.2, cont14					; check if rotary encoder button is pressed
		mov R2, #0FFh					; load R2 for 255 counts
		mov R3, #0FFh					; load R3 for 255 counts
		loop3:							; rotary encoder button must be depressed for ~130ms before time/date can be changed (also acts as debounce)
			jnb P1.2, cont14			; check if rotary encoder button is still pressed
			djnz R3, loop3				; decrement count in R3
		mov R3, #0FFh					; reload R3 in case loop is needed again
		djnz R2, loop3					; count R3 down again until R2 counts down
		setb ENC.2						; set the rotary encoder button flag
		mov GRID9, #00Bh
		clr IE1							; clear any "built up" hardware interrupt flags for external interrupt 1
		clr IE0							; clear any "built up" hardware interrupt flags for external interrupt 0
		setb EX0						; enable external interrupt 0
		setb EX1						; enable external interrupt 1
		sjmp SET_DATE					; jump to SET_DATE
	cont14:

	sjmp MAIN

SET_DATE:										; set date state

	

	;mov ENC_VALUE, MONTH

	mov R0, #30h								; corresponds to memory address of MONTH

	; Set the month
	SET_MM:

		; Initalize the enconder registers
		; mov ENC_TENS, MM_TENS
		; mov ENC_ONES, MM_ONES

		mov MODULUS, #0Ch 						; move 12 into MONDULUS for months

		jb P1.2, set_mm_cont2					; check if rotary encoder is still pressed
			clr ENC.2							; if not, clear the encoder button flag
		set_mm_cont2:

		jb ENC.2, set_mm_cont3					; check to make sure ENC.2 (button) flag is cleared
			jnb P1.2, set_mm_cont3				; check if rotary encoder button is pressed
				mov R2, #28h					; load R2 for 40 counts
				mov R3, #0FFh					; load R3 for 255 counts
				set_mm_loop0:					; rotary encoder button must be depressed for ~20ms before time/date can be changed (also acts as debounce)
					jnb P1.2, set_mm_cont3		; check if rotary encoder button is still pressed
					djnz R3, set_mm_loop0		; decrement count in R3
				mov R3, #0FFh					; reload R3 in case loop is needed again
				djnz R2, set_mm_loop0			; count R3 down again until R2 counts down
				mov GRID9, #0FFh
				clr EX0							; disable external interrupt 0
				clr EX1							; disable external interrupt 1
				sjmp MAIN						; jump to MAIN
		set_mm_cont3:

		; Move the encoder register into the respective date registers
		; mov MM_TENS, ENC_TENS
		; mov MM_ONES, ENC_ONES

		; Operations to prevent MONTH register from going above 12
		; mov a, MONTH
		; mov b, MODULUS
		; div ab
		; mov MONTH, b
		; inc MONTH

		; Operations to dispay MONTH register in decimal format: MM
		mov a, MONTH
		mov b, #0Ah
		div ab
		mov MM_TENS, a
		mov MM_ONES, b

		; Display MM:
		mov GRID8, MM_TENS
		mov GRID7, MM_ONES

		sjmp SET_MM
		
	; Set the day
	SET_DD:								


	; Set the year
	SET_YY: 							; set the year


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
	cjne R1, #29h, vfd_cont13 			; check if a complete grid cycle has finished (GRID_INDX == #29h)
		lcall VFD_RESET					; reset the VFD cycle
	vfd_cont13:

	pop acc					; restore value of a to value before UPDATE_VFD was called
	pop 1					; restore value of R1 to value before UPDATE_VFD was called

ret

DELAY:
	;push R0 				; push R0 onto the stack to preserve its value
	mov R0, #0FFh			; load R0 for 255 counts
	loop0:
	djnz R0, loop0
	;pop	R0					; restore value of R0 to value before DELAY was called
ret

VFD_RESET:
	; This function resets the VFD registers after a complete cycle

	; Initalize grid index (start with grid 9)
	mov GRID_EN_1, #80h
	mov GRID_EN_2, #00h
	mov GRID_INDX, #20h 	; corresponds to memory location of GRID9
ret

ENC_A:
	jb ENC.0, enc_a_cont0
		setb ENC.1
		sjmp enc_a_cont1
	enc_a_cont0:
	clr ENC.0
	inc @R0
	enc_a_cont1:
ret

ENC_B:
	jb ENC.1, enc_b_cont0
		setb ENC.0
		sjmp enc_b_cont1
	enc_b_cont0:
	clr ENC.1
	dec @R0
	enc_b_cont1:
ret

end