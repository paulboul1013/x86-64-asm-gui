

section .rodata

sun_path : db "/tmp/.X11-unix/X0", 0
static sun_path:data

conect_to_x11_server:
static x11_connect_to_server:function
    push rbp
    mov rbp, rsp
    

    ; open a unix socket
    mov rax, SYSCALL_SOCKET
    mov rdi, AF_UNIX ; Unix socket.
    mov rsi, SOCK_STREAM ; Stream oriented.
    mov rdx, 0 ; Automatic protocol.
    syscall

    cmp rax,0
    js die

    mov rdi, rax ; store socket fd to rdi

    sub rsp, 112; for store struct  sockaddr_un on the stack

    mov WORD [rsp], AF_UNIX
    lea rsi, sun_path
    mov r12, rdi ; save socket fd to r12
    lea rdi ,[rsp+2]
    cld 
    mov ecx, 19 ; length of sun_path
    rep movsb ; copy sun_path to stack
    
    
    ; connect to the server
    mov rax, SYSCALL_CONNECT
    mov rdi, r12 ; socket fd
    lea rsi, [rsp]
    %define SIZEOF_SOCKADDR_UN 2+108
    mov rdx, SIZEOF_SOCKADDR_UN
    syscall

    cmp rax,0
    jne die

    mov rax, rdi ; return socket fd

    add rsp, 112
    pop rbp
    ret

die:
    mov rax, SYSCALL_EXIT
    mov rdi, 1
    syscall