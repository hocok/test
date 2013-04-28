; Set the kernel.pid_max (maximum accepted connections)


format elf executable 3
entry   _start

        segment readable writeable  executable


                connect            db    "The new client has been connected", 0x0D, 0x0A        ; First string...

                goodbye            db    "Goodbye... =[", 0                    ; Third string...
                error              db    "ERROR: socket() failed!", 10, 0    ; Fourth string...

                FILE1           db    "/home/andrew/HD-0.ts",0

                off_set         dd 0x00
                n_bytes     dd 0x00

                HTTP200                 db    "HTTP/1.1 200 OK",                        0xD,0xA                      ; 17
                CTYPE                   db    "Content-Type: application/octet-stream", 0xD,0xA
                CLENGTH                 db    "Content-Length: 33939967",                    0xD,0xA,0xD,0xA
                CNAME                   db    'Content-Disposition: attachment; filename="BIGTABLE"',0xD,0xA,0xD,0xA
                SERVER                  db    'Server: kerreine',0xD,0xA


                IPPROTO_TCP     equ     0x06
                SOCK_STREAM     equ     0x01
                PF_INET         equ     0x02
                AF_INET         equ     0x02


                ;KeepAlive db 'Connection: keep-alive',0xD,0xA
                KeepClose db 'Connection: close',0xD,0xA,0xD,0xA

                include 'str2hex.asm'

                sleep:
                dd 10
                dd 0

                buffer:
                db 2048 dup (0)


                checksum:
                db 'OURHASH'
                serv_start db 0xD,0xA,'Server started as daemon...',0xD,0xA

                fork_err db "error";

                socket_desc dd 0x00

                c_accept dd 0x00
                s_socket dd 0x00


                _start: 

                        ; become a daemon
                                mov eax,2
                                int 0x80

                                cmp eax,0
                                jl exit   ; if error

                                test eax,eax
                                jz daemon

                        jmp silent_exit

                daemon:
                ; write 'server daemon started'
                                mov eax, 4                ; write() syscall
                                mov ebx, 0              ; sockfd
                                mov ecx, serv_start    ; Connection: Close
                                mov edx, 31       ; 21 characters in length
                                int 0x80                  ; Call the kernel




; struct for socket
    push  IPPROTO_TCP        ; IPPROTO_TCP (=6)
    push  SOCK_STREAM        ; SOCK_STREAM (=1)
    push  PF_INET            ; PF_INET (=2)

;socketcall
    mov eax, 102        ;
    mov ebx, 1          ;
    mov ecx, esp        ; Pointer to the stack
    int 0x80            ; Call the kernel    
    
    mov edi, eax        ;
    mov [s_socket],eax

    cmp eax, -1
    je near errn         ; Check for errors

; Ignoring TIME_WAIT
;mov ebx, 14 ; SYS_SETSOCKOPT
;mov eax,102
;mov ecx,1 ; SOL_SOCKET
;mov edx,4 ; SO_REUSEADDR
;int 0x80
jmp next3
struc_buffer:
dw 1
dw 1
next3:
; OR LIKE:
 push 4
 push struc_buffer; sockoptvals
 push 2 ; REUSEADDR
 push 1 ; SOL_SOCKET
 push edi

 mov eax,102
 mov ebx,14
 mov ecx,esp
 int 0x80

;bind(fd, (struct sockaddr*) &sock, sizeof(sock));                

; struct sockaddr_in
    push dword 0x00;1001A8C0;0x0100007F  ; INADDR_ANY = 0x00000000
    push word 0x901F        ; port 8080; htons(1F90)
    push word AF_INET            ; AF_INET = 2


    mov ecx, esp        ; Save a pointer to the struct

;-------------
;bind() args
    push 16        ; socklen_t addrlen
    push ecx            ; const struct sockaddr *my_addr
    push edi            ; int sockfd
    
;bind!
    mov eax, 102        ; socketcall() syscall
    mov ebx, 2            ; bind() = int call 2
    mov ecx, esp        ; Pointer to the arguments on the stack                ;
    int 0x80            ; Call the kernel.;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
    

    cmp eax, 0
    jne near errn
    
;listen(fd, 1);               
;listen() args
    push 1        ; int backlog
    push edi            ; int sockfd
    pop esi
    push edi

;listen!
    mov eax, 102        ; socketcall() syscall (listen)
    mov ebx, 4            ; bind() = int call 4
    mov ecx, esp        ; Pointer to the arguments on the stack
    int 0x80            ; Call the kernel.
    
; Do a little error-checking here...
    cmp eax, 0
    jne near errn
    
;accept(fd, NULL, 0);                
; accept() args

    push 0x00            ; socklen_t *addrlen
    push 0x00            ; struct sockaddr *addr
    push edi            ; int sockfd


; SIGCHLD, SIG_IGN
; we dont want a millions of zombie
        mov eax,48
        mov ebx,17
        mov ecx,1    ; SIG_IGN
        int 0x80


;Accept
sock_accept:
    mov eax, 102        ; socketcall() syscall
    mov ebx, 5            ; accept() = int call 5
    mov ecx, esp        ; Pointer to the arguments on the stack
    int 0x80            ; Call the kernel;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
    
; Check for error
    cmp eax, -1
    je near errn


    mov edi, eax        ; <-- store teh return value from accept()
    mov [c_accept],eax
    
