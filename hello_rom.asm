cpu 8086
org 0

%macro DisplayString 1
	[section .data]
	
	%%str: db %1, 0

	__SECT__

	push si
	mov si, %%str
	call display_string
	pop si
%endmacro

section .data
noise:
	incbin "noise.bin" 

section .text

	db 0x55, 0xaa ; BIOS marker
	db 0 ; BIOS size / 512 bytes

	mov ax, cs
	mov ds, ax

	call cls
	DisplayString `RAM test\r\n\r\n`

next_test:
	int 0x12 ; get memory size in KB in AX 
	mov cl, 4
	shr ax, cl
	mov bx, ax ; number of 16K blocks in BX

	mov ax, 1 ; don't test first 16K	

	mov cx, 2 ; stride in CX

next_block:
	DisplayString `Testing range `
	call display_current_block_address
	push ax
	add ax, cx
	DisplayString `-`
	call display_current_block_address
	pop ax

	sub dx, dx

	push ax
	push cx
stride_fill_region:
	call setup_block_address
	call fill_region
	inc ax
	loop stride_fill_region
	pop cx
	pop ax

	push ax
	push cx
stride_check_region:
	call setup_block_address
	call check_region
	inc ax
	loop stride_check_region
	pop cx
	pop ax

	push ax
	push cx
stride_invert_region:
	call setup_block_address
	call invert_region
	inc ax
	loop stride_invert_region
	pop cx
	pop ax

	push cx
stride_check_inverted_region:
	call setup_block_address
	call check_inverted_region
	inc ax
	loop stride_check_inverted_region
	pop cx

	cmp dx, 0
	jne report_block_error
	DisplayString ` OK\r\n`

next_block_1:
	cmp bx, ax
	jg next_block
	jmp next_test

report_block_error:
	DisplayString ` FAIL\r\n`
	jmp next_block_1

display_current_block_address:
	push ax
	push cx
	mov cl, 10
	shl ax, cl
	call display_word
	mov al, '0'
	call display_char
	pop cx
	pop ax
	ret

	; Set ES to point to block number in AX
setup_block_address:
	push cx
	push ax
	mov cl, 10
	shl ax, cl
	mov es, ax
	pop ax
	pop cx
	ret

	; Fill 16K region at [ES:00] with noise
fill_region:
	pushf
	push ax
	push bx
	push cx
	push si	
	push di
	cld

	mov bx, es
	mov cl, 10
	shr bx, cl
	mov bl, [noise + bx] ; mixer in BL

	mov cx, 0x4000
	mov si, noise
	sub di, di
	rep movsb

	mov cx, 0x4000
	sub di, di
.next_byte:
	mov al, [es:di]
	xor al, bl ; mix
	mov [es:di], al

	inc di
	loop .next_byte

	pop di
	pop si
	pop cx
	pop bx
	pop ax
	popf
	ret

	; Invert 16K region at [ES:00]
invert_region:
	pushf
	push ax
	push cx
	push di

	mov cx, 0x4000
	sub di, di
.next_byte:
	mov al, [es:di]
	not al ; invert
	mov [es:di], al

	inc di
	loop .next_byte

	pop di
	pop cx
	pop ax
	popf
	ret

	; Check 16K region at [ES:00] with noise
check_region:
	pushf
	push ax
	push bx
	push cx
	push si	
	push di

	mov bx, es
	mov cl, 10
	shr bx, cl
	mov bl, [noise + bx] ; mixer in BL

	mov cx, 0x4000
	mov si, noise
	sub di, di
.next_byte:
	mov al, [es:di]
	mov ah, [si]
	xor ah, bl ; mix

	cmp al, ah
	je .ok

	inc dx

.ok:
	inc si
	inc di
	loop .next_byte

	pop di
	pop si
	pop cx
	pop bx
	pop ax
	popf
	ret

	; Check 16K region at [ES:00] with inverted noise
	; Return: number of errors in DX
check_inverted_region:
	pushf
	push ax
	push bx
	push cx
	push si	
	push di

	mov bx, es
	mov cl, 10
	shr bx, cl
	mov bl, [noise + bx] ; mixer in BL

	mov cx, 0x4000
	mov si, noise
	sub di, di
.next_byte:
	mov al, [es:di]
	mov ah, [si]
	xor ah, bl ; mix
	not ah ; invert

	cmp al, ah
	je .ok

	inc dx

.ok:
	inc si
	inc di
	loop .next_byte

	pop di
	pop si
	pop cx
	pop bx
	pop ax
	popf
	ret

	; Display 256 bytes
	; Address in [ES:DI]
display_memory_block:
	push ax
	push cx
	push dx
	mov cx, 0x10
.next_line:
	push es
	push di
	pop ax
	pop dx
	add ah, dl
	adc dh, 0
	mov dl, dh
	sub dh, dh
	call display_dword
	mov al, ' '
	call display_char
	call display_memory_line
	mov al, 0x0d
	call display_char
	mov al, 0x0a
	call display_char
	loop .next_line
	pop dx
	pop cx
	pop ax
	ret

	; Display 16 bytes and advance DI
	; Address in [ES:DI]
display_memory_line:
	push ax
	push cx
	sub ax, ax
	mov cx, 0x10
.next_byte:	
	mov al, [es:di]
	call display_byte
	mov al, ' '
	call display_char
	inc di
	loop .next_byte
	pop cx
	pop ax
	ret

	; Double word in AX
display_word:
	push ax
	mov al, ah
	call display_byte
	pop ax
	call display_byte	
	ret

	; Double word in DX:AX
display_dword:
	push dx
	push ax
	mov al, dh
	call display_byte
	mov al, dl
	call display_byte
	mov al, ah
	call display_byte
	pop ax
	call display_byte	
	pop dx
	ret

	; Byte in AL
display_byte:
	push cx
	push ax
	mov cl, 4
	shr al, cl
	call display_nibble
	pop ax
	push ax
	and al, 0x0f
	call display_nibble
	pop ax
	pop cx
	ret

	; 4 LSB in AL
display_nibble:
	push ax
	and al, 0x0f
	cmp al, 0x09
	jle .is_digit
	add al, 0x07
.is_digit:
	add al, 0x30
	call display_char
	pop ax
	ret

	; String address in DS:SI
display_string:
	push ax
	push bx
	mov bx, si
	
.next_char:
	mov al,[bx]
	cmp al,0
	jz .done
	call display_char
	inc bx
	jmp .next_char

.done:
	pop bx
	pop ax
	ret

	; Char in AL
display_char:
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	mov ah, 0x0e
	mov bx,0x000f
	int 0x10
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	ret

	; Char in AL
read_char:
	push bx
	push cx
	push dx
	push si
	push di
	mov ah, 0x00
	int 0x16
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret

cls:
	push ax
	mov ah, 0
	mov al, 3
	int 10h
	pop ax
	ret
