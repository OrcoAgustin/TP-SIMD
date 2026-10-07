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
ej_1_hecho: db FALSE
ej_2_hecho: db FALSE
ej_3_hecho: db FALSE
ej_4_hecho: db FALSE

ALIGN 16
espacios:
	times 10 db ' ' - '0'
	times 6  db 0x0
ceros:
	times 10 db '0'
	times 6  db 0x0
; ... y otra data que les resulte útil para resolver los ejercicios

section .text

global ej1_sample
; void ej1_sample(size_t buf_len, int16_t buf[buf_len],
;                 size_t freq_a_len, int16_t freq_a[freq_a_len], size_t a_start,
;                 size_t freq_b_len, int16_t freq_b[freq_b_len], size_t b_start);
;
; buf_len:    Está en ??
; buf:        Está en ??
; freq_a_len: Está en ??
; freq_a:     Está en ??
; a_start:    Está en ??
; freq_b_len: Está en ??
; freq_b:     Está en ??
; b_start:    Está en ??
;
; Tener en mente que:
; - buf_len, freq_a_len, freq_b_len, a_start y b_start son siempre múltiplos de 16
; - a_start < freq_a_len y b_start < freq_b_len
; - freq_a y freq_b están dados tal que sumarlos entre sí no causa overflow
ej1_sample:
	add rdi, rdi ; ahora mido en bytes en lugar de ítems

	xor r10, r10
	jmp .guarda
	.loop:
		pxor xmm0, xmm0
		movdqu [rsi + r10], xmm0

		add r10, 16
	.guarda:
		cmp r10, rdi
		jl .loop
	ret

global ej2_detect
; float ej2_detect(size_t size, int16_t signal[size], sincos_t freq[size]);
;
; size:   Está en ??
; signal: Está en ??
; freq:   Está en ??
ej2_detect:
	xorps xmm0, xmm0
	ret

global ej3_remove_duplicates
; void ej3_remove_duplicates(size_t size, char detected[size], char output[]);
;
; size:   Está en ??
; signal: Está en ??
; output: Está en ??
ej3_remove_duplicates:
	ret

global ej4_get_numbers
; void ej4_get_numbers(size_t size, char numbers[10 * (size - 1) + 16], size_t output[size]);
;
; size:   Está en ??
; signal: Está en ??
; output: Está en ??
ej4_get_numbers:
	ret
