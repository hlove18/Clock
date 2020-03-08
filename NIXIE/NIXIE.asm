; VFD
; HENRY LOVE
; 06/05/19
; This program uses timer 2 to update the Nixies.

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

	; Intialize
	mov NIX4, #04h
	mov NIX3, #03h
	mov NIX2, #02h
	mov NIX1, #01h

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

	; Turn on the NIXIE Colon:
	setb P1.4
	; Turn off the alarm
	clr P1.1

	sjmp MAIN

MAIN:
	sjmp MAIN


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


