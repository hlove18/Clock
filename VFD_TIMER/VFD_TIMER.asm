; VFD
; HENRY LOVE
; 06/05/19
; This program uses timer 2 to update the vfd.

; ======Registers======
; R0 - used in delay fxn
; R1 - used in VFD ISR

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


; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

; Timer 2 interrupt
.org 002Bh
VFD_ISR:
	clr TF2					; clear timer 2 interrupt flag
	lcall UPDATE_VFD
	reti

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

	; Intilize date with sample date: 03-11-16
	mov GRID9, #0Bh
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

	; Clear the carry flag
	clr c

	; Interrupt initialization
	setb EA 			; enable interrupts

	; Timer 2 interrupt initialization
	setb ET2			; enable timer 2 interrupt
	mov T2CON, #04h		; set timer 2 in auto reload
	mov RCAP2H, #0FFh	; set high byte of timer 2 reload
	mov RCAP2L, #000h	; set low byte of timer 2 reload 

	; Serial port initialization (mode 0 - synchronous serial communication)
	mov SCON, #00h 		; initialize the serial port in mode 0

	sjmp MAIN

MAIN:
	sjmp MAIN


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

	;push R1						; push R1 onto the stack to preserve its value
	;push a 						; push a onto the stack to preserve its value

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
	cjne @R1, #00h, cont0
		mov SBUF, #0FCh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont0:

	; "1" numeral
	cjne @R1, #01h, cont1
		mov SBUF, #060h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont1:

	; "2" numeral
	cjne @R1, #02h, cont2
		mov SBUF, #0DAh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont2:

	; "3" numeral
	cjne @R1, #03h, cont3
		mov SBUF, #0F2h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont3:

	; "4" numeral
	cjne @R1, #04h, cont4
		mov SBUF, #66h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont4:

	; "5" numeral
	cjne @R1, #05h, cont5
		mov SBUF, #0B6h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont5:

	; "6" numeral
	cjne @R1, #06h, cont6
		mov SBUF, #0BEh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont6:

	; "7" numeral
	cjne @R1, #07h, cont7
		mov SBUF, #0E0h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont7:

	; "8" numeral
	cjne @R1, #08h, cont8
		mov SBUF, #0FEh				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont8:

	; "9" numeral
	cjne @R1, #09h, cont9
		mov SBUF, #0E6h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont9:

	; "-" numeral
	cjne @R1, #0Ah, cont10
		mov SBUF, #02h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont10:

	; "*" numeral
	cjne @R1, #0Bh, cont11
		mov SBUF, #01h				; send the third byte down the serial line
		jnb TI, $ 					; wait for the entire byte to be sent
		clr TI 						; the transmit interrupt flag is set by hardware but must be cleared by software
	cont11:
	
	setb P3.5						; load the MAX6921
	;lcall DELAY						; wait
	clr P3.5						; latch the MAX6921

	; Now we prepare for the next cycle
	mov a, GRID_EN_1					; move GRID_EN_1 into accumulator
	rlc a 								; rotate the accumlator left through carry (NOTE! the carry flag gets rotated into bit 0)
	mov GRID_EN_1, a 					; move the rotated result back into GRID_EN_1
	mov a, GRID_EN_2					; move GRID_EN_2 into the accumlator
	rlc a 								; rotate the acculator left through carry (NOTE! the carry flag gest rotated into bit 0)
	mov GRID_EN_2, a 					; move the rotated result back into GRID_EN_2
	clr c 								; clear the carry flag
	cjne R1, #29h, cont12 				; check if a complete grid cycle has finished (GRID_INDX == #29h)
		lcall VFD_RESET					; reset the VFD cycle
	cont12:

	;pop a 					; restore value of a to value before UPDATE_VFD was called
	;pop R1					; restore value of R1 to value before UPDATE_VFD was called

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

end


