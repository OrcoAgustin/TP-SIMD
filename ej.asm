; Hace que los accesos a memoria por defecto se compilen como [rip + offset]
; en lugar de [offset_desde_el_0x0].
;
; Ver https://www.nasm.us/doc/nasmdoc7.html#section-7.2.1 para más información
DEFAULT REL

TRUE  EQU 1
FALSE EQU 0

SINCOS_SIN_OFF EQU 0
SINCOS_COS_OFF EQU 4
SINCOS_SZ      EQU 8

section .rodata

global ej_1_hecho
global ej_2_hecho
global ej_3_hecho
global ej_4_hecho
ej_1_hecho: db TRUE
ej_2_hecho: db TRUE
ej_3_hecho: db TRUE
ej_4_hecho: db TRUE

ALIGN 16
espacios:
	times 10 db ' ' - '0'
	times 6  db 0x0
ceros:
	times 10 db '0'
	times 6  db 0x0
mask_10:
	times 10 db 0xFF
	times 6  db 0x00
mult_10:
	db 10, 1, 10, 1, 10, 1, 10, 1, 10, 1, 0, 0, 0, 0, 0, 0
mult_100:
	dw 100, 1, 100, 1, 1, 0, 0, 0
const_dos: dd 2.0

section .text

global ej1_sample
; void ej1_sample(size_t buf_len, int16_t buf[buf_len],
;                 size_t freq_a_len, int16_t freq_a[freq_a_len], size_t a_start,
;                 size_t freq_b_len, int16_t freq_b[freq_b_len], size_t b_start);
;
; buf_len:    Está en rdi
; buf:        Está en rsi
; freq_a_len: Está en rdx
; freq_a:     Está en rcx
; a_start:    Está en r8
; freq_b_len: Está en r9
; freq_b:     Está en rsp+8
; b_start:    Está en rsp+16
;
; Tener en mente que:
; - buf_len, freq_a_len, freq_b_len, a_start y b_start son siempre múltiplos de 16
; - a_start < freq_a_len y b_start < freq_b_len
; - freq_a y freq_b están dados tal que sumarlos entre sí no causa overflow

ej1_sample:
    push rbp
    mov rbp, rsp
    push rbx
    push r12 
    push r13
    push r14
    push r15

    ;Recuperar de pila
    mov r10, [rbp + 16] ; freq_b
    mov r11, [rbp + 24] ; b_start

    ; Guardar datos 
    mov r13, rdx ; r13 = freq_a_len
    mov r14, r9 ; r14 = freq_b_len

    xor r12, r12 ; contador / i del buffer

.loop:
    cmp r12, rdi
    jge .end

    ; Calcular índice A: rax = (i + a_start) % freq_a_len
    ;ES CIRCULAR
    mov rax, r12
    add rax, r8 ; rax = i + a_start
    xor rdx, rdx ; Limpiar rdx para la división de 128-bit (rdx:rax)
    div r13
    mov rbx, rdx ; rbx = índice final para freq_a

    
    ; Calcular índice B    
    mov rax, r12
    add rax, r11 ; rax = i + b_start
    xor rdx, rdx ; Limpiar rdx
    div r14 
    ; rdx ya tiene el índice final para freq_b

    
    ; Carga 8 elementos de int16_t 
    lea rax, [rcx + rbx * 2]
    movdqu xmm0, [rax] ; Carga 8 valores de freq_a en xmm0

    lea rax, [r10 + rdx * 2]
    movdqu xmm1, [rax] ; Carga 8 valores de freq_b en xmm1

    
    ; Operaciones SIMD
    paddsw xmm0, xmm1 ; Suma con signo de 16 bits en paralelo (8 elementos)
    psraw  xmm0, 1 ; Dividir por 2 (sh rig)

    
    ;Guardar resultado en el buffer de salida
    lea rax, [rsi + r12 * 2]
    movdqu [rax], xmm0

    ; Avanzar de a 8 elementos
    add r12, 8
    jmp .loop

