;CYCLE ONE NIXIE - HENRY LOVE - 06/02/19
;This little program cycles a nixie tube 0-9.

main:
	mov P2, #00h			; 0
	lcall delay				; delay 
	lcall delay				; delay
	
	mov P2, #001h			; 1
	lcall delay				; delay
	lcall delay				; delay

	mov P2, #002h			; 2
	lcall delay				; delay
	lcall delay				; delay

	mov P2, #003h			; 3
	lcall delay				; delay
	lcall delay				; delay

	mov P2, #004h			; 4
	lcall delay				; delay
	lcall delay				; delay

	mov P2, #005h			; 5
	lcall delay				; delay
	lcall delay				; delay

	mov P2, #006h			; 6
	lcall delay				; delay
	lcall delay				; delay

	mov P2, #007h			; 7
	lcall delay				; delay
	lcall delay				; delay

	mov P2, #008h			; 8
	lcall delay				; delay
	lcall delay				; delay

	mov P2, #009h			; 9
	lcall delay				; delay
	lcall delay				; delay

sjmp main					; repeat


delay:
	mov R0, #0FFh			; load R0 for 255 counts
	mov R1, #0FFh			; load R1 for 255 counts		

	loop1:
		djnz R1, loop1		; decrement count in R1
	mov R1, #0FFh			; reload R1 in case loop is needed again
	
	djnz R0, loop1			; count R1 down again until R0 counts down
ret

end