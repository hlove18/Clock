; VFD
; HENRY LOVE
; 06/05/19
; This program uses timer 2 to update the vfd.

; ======Registers======
; R0 - used in delay fxn
; R1 - used in VFD ISR



; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52						; MEGA COMMAND GETS US MORE RAM #frickinheckers

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
	
	;mov RCAP2H, #0FFh	; set high byte of timer 2 reload
	;mov RCAP2L, #000h	; set low byte of timer 2 reload

	mov RCAP2H, #0FAh	; set high byte of timer 2 reload
	mov RCAP2L, #00h	; set low byte of timer 2 reload 

	; Serial port initialization (mode 0 - synchronous serial communication)
	mov SCON, #00h 		; initialize the serial port in mode 0

	; Turn off the alarm
	clr P1.1

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

	; push any used SFRs onto the stack to preserve their values
	push 1
	push acc

	; move the contents of the respective grid into VFD_NUM (the number to be displayed - @R1)
	mov R1, GRID_INDX 					; move GRID_INX into R1
	inc GRID_INDX						; increment the grid index (to access next grid memory location)


	; the first two bytes of serial data are independent of the numeral to be shown
	mov SBUF, GRID_EN_1 				; send the first byte down the serial line
	jnb TI, $ 							; wait for the entire byte to be sent
	clr TI 								; the transmit interrupt flag is set by hardware but must be cleared by software
	mov SBUF, GRID_EN_2					; send the second byte down the serial line
	jnb TI, $ 							; wait for the entire byte to be sent
	clr TI 								; the transmit interrupt flag is set by hardware but must be cleared by software

	; the third byte of serial data depends on the numeral to be shown
	
	; "0" numeral
	cjne @R1, #00h, update_vfd_cont1
		mov SBUF, #0FCh					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		ljmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont1:

	; "1" numeral
	cjne @R1, #01h, update_vfd_cont2
		mov SBUF, #060h					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		ljmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont2:

	; "2" numeral
	cjne @R1, #02h, update_vfd_cont3
		mov SBUF, #0DAh					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont3:

	; "3" numeral
	cjne @R1, #03h, update_vfd_cont4
		mov SBUF, #0F2h					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont4:

	; "4" numeral
	cjne @R1, #04h, update_vfd_cont5
		mov SBUF, #66h					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont5:

	; "5" numeral
	cjne @R1, #05h, update_vfd_cont6
		mov SBUF, #0B6h					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont6:

	; "6" numeral
	cjne @R1, #06h, update_vfd_cont7
		mov SBUF, #0BEh					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont7:

	; "7" numeral
	cjne @R1, #07h, update_vfd_cont8
		mov SBUF, #0E0h					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont8:

	; "8" numeral
	cjne @R1, #08h, update_vfd_cont9
		mov SBUF, #0FEh					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont9:

	; "9" numeral
	cjne @R1, #09h, update_vfd_cont10
		mov SBUF, #0E6h					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont10:

	; "-" numeral
	cjne @R1, #0Ah, update_vfd_cont11
		mov SBUF, #02h					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont11:

	; "*" numeral
	cjne @R1, #0Bh, update_vfd_cont12
		mov SBUF, #01h					; send the third byte down the serial line
		jnb TI, $ 						; wait for the entire byte to be sent
		clr TI 							; the transmit interrupt flag is set by hardware but must be cleared by software
		sjmp update_vfd_cont12			; go to end of "case statement"
	update_vfd_cont12:
	
	setb P3.5							; load the MAX6921
	clr P3.5							; latch the MAX6921

	; prepare for the next cycle
	mov a, GRID_EN_1					; move GRID_EN_1 into accumulator
	rlc a 								; rotate the accumlator left through carry (NOTE! the carry flag gets rotated into bit 0)
	mov GRID_EN_1, a 					; move the rotated result back into GRID_EN_1
	mov a, GRID_EN_2					; move GRID_EN_2 into the accumlator
	rlc a 								; rotate the acculator left through carry (NOTE! the carry flag gest rotated into bit 0)
	mov GRID_EN_2, a 					; move the rotated result back into GRID_EN_2
	clr c 								; clear the carry flag
	cjne R1, #29h, update_vfd_cont13 	; check if a complete grid cycle has finished (GRID_INDX == #29h)
		lcall VFD_RESET					; reset the VFD cycle
	update_vfd_cont13:

	; pop the original SFR values back into their place and restore their values
	pop acc
	pop 1

	ret



VFD_RESET:
	; This function resets the VFD registers after a complete cycle
	mov GRID_EN_1, #80h					; initialize grid enable byte 1
	mov GRID_EN_2, #00h 				; initialize grid enable byte 2
	mov GRID_INDX, #20h 				; initalize grid index (start with grid 9). This should reflect the memory location of GRID9.

	ret

end