.end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

global ej2_detect
; float ej2_detect(size_t size, int16_t signal[size], sincos_t freq[size]);
;
; size:   Está en rdi
; signal: Está en rsi
; freq:   Está en rdx
ej2_detect:
push rbp
mov rbp, rsp
push r12 ;contador
push r13
push r14
push r15
push rbx

xorps xmm0, xmm0 ;contador real
xorps xmm1, xmm1 ;contador imaginario

xor r12, r12

mov rcx, rdi
shr rcx, 2          
jz .loopCasoBorde

.loop:
    ;cargamos de a 4 int16_t de senal y convertir a float en xmm2
    movq xmm2, [rsi + r12 * 2]
    pmovsxwd xmm2, xmm2
    cvtdq2ps xmm2, xmm2   ; xmm2 = [s3, s2, s1, s0]

    ;Cargamos 4 estructuras sen y cos de freq
    lea rax, [rdx + r12 * 8]
    movups xmm3, [rax]        ; [sin0, cos0, sin1, cos1]
    movups xmm4, [rax + 16]   ; [sin2, cos2, sin3, cos3]

    ;Separamos senos y cosenos en registros independientes
    movaps xmm5, xmm3
    movaps xmm6, xmm3
    shufps xmm5, xmm4, 0x88   ; xmm5 = [sin3, sin2, sin1, sin0]
    shufps xmm6, xmm4, 0xDD   ; xmm6 = [cos3, cos2, cos1, cos0]

    ;Multiplicación vectorial
    movaps xmm7, xmm2
    mulps xmm7, xmm6          ; signal * cos
    addps xmm0, xmm7          ; Acumula en Re

    movaps xmm7, xmm2
    mulps xmm7, xmm5          ; signal * sin
    addps xmm1, xmm7          ; Acumula en Im

    add r12, 4                ; Avanzamos de 4 en 4
    dec rcx
    jnz .loop

.loopCasoBorde:
    cmp r12, rdi
    jge .postLoop

    ;Bucle para procesar los elementos restantes
    movsx r11, word [rsi + r12 * 2]
    cvtsi2ss xmm2, r11

    mov rax, r12
    shl rax, 3
    add rax, rdx

    movss xmm3, [rax + 4]; cos
    mulss xmm3, xmm2
    addss xmm0, xmm3

    movss xmm4, [rax]; sin
    mulss xmm4, xmm2
    addss xmm1, xmm4

    inc r12
    jmp .loopCasoBorde

.postLoop:
    ; Reducción horizontal de los acumuladores vectoriales xmm0 y xmm1
    movhlps xmm2, xmm0
    addps xmm0, xmm2
    movshdup xmm2, xmm0
    addss xmm0, xmm2

    movhlps xmm2, xmm1
    addps xmm1, xmm2
    movshdup xmm2, xmm1
    addss xmm1, xmm2

	;ahora la formula 
	mulss xmm0, xmm0 ; xmm0 = Re^2
    mulss xmm1, xmm1 ; xmm1 = Im^2
    addss xmm0, xmm1 ; xmm0 = Re^2 + Im^2

	sqrtss xmm0, xmm0
	xorps xmm5, xmm5
	movss xmm5, [rel const_dos]
	mulss xmm0, xmm5	

	cvtsi2ss xmm2, rdi               
    divss xmm0, xmm2

.end:
	pop rbx
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbp
	ret

global ej3_remove_duplicates
; void ej3_remove_duplicates(size_t size, char detected[size], char output[]);
;
; size:   Está en rdi
; signal: Está en rsi
; output: Está en rdx
ej3_remove_duplicates:
    push rbp
    mov rbp, rsp
    push r12 
    push r13
    push r14
    push r15
    push rbx

    xor r12, r12 ; r12 = índice de lectura (avanza de 16 en 16)
    xor r15, r15 ; r15 = índice de escritura en output (arranca en 0)

    mov r14b, ' ' ; r14b = señal de referencia (arranca en espacio)

