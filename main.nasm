BITS 64; 64 bits
CPU X64; target the x86_64 family of CPUs

%define SYSCALL_EXIT 60

%define SYSCALL_WRITE 1
%define STDOUT 1

%define AF_UNIX 1
%define SOCK_STREAM 1

%define SYSCALL_SOCKET 41

print_world:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov BYTE [rsp+0], ' '
    mov BYTE [rsp + 1], 'w'
    mov BYTE [rsp + 2], 'o'
    mov BYTE [rsp + 3], 'r'
    mov BYTE [rsp + 4], 'l'
    mov BYTE [rsp + 5], 'd' 

    mov rax,SYSCALL_WRITE
    mov rdi,STDOUT
    lea rsi, [rsp]
    mov rdx, 6
    syscall

    add rsp,16
    
    pop rbp
    ret


print_hello:
    push rbp
    mov rbp,rsp

    sub rsp,16
    mov BYTE [rsp+0],'h'
    mov BYTE [rsp+1],'e'
    mov BYTE [rsp+2],'l'
    mov BYTE [rsp+3],'l'
    mov BYTE [rsp+4],'o'

    mov rax,SYSCALL_WRITE
    mov rdi,STDOUT
    lea rsi,[rsp]
    mov rdx,5
    syscall

    call print_world

    add rsp,16

    pop rbp
    ret

    
; Create a UNIX domain socket and connect to the X11 server.
; @returns The socket file descriptor.
x11_connect_to_server:
static x11_connect_to_server:function
    push rbp
    mov rbp,rsp

    ; open a unix socket
    mov rax,SYSCALL_SOCKET
    mov rdi, AF_UNIX
    mov rsi,SOCK_STREAM
    mov rdx,0 
    syscall

    cmp rax,0
    js die

    mov rdi,rax ; store socket fd in `rdi` for the remainder of the function.
    
    pop rbp
    ret

die:
    mov rax,SYSCALL_EXIT
    mov rdi,1
    syscall

section .text
global _start
_start:
    call x11_connect_to_server


    mov rax,SYSCALL_EXIT
    mov rdi,0
    syscall
    