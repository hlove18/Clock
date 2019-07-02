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
	lcall UPDATE_NIX
	reti

INIT:
	; Variables

	; ======VFD variables======

	; Grid 9 is on the left, grid 1 is on the right.  These hold the values each
	; grid will display
	.equ NIX4, 20h
	.equ NIX3, 21h
	.equ NIX2, 22h
	.equ NIX1, 23h

	; These registers keep track of which VFD grid should be on
	.equ NIX_EN, 24h

	; This variable is used to index through memory to access the correct numeral
	; to display on each repsective VFD grid
	.equ NIX_INDX, 25h

	; Intilize date with sample date: 03-11-16
	mov NIX4, #09h
	mov NIX3, #09h
	mov NIX2, #09h
	mov NIX1, #09h

	; Initalize the VFD
	lcall NIX_RESET

	; Clear the carry flag
	clr c

	; Interrupt initialization
	setb EA 			; enable interrupts

	; Timer 2 interrupt initialization
	setb ET2			; enable timer 2 interrupt
	mov T2CON, #04h		; set timer 2 in auto reload
	mov RCAP2H, #0F4h	; set high byte of timer 2 reload
	mov RCAP2L, #048h	; set low byte of timer 2 reload 

	; Serial port initialization (mode 0 - synchronous serial communication)
	; mov SCON, #00h 		; initialize the serial port in mode 0

	sjmp MAIN

MAIN:
	sjmp MAIN


UPDATE_NIX:
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
	mov R1, NIX_INDX 			; move GRID_INX into R1
	inc NIX_INDX				; increment the grid index (to access next grid memory location)

	mov a, NIX_EN
	orl a, @R1
	mov P2, #00h
	lcall DELAY
	mov P2, a

	; Now we prepare for the next cycle
	mov a, NIX_EN					; move GRID_EN_1 into accumulator
	rlc a 								; rotate the accumlator left through carry (NOTE! the carry flag gets rotated into bit 0)
	mov NIX_EN, a 					; move the rotated result back into GRID_EN_1					
	jnc cont12 						; check if a complete grid cycle has finished (GRID_INDX == #29h)
		clr c
		lcall NIX_RESET					; reset the VFD cycle
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

NIX_RESET:
	; This function resets the VFD registers after a complete cycle

	; Initalize grid index (start with grid 9)
	mov NIX_EN, #10h
	mov NIX_INDX, #20h 	; corresponds to memory location of GRID9

ret

end


