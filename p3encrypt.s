	.arch	armv8-a
	.cpu	cortex-a53 
	.fpu	neon-fp-armv8
	.global main
	.syntax unified
	.text
.equ SWI_OPEN, 0x66 @open a file 
.equ SWI_CLOSE,0x68 @close a file

main: 
	mov	r0,#1
	ldr	r1,=prompt 
	mov	r2,promptlen
	bl	write @ write out a prompt
	
read_input:
	ldr r0, =rformat
	ldr r1, =image_file
	bl	scanf
	ldr r0, =image_file
	bl readimage
	mov r4, r0 @ save memory address of image
	mov r8, r2 @ save image width
	mov r9, r3 @ save image height
	mul r5, r2, r3 @ save max length of message
	lsl r5, #2
	mov r0, #1
	ldr r1, =message_prompt
	mov r2, message_promptlen
	bl write
	ldr r0, =rformat
	ldr r1, =message_file
	bl	scanf @ read in 64 bytes
	ldr r0, =message_file
	ldr r1, =inputfilemode
	bl fopen
	mov r11, r0
	mov r1, #0
	mov r2, #2
	bl fseek
	mov r0, r11
	bl ftell
	mov r7, r0
	cmp r5, r7 @ if the length of the message is greater than the max length, error
	blt message_error
	mov r0, r11
	bl rewind
	sub r0, r7, #1
	bl malloc
	mov r6, r0
	mov r1, #1 @ size of 1 byte per entry
	mov r2, r7 @ number of entrys/file size
	mov r3, r11 @ file ptr
	bl fread @ read in the file's contents
	mov r0, r11
	bl fclose
	bl keygen
	mov r10, r1 @ save key
	mov r2, r7
	mov r0, r6
	bl caeser
	mov r11, r0 @ save ciphertext
	mov r0, r6
	bl free
	mov r0, r11 @ ciphertext
	mov r1, r4 @ image blob pointer
	mov r2, r7 @ message length
	mov r3, r10 @ key
	bl encode
	mov r1, r8 @ width
	mov r2, r9 @ height
	bl printstego
	mov r7, #1
	swi #0
@ input r0 = encrypted file string, r1 = width, r2 = height
printstego:
	stmfd sp!, {fp, lr, r3, r4, r5, r6, r7}
	add	fp, sp, #8
	mov r7, r1 @save dimensions
	mov r4, r2
	mov r5, r0
	ldr r0, =outputfile
	ldr r1, =outputfilemode
	bl fopen
	mov r6, r0 @ save file pointer
	ldr r2, =outputfileheader
	ldr r1, =outputformat
	bl fprintf
	mov r0, r6
	ldr r1, =outputfiledimensions
	mov r2, r7 
	mov r3, r4
	bl fprintf
	mov r0, r6
	ldr r1, =outputfilescale
	mov r2, #255
	bl fprintf
	mov r0, r5
	mov r1, #1
	mul r2, r7, r4
	mov r3, r6
	bl fwrite
	mov r0, r6
	bl fclose
	ldmfd  sp!, {fp, pc, r3, r4, r5, r6, r7}
@ in:r0 = ciphertext, r1 = image, r2 = message length, r3 = key
@ out: r0 = image with embedded ciphertext, r1 = last stored byte
encode:
	stmfd sp!, {fp, lr, r3, r4, r5, r6, r7, r8, r9}
	mov r8, r3
	mov r6, r0
	mov r7, r1
	mov r9, r2
	e_begin:
		mov r4, #0
		mov r3, #0 @ counter for message length
	e_msg_length:
		cmp r3, #16
		beq e_key
		and r7, r2, #3 @ check current bits of message length
		lsr r2, #2 @ shift to next portion of message length
		ldrb r5, [r1, r4] @ load appropriate byte of image
		and r5, r5, #252 @ AND to set last 2 bits of byte to 0
		add r5, r7 @ add 2 bits from message
		strb r5, [r1, r4]
		add r3, #1 @increment message counter
		add r4, #1 @ increment pointer to where we are in the file
		b e_msg_length
	e_key:
		mov r3, #0
	e_key_loop:
		cmp r3, #4
		beq e_msg
		and r7, r8, #3 @ grab 2 bits from key
		lsr r8, #2 @ shift to get next 2 bits next loop
		ldrb r5, [r1, r4]
		and r5, r5, #252 @ set last 2 bits to 0 of this byte
		add r5, r7 @ add bits from key
		strb r5, [r1, r4]
		add r4, #1
		add r3, #1
		b e_key_loop
	e_msg:
		sub r9, #1
		
		ldrb r2, [r0, r9]
		mov r3, #0
		e_msg_bit:
			and r7, r2, #3 @ grab 2 bits from msg
			lsr r2, #2 @ shift to get next 2 bits next loop
			ldrb r5, [r1, r4]
			and r5, r5, #252 @ set last 2 bits to 0 of this byte
			add r5, r7 @ add bits from msg
			strb r5, [r1, r4]
			add r4, #1
			

			cmp r9, #0
			beq e_done
			add r3, #1
			cmp r3, #4
			beq e_msg
		b e_msg_bit
	e_done:
		mov r0, r1
		mov r1, r4
		ldmfd  sp!, {fp, pc, r3, r4, r5, r6, r7, r8, r9}