.loop:
    cmp r12, rdi
    jge .end
    
    ; Cargar 16 bytes y guardar el primer byte en r13b
    movdqu xmm0, [rsi + r12]
    movd eax, xmm0 ; EAX tiene los primeros 4 bytes, AL tiene el 1ro
    mov r13b, al ; Guardamos de forma segura el carácter del bloque

    pxor xmm1, xmm1
    movd xmm1, eax

    pxor xmm1, xmm1 ; xmm1 en ceros (selecciona siempre el byte 0)
    movaps xmm2, xmm0 ; Copiamos el bloque cargado
    pshufb xmm2, xmm1 ;Duplica el primer byte en todo el registro en 1 sola instrucción

    ; Comparar bloque real con copias
    pcmpeqb xmm0, xmm2
    
    pmovmskb eax, xmm0     
    cmp eax, 0xFFFF        
    jne .siguiente_bloque ; Si no es homogéneo, se descarta

    ;checks a e13b
    cmp r13b, r14b
    je .siguiente_bloque ; Si es igual al anterior, se descarta (duplicado)
    
    mov r14b, r13b  ; Nueva referencia
    
    cmp r14b, ' '
    je .siguiente_bloque  ;Si es espacio (silencio), se descarta

    ;Guardar en el output
    mov [rdx + r15], r14b
    inc r15            

.siguiente_bloque:
    add r12, 16            
    jmp .loop

.end:
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

global ej4_get_numbers
; void ej4_get_numbers(size_t size, char numbers[10 * (size - 1) + 16], size_t output[size]);
;
; size:   Está en rdi
; signal: Está en rsi
; output: Está en rdx
ej4_get_numbers:
    push rbp
    mov rbp, rsp
    push r12 
    push r13
    push r14
    push r15
    push rbx

    xor rcx, rcx ;contador 
    xor r8, r8 ; r8 es offset de lectura en bytes (avanza de a 10)

    ;cargar mascaras
    movdqa xmm2, [rel ceros]
    movdqa xmm3, [rel espacios]
    movdqa xmm4, [rel mask_10]
    movdqa xmm5, [rel mult_10]
    movdqa xmm6, [rel mult_100]

.loop:
    cmp rcx, rdi
    jge .end

    ;cargamos 16 bytes de entrada 10 bytes de caracteres  + 6 bytes basura
    movdqu xmm0, [rsi + r8]

    ;Restar '0' a cada byte
    psubb xmm0, xmm2

    ;Detectar dónde había espacios (' ' - '0' == 0xF0)
    movdqa xmm1, xmm3
    pcmpeqb xmm1, xmm0

    ;Reemplazar espacios por 0 (donde era espacio queda 0, dígitos 0..9 se mantienen)
    pandn xmm1, xmm0

    ;Limpiar los 6 bytes sobrantes del final
    pand xmm1, xmm4

    ;Contraer adyacentes: d_par * 10 + d_impar en words de 16 bits
    pmaddubsw xmm1, xmm5

    ;Contraer en bloques de 4 dígitos: (d0..d1) * 100 + (d2..d3) en dwords de 32 bits
    pmaddwd xmm1, xmm6

    ;Combinar los 3 dwords en un uint64_t en rax
    ;total = (dw0 * 10000 + dw1) * 100 + dw2
    movd eax, xmm1
    imul rax, 10000

    psrldq xmm1, 4
    movd r9d, xmm1
    add rax, r9
    imul rax, 100

    psrldq xmm1, 4
    movd r9d, xmm1
    add rax, r9

    ;Guardar entero de 64 bits en [rcx]
    mov [rdx + rcx * 8], rax

    inc rcx
    add r8, 10
    jmp .loop

.end:
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

