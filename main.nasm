BITS 64; 64 bits
CPU X64; target the x86_64 family of CPUs

%define SYSCALL_EXIT 60



%define AF_UNIX 1
%define SOCK_STREAM 1

%define SYSCALL_READ 0
%define SYSCALL_WRITE 1
%define STDOUT 1
%define SYSCALL_SOCKET 41
%define SYSCALL_CONNECT 42

section .rodata

sun_path: db "/tmp/.X11-unix/X0" ,0
static sun_path:data

section .data

id : dd 0
static id:data

id_base: dd 0
static id_base:data

id_mask: dd 0
static id_mask:data

root_visual_id: dd 0
static root_visual_id:data

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
    
    sub rsp,112 ;store struct sockaddr_un on the stack
    
    mov WORD [rsp], AF_UNIX ; set sockaddr_un.sun_family to AF_UNIX

    lea rsi,sun_path
    mov r12, rdi ;save teh socket file descriptor 'rdi' in 'r12'
    lea rdi, [rsp+2] 
    cld ; move forward
    mov ecx,19 ; length is 19 with the null terminator
    rep movsb ; copy

    ;connect to the server: connect(2)
    mov rax,SYSCALL_CONNECT
    mov rdi,r12
    lea rsi, [rsp]
    %define SIZEOF_SOCKADDR_UN 2+108
    mov rdx, SIZEOF_SOCKADDR_UN
    syscall

    cmp rax,0
    jne die

    mov rax,rdi ; return socket fd

    add rsp,112

    pop rbp
    ret

die:
    mov rax,SYSCALL_EXIT
    mov rdi,1
    syscall

; 送handshake到x11 server和讀取系統返回資訊
; @參數 rdi: socket file descriptor
; @返回 window root id (uint32_t)在 rax
x11_send_handshake:
static x11_send_handshake:function
    push rbp
    mov rbp,rsp
    
    
    sub rsp,1<<15 ;32 KB for return response

    ;fill X11 connection request
    mov BYTE [rsp+0], 'l' ;set endianness to 'l' for x86-64 little-endian
    mov BYTE [rsp+1], 0 ; pad1
    mov WORD [rsp+2], 11 ; major version
    mov WORD [rsp+4], 0 ; minor version
    mov BYTE [rsp+6], 0 ; auth_proto_len
    mov BYTE [rsp+7], 0 
    mov BYTE [rsp+8], 0 ; auth_data_len
    mov BYTE [rsp+9], 0
    mov BYTE [rsp+10], 0 ; pad2
    mov BYTE [rsp+11], 0

    ; linux x86-64 syscall convention
    ; rax: syscall number
    ; rdi :arg1
    ; rsi :arg2
    ; rdx :arg3

    ; send the handshake to the server: write(2)
    ; ssize_t write(int fd, const void *buf,size_t count)
    mov rax,SYSCALL_WRITE
    mov rdi,rdi ;socket fd already in rdi
    lea rsi, [rsp] ; buf = rsp
    mov rdx,12 ; count =12
    syscall

    cmp rax,12 ; check 12 bytes were written
    jnz die ; if no write 12 bytes, exit

    ;read the server response: read(2)
    ; use stack for the read buffer
    ; The x11 server first replies with 8 bytes.
    ; Once these are read, it replies with a much bigger message.
    ;ssize_t read(int fd,void *buf,size_t count)
    mov rax,SYSCALL_READ
    mov rdi,rdi
    lea rsi, [rsp]
    mov rdx, 8
    syscall
    
    cmp rax,8 ;check that server replied with 8 bytes
    jnz die ; if no, exit

    cmp BYTE [rsp],1 ; check that server sent success (first byte is 1)
    jnz die


    ; Read the rest of the server response: read(2)
    ; use the stack for the read buffer
    mov rax,SYSCALL_READ
    mov rdi,rdi
    lea rsi,[rsp]
    mov rdx, 1<<15
    syscall

    cmp rax,0 ; check that the server replied with something
    jle die

    
    ; x11 client build window,pixmap,GC resource，need to produce resource id
    ; resource_id_base = *(uint32_t*) (rsp+4)
    mov edx,DWORD [rsp+4]
    ; save resource_id_base to id_base
    ; id_base = resource_id_base
    mov DWORD [id_base],edx


    ; set id_mask globally
    ; resource_id_mask = *(uint32_t*) (rsp+8)
    mov edx, DWORD [rsp+8]
    ; id_mask = resource_id_mask
    mov DWORD [id_mask], edx


    ; read the information needed，skip over the rest
    ; rdi not socket fd anymore
    ; rdi  = setup information body current parse position
    ; uint8_t *p = buf;
    ; Pointer that will skip over some data.
    lea  rdi, [rsp]
    
    ; cx = *(uint16_t*) (rsp+16)
    ; uint64_t vendor_len =*(uint16_t*) (buf+16)
    mov cx , WORD [rsp+16] ; Vendor length
    movzx rcx, cx

    ; rax = pixmap_formats_len * 8
    ;size_t format_bytes = pixmap_formats_len * 8
    mov al, BYTE [rsp+21] ; number of formats
    movzx rax, al ; fill the rest of the register with zeroes to avoid garbage values
    imul rax,8 ;sizeof(format) == 8

    ; p+=32
    add rdi, 32 ; skip the connect setup
    ; p+= vendor_len
    add rdi, rcx; skip over that vendor information

    ; alignment x11 protocol 4-byte boundary
    ; p = (p+3) & ~3
    ; -4 in the 2's complement is 11111111111111111111111111111100 clear to lowest 2 bits
    ; example: vender_len =18， 32+18 = 50， 50+3 = 53， 53 & ~3(same and -4) = 52
    add rdi,3
    and rdi,-4

    add rdi,rax ; skip pixmap formats list (n*8)

    ; X11 setup body
    ; fixed setup header, 32 bytes
    ; vendor string
    ; padding
    ; pixmap formats, n*8 bytes
    ; screen/root list

    ;read root window id
    ; eax = *(uint32_t*) rdi
    ; uint32_t root_window_id = *(uint32_t*) p
    mov eax, DWORD [rdi] ;store (and return) the window root id

    ; set the root_visual_id globally
    ; root_visual_id = *(uint32_t*)(p+32)
    mov edx, DWORD [rdi+32]
    mov DWORD [root_visual_id], edx

    ; free the stack buffer
    add rsp, 1<<15
    pop rbp ;recover caller's rbp
    ret ;root window id