;

;write(1, "The new client has been connected", 35)
   ; mov eax, 4            ; write() syscall
   ; mov ebx, 1            ; stdout
   ; mov ecx, connect    ; our string
   ; mov edx, 35        ; 27 characters in length
   ; int 0x80            ; Call the kernel

; Ïîðîæäàåì äèòÿ :)
; pcntl_fork ()
mov eax,2
int 0x80

cmp eax,0
jl exit   ; if error

test eax,eax
jnz fork   ; Ïåðåõîäèì íà îòðàáîòêó çàïðîñà îò êëèåíòà
    ; edi - accept descriptor
    ; esp
    mov eax, 6          ; close() syscall
    mov ebx, edi        ; The socket descriptor
    int 0x80            ; Call the kernel

        mov eax,4
        mov ebx,1
        mov ecx,KeepClose
        mov edx,10
        int 0x80

jmp sock_accept       ; ðîäèòåëüñêèé ïðîöåññ âîçâðàùàåòñÿ îáðàòíî ê ïðèíÿòèþ îñòàëüíûõ êëèåíòîâ

;
fork:
; making leader
;mov eax,66
;int 0x80



; New client connected !
; Read 21 bytes (instead 'GET /' 16+5)
    mov eax,3
    mov ebx,edi
    mov ecx,buffer-5
    mov edx,21
    int 0x80

; Write header information

    mov eax, 4            ; write() syscall
    mov ebx, edi          ; sockfd
    mov ecx, HTTP200      ; Send 200 Ok
    mov edx, 17           ; 17 characters in length
    int 0x80              ; Call the kernel

    mov eax, 4            ; write() syscall
    mov ebx, edi          ; sockfd
    mov ecx, CTYPE        ; Content-type - 'application/octet-stream'
    mov edx, 40           ; 40 characters in length
    int 0x80              ; Call the kernel

;    mov eax, 4           ; write() syscall
;    mov ebx, edi         ; sockfd
;    mov ecx, CLENGTH     ; Content length
;    mov edx, 26          ; 26 characters in length
;    int 0x80             ; Call the kernel

    mov eax, 4            ; write() syscall
    mov ebx, edi          ; sockfd
    mov ecx, CNAME        ; File name (BIGTABLE as default)
    mov edx, 54           ; 54 characters in length
    int 0x80              ; Call the kernel

    mov eax, 4           ; write() syscall
    mov ebx, edi         ; sockfd
    mov ecx, SERVER   ; our string to send
    mov edx, 18          ; 16 characters in length
    int 0x80             ; Call the kernel

;

    mov eax, 4            ; write() syscall
    mov ebx, edi          ; sockfd
    mov ecx, KeepClose    ; Connection: Close
    mov edx, 21           ; 21 characters in length
    int 0x80              ; Call the kernel

;--------------------------------------------------------------------------------



; Read id from GET /F8B784-1FFFFFF HTTP/1.1
; read 16 bytes



        ;mov eax, 4            ; write() syscall
        ;mov ebx, 1            ; sockfd
        ;mov ecx, buffer        ; our string to send
        ;mov edx, 21        ; 16 characters in length
        ;int 0x80            ; Call the kernel

; esi - hex in str
; Read first 0-8 bytes from buffer, and convert it into 4 bytes value

mov esi,buffer

push edi                ; Save sock_fd
STR2HEX4                ; Function clear edi, so push it to the stack before
pop edi                 ; popup sock_in

mov [off_set],eax       ; That's result (offset from zero byte in BIGTABLE)

; Read next 8-16 bytes from url, and convert it to a 4 bytes value

mov esi,buffer+8

push edi
STR2HEX4
pop edi

mov [n_bytes],eax        ; Size in bytes


; Open BIGTABLE file
        mov eax,5
        mov ebx,FILE1
        mov ecx, 2
; mov edx,0xFF ; rights
        int 0x80


; Send [n_bytes] from BIGTABLE starting at [off_set]
send_file:


       mov ecx,eax         ; file descriptor from previous function
       mov eax,187
       mov ebx,edi         ; socket
       mov edx,off_set     ; pointer -> null
       mov esi,[n_bytes]   ;
       int 0x80


success:


; Read the header 

   mov eax,3
   mov ebx,edi
   mov ecx,buffer
   mov edx,1024
   int 0x80


; Close file ---

; Shutdown
   ; push edi
   ; push 0
   ; mov eax,102
   ; mov ebx,13
   ; mov ecx,esp
   ; int 0x80

; Cleaning...
;close(fd)
    mov eax, 6            ; close() syscall
    mov ebx, edi        ; The socket descriptor
    int 0x80            ; Call the kernel
; end to pcntl_fork ()
    mov eax,1
    xor ebx,ebx
    int 0x80


;------------------------

    
;exit(0)
exit:
errn:
mov eax, 4            ; write() syscall
    mov ebx, 1            ; stdout
    mov ecx, fork_err    ; our string
    mov edx, 5        ; 27 characters in length
    int 0x80            ; Call the kernel

silent_exit:
    mov eax, 1            ; exit() syscall
    mov ebx, 0            ; status = zero
    int 0x80            ; Call the kernel
    
; These are just to print an error message to stdout should
; one of our socketcall()s fail.

