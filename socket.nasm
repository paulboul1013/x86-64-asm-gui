BITS 64 
CPU X64

section .text

%define AF_UNIX 1
%define SOCK_STREAM 1
%define SYSCALL_SOCKET 41
%define SYSCALL_EXIT 60

global _start:
_start:
    ; open a unix socket
    mov rax, SYSCALL_SOCKET
    mov rdi, AF_UNIX ;unix socket
    mov rsi, SOCK_STREAM  ; stream oriented
    mov rdx ,0 ; automatic protocol
    syscall

    mov rax, SYSCALL_EXIT
    mov rdi, 0
    syscall