; Increament the global id
; @return:new id
x11_next_id:
    push rbp
    mov rbp,rsp

    mov eax,DWORD [id] ; load global id

    mov edi,DWORD [id_base] ; load global id_base
    mov edx,DWORD [id_mask] ; load global id_mask

    ; return id_mask & (id) | id_base
    and eax, edx
    or eax ,edi

    add DWORD [id],1 ; Increament id

    pop rbp
    ret


;open the font on the server side
;@param rdi:socket fd
;@param esi:font id
x11_open_font:
static x11_open_font:function
    push rbp
    mov rbp,rsp

    $define OPEN_FONT_NAME_BYTE_COUNT 5 ; fixed font length is 5 bytes
    %define OPEN_FONT_PADDING ((4-(OPEN_FONT_NAME_BYTE_COUNT%4))) ;fixed alingment 4 bytes

    ; open font request packet size in u32
    ; 3 uint32_t = 12 bytes
    ; pass fixed font 
    ; name bytes = 5, padding =3
    ; OPEN_FONT_PACKET_U32_COUNT  = 5
    ; full request size = 4*5 = 20 bytes
    %define OPEN_FONT_PACKET_U32_COUNT (3+
    (OPEN_FONT_NAME_BYTE_COUNT+OPEN_FONT_PADDING)/4)
    
    ;0x2d = 45
    %define X11_OP_REQ_OPEN_FONT 0x2d

    sub rsp,6*8 ; for uint8_t packet[48]

    ; write request 4 bytes data
    mov DWORD [rsp+0*4], X11_OP_REQ_OPEN_FONT | 
    (OPEN_FONT_NAME_BYTE_COUNT << 16)

    mov DWORD [rsp+1*4], esi ; input font id
    mov DWORD [rsp+2*4], OPEN_FONT_NAME_BYTE_COUNT ; font name length
    mov BYTE [rsp+3*4+0], 'f'
    mov BYTE [rsp+3*4+1], 'i'
    mov BYTE [rsp+3*4+2], 'x'
    mov BYTE [rsp+3*4+3], 'e'
    mov BYTE [rsp+3*4+4], 'd'

    mov rax, SYSCALL_WRITE
    mov rdi, rdi
    lea rsi, [rsp]
    mov rdx, OPEN_FONT_PACKET_U32_COUNT * 4
    syscall

    cmp rax, OPEN_FONT_PACKET_U32_COUNT * 4
    jnz die

    add rsp, 6*8

    pop rbp
    ret

