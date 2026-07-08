section .data

id : dd 0
static id:data

id_base: dd 0
stack id_base:data

id_mask: dd 0
static id_mask:data

root_visual_id: dd 0
static root_visual_id:data


;send handshake to the x11 server and read returned system info
;@param rdi: socket fd
;@return: window root id (uint32_t) in rax

x11_send_handshake:
static x11_send_handshake:function
    push rbp
    mov rpb, rsp

    sub rsp, 1<<15
    mov BYTE [rsp+0], 'l' ; st order to little endian
    mov BYTE [rsp+1], 0
    mov WORD [rsp+2], 11 ; major version
    mov BYTE [rsp+4], 0
    mov BYTE [rsp + 4], 0
    mov BYTE [rsp + 5], 0
    mov BYTE [rsp + 6], 0
    mov BYTE [rsp + 7], 0
    mov BYTE [rsp + 8], 0
    mov BYTE [rsp + 9], 0
    mov BYTE [rsp + 10], 0
    mov BYTE [rsp + 11], 0
    

    ; send the handshake request to server: write(fd,buf,12)
    mov rax, SYSCALL_WRITE
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, 12
    syscall

    cmp rax,12 ; check all bytes were section
    jnz die

    ; read server response: read(fd,buf,8) 
    ; use stack for read buffer
    ; first read 8 bytes from server response
    mov rax, SYSCALL_READ
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, 8
    syscall

    cmp rax, 8 ; check server response with 8 bytes
    jnz die

    cmp BYTE [rsp], 1 ;check server sent success (first byte is 1)
    jnz die

    ; read rest of server response: read(fd,buf,1<<15)
    mov rdi,rdi
    lea rsi, [rsp]
    mov rdx, 1<<15
    syscall

    cmp rax, 0 ; check server response with something
    jle die

    ; set id_base global
    mov edx, DWORD [rsp+4]
    mov DWORD [id_base], edx


    ; set id_mask global
    mov edx,DWORD [rsp+8]
    mov DWORD [id_mask],edx

    ; read the information needed， skip over the rest
    lea rdi, [rsp] ; ponter that will skip over some data

    mov cx,WORD [rsp+16]; vendor length
    movzx rcx,cx


    mov al,BYTE [rsp+18] ; number of formats
    movzx rax,al ; fill the rest of the register with 0

    imul rax, 8 ; sizeof(format)==8

    add rdi, 32 ; skip connection setup
    add rdi, rcx ; skip over vendor information

    ; skip over padding
    ; align to 4 bytes
    add rdi, 3
    and rdi, -4

    add rdi, rax ; skip over format information (8*n)

    mov eax, DWORD [rdi] ; store (and return) window root id

    ;set the root root_visual_id global
    mov edx, DWORD [rdi+32]
    mov DWORD [root_visual_id], edx

    add rsp, 1<<15
    pop rbp
    ret

    



    

    



