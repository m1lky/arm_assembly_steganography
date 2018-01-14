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
	mov r3, r0
	bl extract_message_length
	mov r4, r1
	mov r0, r3
	bl extract_key
	mov r5, r1 @ save key
	mov r0, r3
	mov r1, r4
	bl extract_message
	mov r0, r1
	mov r1, r5
	mov r2, r4
	bl caeser
	mov r1, r0
	mov r0, #1
	mov r2, r4
	bl write
	
	mov r7, #1
	swi #0
@ in: r0=image blob
@ out: r1= message length
extract_message_length:
	stmfd sp!, {fp, lr, r3, r4, r5}
	add	fp, sp, #8
	mov r1, #0 @ output number
	mov r2, #0
	mov r5, #2 @ for multiplication
	extract_ml_begin:
		ldrb r3, [r0, r2]
		and r3, #3 @ get only last 2 bits
		mul r4, r2, r5 @ compute proper weight
		lsl r3, r4 @ apply proper weight
		add r1, r3 @ add to total
		add r2, #1 @ increment iterator
		cmp r2, #16
		bne extract_ml_begin
	
	ldmfd  sp!, {fp, pc, r3, r4, r5}

@ in: r0=fileptr
@ out: r1= key
extract_key:
	stmfd sp!, {fp, lr, r3, r4, r5, r6}
	add	fp, sp, #8
	mov r1, #0 @ output number
	mov r2, #16 @ iterator for offset
	mov r6, #0 @ iterator for weight
	mov r5, #2 @ for multiplication
	extract_key_begin:
		ldrb r3, [r0, r2]
		and r3, #3 @ get only last 2 bits
		mul r4, r6, r5 @ compute proper weight
		lsl r3, r4 @ apply proper weight
		add r1, r3 @ add to total
		add r2, #1 @ increment iterator
		add r6, #1
		cmp r2, #20
		bne extract_key_begin
	
	ldmfd  sp!, {fp, pc, r3, r4, r5, r6}
@ in: r0=fileptr, r1=message length
@ out: r1= message
extract_message:
	stmfd sp!, {fp, lr, r3, r4, r5, r6, r7, r8, r9}
	add	fp, sp, #8
	mov r5, r0 @ juggle parameters for initial malloc call
	mov r7, r1 
	mov r0, r1
	bl malloc
	mov r8, r0
	mov r0, r5
	mov r2, #20 @ iterator for offset
	extract_message_begin:
		mov r6, #0 @ iterator for weight
		mov r1, #0 @ total
		extract_message_bit_begin:
			ldrb r3, [r0, r2]
			and r3, #3 @ get only last 2 bits
			lsl r3, r6 @ apply proper weight
			add r1, r3 @ add to total
			add r2, #1 @ increment iterator
			add r6, #2
			cmp r6, #8
			blt extract_message_bit_begin
		t0:
		strb r1, [r8,r7]
		sub r7, #1
		cmp r7, #0
		bne extract_message_begin
	mov r1, r8
	ldmfd  sp!, {fp, pc, r3, r4, r5, r6, r7, r8, r9}
@ in: r0=encrypted message, r1 = key, r2 = message length
@ out: r0= decrypted message
caeser:
	stmfd sp!, {fp, lr, r3, r4, r5, r6, r7}
	add	fp, sp, #8
	c_loop:
		sub r2, #1
		ldrb r4, [r0, r2] 
		subs r4, r1
		bgt c_done @ if it's negative, gotta add #127 to get the ascii
		c_neg:
			add r4, #127
		c_done:
			strb r4, [r0, r2]
		cmp r2, #0
		bne c_loop
	ldmfd  sp!, {fp, pc, r3, r4, r5, r6, r7}

@in:r0 = filename
@out: r0 = memory address, r1 = size, r2 = location of start of message
readimage:
	stmfd sp!, {r4,r5,r6, r7,lr}
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
	mov r0, r4
	bl ftell
	mov r7, r0
	ldr  r2, =width
	ldr  r2, [r2]
	ldr  r3, =height
	ldr  r3, [r3]
	mul  r6, r2, r3

	mov  r0, r6
	bl   malloc
	mov r5, r0
	mov  r1, #1
	mov  r2, r6
	mov  r3, r4
	bl   fread
	mov  r0, r4
	bl   fclose

	mov  r0, r5
	mov r1, r6
	
	mov r2, r7
	ldmfd sp!, {r4,r5,r6,r7,lr}
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
	.asciz "P5\n%d %d\n%d"
message_file:
	.space 80
image_file:
	.space 80
inputfilemode:
	.asciz "r"
buffer_flusher:
	.asciz "\n"