;create a x11 graphical context
;@param rdi: socket fd
;@param esi: graphical context id
;@param edx: window root id
;@param ecx: font id

x11_create_gc:
static x11_create_gc:function
    push rbp
    mov rbp,rsp

    sub rsp, 8*8

%define X11_OP_REQ_CREATE_GC 0x37
%define X11_FLAG_GC_BG 0x00000004
%define X11_FLAG_GC_FG 0x00000008
%define X11_FLAG_GC_FONT 0x00004000
%define X11_FLAG_GC_EXPOSE 0x00010000

%define CREATE_GC_FLAGS X11_FLAG_GC_BG | X11_FLAG_GC_FG | X11_FLAG_GC_FONT
%define CREATE_GC_PACKET_FLAG_COUNT 3
%define CREATE_GC_PACKET_U32_COUNT (4+
CREATE_GC_PACKET_FLAG_COUNT)
%define MY_COLOR_RGB 0x0000ffff

    mov DWORD [rsp+0*4] ,X11_OP_REQ_CREATE_GC | (CREATE_GC_PACKET_U32_COUNT<<16)
    mov DWORD [rsp+1*4], esi
    mov DWORD [rsp+2*4], edx
    mov DWORD [rsp+3*4], CREATE_GC_FLAGS
    mov DWORD [rsp+4*4], MY_COLOR_RGB
    mov DWORD [rsp+5*4], 0
    mov DWORD [rsp+6*4], ecx

    mov rax,SYSCALL_WRITE
    mov rdi,rdi
    lea rsi,[rsp]
    mov rdx,CREATE_GC_PACKET_U32_COUNT * 4
    syscall

    cmp rax, CREATE_GC_PACKET_U32_COUNT * 4
    jnz die

    add rsp, 8*8

    pop rbp
    ret


;create x11 window
;@param rdi: socket fd
;@param esi: new window id
;@param edx: root window id
;@param ecx: root visual id
;@param r8d: packed x and y
;@param r9d: packed w and h
x11_create_window:
static x11_create_window:function
    push rbp
    mov rbp,rsp

    %define X11_OP_REQ_CREATE_WINDOW 0x01
    %define X11_FLAG_WIN_BG_COLOR 0x00000002
    %define X11_EVENT_FLAG_KEY_RELEASE 0x0002
    %define X11_EVENT_FLAG_EXPOSURE 0x8000
    %define X11_FLAG_WIN_EVENT 0x00000800

    %define CREATE_WINDOW_FLAG_COUNT 2
    %define CREATE_WINDOW_PACKET_U32_COUNT (8 + CREATE_WINDOW_FLAG_COUNT)
    %define CREATE_WINDOW_BORDER 1
    %define CREATE_WINDOW_GROUP 1

    sub rsp, 12*8

    mov DWORD [rsp+0*4], X11_OP_REQ_CREATE_WINDOW |
    (CREATE_WINDOW_PACKET_U32_COUNT <<16)
    mov DWORD [rsp+1*4], esi ; new window id
    mov DWORD [rsp+2*4], edx ; root window id
    mov DWORD [rsp+3*4], r8d ; packed x and y
    mov DWORD [rsp+4*4], r9d ; packed w and h
    mov DWORD [rsp+5*4], CREATE_WINDOW_GROUP | (CREATE_WINDOW_BORDER << 16)
    mov DWORD [rsp+6*4], ecx ;root visual id
    mov DWORD [rsp+7*4], X11_FLAG_WIN_BG_COLOR | X11_FLAG_WIN_EVENT
    mov DWORD [rsp+8*4], 0
    mov DWORD [rsp+9*4], X11_EVENT_FLAG_KEY_RELEASE | X11_EVENT_FLAG_EXPOSURE
    
    mov rax,SYSCALL_WRITE
    mov rdi,rdi
    lea rsi,[rsp]
    mov rdx, CREATE_WINDOW_PACKET_U32_COUNT * 4
    syscall

    cmp rax, CREATE_WINDOW_PACKET_U32_COUNT * 4
    jnz die
    

    add rsp, 12*8
    
    pop rbp
    ret

section .text
global _start
_start:
    call x11_connect_to_server


    mov rax,SYSCALL_EXIT
    mov rdi,0
    syscall
    