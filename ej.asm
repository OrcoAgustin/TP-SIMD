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
ej_4_hecho: db FALSE

ALIGN 16
espacios:
	times 10 db ' ' - '0'
	times 6  db 0x0
ceros:
	times 10 db '0'
	times 6  db 0x0
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

    ; Recuperar argumentos de la pila
    mov r10, [rbp + 16]   ; freq_b
    mov r11, [rbp + 24]   ; b_start

    ; Preservar longitudes en registros seguros para no pisarlos con la división
    mov r13, rdx          ; r13 = freq_a_len
    mov r14, r9           ; r14 = freq_b_len

    xor r12, r12          ; r12 = i (contador / índice actual del buffer)

.loop:
    cmp r12, rdi
    jge .end

    ; Calcular índice circular para A: rax = (i + a_start) % freq_a_len
    mov rax, r12
    add rax, r8           ; rax = i + a_start
    xor rdx, rdx          ; Limpiar rdx para la división de 128-bit (rdx:rax)
    div r13               ; rdx:rax / freq_a_len -> el resto (módulo) queda en rdx
    mov rbx, rdx          ; rbx = índice final para freq_a

    
    ; Calcular índice circular para B: rax = (i + b_start) % freq_b_len
    mov rax, r12
    add rax, r11          ; rax = i + b_start
    xor rdx, rdx          ; Limpiar rdx
    div r14               ; rdx:rax / freq_b_len -> el resto queda en rdx
    ; rdx ya tiene el índice final para freq_b

    
    ; Carga SIMD (8 elementos de int16_t = 16 bytes por tabla)
    lea rax, [rcx + rbx * 2]    ; Dirección base + índice * 2 bytes
    movdqu xmm0, [rax]          ; Carga 8 valores de freq_a en xmm0

    lea rax, [r10 + rdx * 2]    ; Dirección base + índice * 2 bytes
    movdqu xmm1, [rax]          ; Carga 8 valores de freq_b en xmm1

    
    ; Operaciones SIMD
    paddsw xmm0, xmm1     ; Suma con signo de 16 bits en paralelo (8 elementos)
    psraw  xmm0, 1        ; Dividir por 2 (shift a rigth, mantiene signo)

    
    ;Guardar resultado en el buffer de salida
    lea rax, [rsi + r12 * 2]
    movdqu [rax], xmm0

    ; Avanzar de a 8 elementos
    add r12, 8
    jmp .loop

.end:
    ; Restaurar registros en orden inverso exacto al push
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

.loop:
	cmp r12, rdi
	jge .postLoop

	;sigue loop, cargo en r11 el signal[i]
	movsx r11, word [rsi + r12 * 2]

	;convierto en float
	cvtsi2ss xmm2, r11

	;calculamos freq i
	mov rax, r12
    shl rax, 3     ; rax = i * 8 (offset en bytes)
    add rax, rdx

	;parte real
	movss xmm3, [rax + 4]     ; Carga freq[i].cos (offset +4 dentro del struct)
    mulss xmm3, xmm2          ; xmm3 = signal[i] * cos[i]
    addss xmm0, xmm3

	;parte imaginaria
	movss xmm4, [rax]    ; Carga freq[i].cos (offset +4 dentro del struct)
    mulss xmm4, xmm2     ; xmm3 = signal[i] * cos[i]
    addss xmm1, xmm4

	inc r12
	jmp .loop

.postLoop:
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

    xor r12, r12          ; r12 = índice de lectura (avanza de 16 en 16)
    xor r15, r15          ; r15 = índice de escritura en output (arranca en 0)

    mov r14b, ' '         ; r14b = señal de referencia (arranca en espacio)

.loop:
    cmp r12, rdi
    jge .end
    
    ; Cargar 16 bytes y salvar INMEDIATAMENTE el primer byte en r13b
    movdqu xmm0, [rsi + r12]
    movd eax, xmm0 ; EAX tiene los primeros 4 bytes, AL tiene el 1ro
    mov r13b, al ; Guardamos de forma segura el carácter del bloque

    ;Preparar xmm1 para la expansión matemática
    pxor xmm1, xmm1
    movd xmm1, eax

    ; Matemática de expansión a 16 bytes
    punpcklbw xmm1, xmm1 
    punpcklwd xmm1, xmm1 
    punpckldq xmm1, xmm1 
    punpcklqdq xmm1, xmm1 

    ; Comparar bloque real con copias
    pcmpeqb xmm0, xmm1
    
    pmovmskb eax, xmm0     
    cmp eax, 0xFFFF        
    jne .siguiente_bloque ; Si no es homogéneo, se descarta

    ; Aplicar reglas de referencia usando r13b
    cmp r13b, r14b
    je .siguiente_bloque ; Si es igual al anterior, se descarta (duplicado)
    
    mov r14b, r13b  ; Nueva referencia
    
    cmp r14b, ' '
    je .siguiente_bloque  ;Si es espacio (silencio), se descarta

    ;Guardar en el output de forma segura y avanzar r15 de a 1
    mov [rdx + r15], r14b
    inc r15            

.siguiente_bloque:
    add r12, 16            
    jmp .loop

.end:
    mov byte [rdx + r15], 0 

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
; size:   Está en ??
; signal: Está en ??
; output: Está en ??
ej4_get_numbers:
	ret