@generate a key between 1 and 127 in r1
keygen:
	stmfd sp!, {fp, lr}
	add	fp, sp, #8
	
	bl rand @ get random number
	and r1, r0, #127 @ make it between 0 and 127
	ldmfd  sp!, {fp, pc}
@ in: r0=message, r1 = key, r2 = message length
@ out: r0= encrypted message
caeser:
	stmfd sp!, {fp, lr, r3, r4, r5, r6, r7}
	add	fp, sp, #8
	mov r5, r0 @ save the parameters
	mov r6, r1
	mov r7, r2
	sub r0, r2, #1 @ allocate message length amount of space, excluding null terminator
	bl malloc
	mov r4, r0 @ move allocated space to r4
	mov r0, r5 @ restore parameters
	mov r2, r7
	mov r1, r6
	sub r2, #1
	mov r6, #0
	strb r6, [r4, r2]
	c_loop:
		sub r2, #1 @ subtract 1 from message length
		ldrb r3, [r0, r2] 
		add r3, r1, r3 @ add key to value
		cmp r3, #127
		ble c_done_char
		c_g:
			sub r3, #127
		c_done_char:
			strb r3, [r4, r2]
		cmp r2, #0
		beq c_done_string
		b c_loop
	c_done_string:
		mov r0, r4
		ldmfd  sp!, {fp, pc, r3, r4, r5, r6, r7}

@in:r0 = filename
@out: r0 = memory address, r1 = max size, r2 = width, r3 = height
readimage:
	stmfd sp!, {r4,r5,r6,lr}
	add	fp, sp, #8
	ldr  r1, =rmode
	bl   fopen
	mov  r4, r0
	ldr  r1, =infmt1
	ldr  r2, =code
	bl   fscanf
	mov  r0, r4
	ldr  r1, =infmt2
	ldr  r2, =width
	ldr  r3, =height
	bl   fscanf
	mov  r0, r4
	ldr  r1, =infmt3
	ldr  r2, =maxval
	bl   fscanf

	ldr  r2, =width
	ldr  r2, [r2]
	ldr  r3, =height
	ldr  r3, [r3]
	mul  r6, r2, r3

	mov  r0, r6
	bl   malloc

	mov  r5, r0
	mov  r1, #1
	mov  r2, r6
	mov  r3, r4
	bl   fread

	mov  r0, r4
	bl   fclose

	mov  r0, r5
	mov r1, r6
	ldr r2, =width
	ldr r2, [r2]
	ldr r3, =height
	ldr r3, [r3]
	ldmfd sp!, {r4,r5,r6,lr}
	mov  pc, lr

@TODO:handle error
file_error:
	mov r7, #0
	swi 0
message_error:
	mov r7, #0
	swi 0

.data
prompt:
	.asciz "Enter a file name for the image.\n"
	.equ	promptlen, (.-prompt)
message_prompt:
	.asciz "Enter a file name for the message.\n"
	.equ	message_promptlen, (.-message_prompt)
testfile:
	.asciz "obama.pgm"
rmode:
	.asciz "rb"
rformat:
	.asciz "%s"
testoutput:
	.asciz "%s\n"
infmt1:
	.asciz  "%s"
infmt2:
	.asciz	"%i %i"
infmt3:
	.asciz	"%i"
code:
	.space 3
	.align 2
width:
	.word 0
height: 
	.word 0
maxval:
	.word 0
outputfile:
	.asciz "stego.pgm"
outputfilemode:
	.asciz "w"
outputformat:
	.asciz "%s"
outputfileheader:
	.asciz "P5\n"
outputfiledimensions:
	.asciz "%d %d"
outputfilescale:
	.asciz "\n%d"
message_file:
	.space 80
image_file:
	.space 80
inputfilemode:
	.asciz "r"
