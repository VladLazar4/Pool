.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc
extern rand: proc
extern time: proc
extern srand: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;s;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Biliard",0
area_width EQU 640
area_height EQU 480
area DD 0
aux1 DD 0
aux2 DD 0
aux3 DD 0
cd1 DD 285, 310, 335, 285, 310, 335, 285, 310, 335
cd2 DD 385, 385, 385, 410, 410, 410, 435, 435, 435
cd3 DD 305, 330, 355, 305, 330, 355, 305, 330, 355
cd4 DD 405, 405, 405, 430, 430, 430, 455, 455, 455
dir_x DD -1, 0, 1, -1, 0, 1, -1, 0, 1
dir_y DD -1, -1, -1, 0, 0, 0, 1, 1, 1
x1 DD 0
y1 DD 0
x2 DD 0
y2 DD 0
directie1 DD 0
directie2 DD 0
directie1_ant DD 0
directie2_ant DD 0
v DD 0, 0, 0, 0

format_dbg DB "x1=%d y1=%d x2=%d y2=%d", 13, 10, 0
format1 DB "eax=%d ebx=%d",13,10,0

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20
arg5 EQU 24

symbol_width EQU 20
symbol_height EQU 20
include digits.inc
include letters.inc
include symbols.inc

.code

; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
; arg5 - culoarea
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	cmp eax, 27
	jl make_symbol
	cmp eax, 31
	jg make_symbol
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
make_symbol:
	lea esi, symbols
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_langa
	mov edx, [ebp+arg5]
	mov dword ptr [edi], edx
	jmp simbol_pixel_next
simbol_pixel_langa:
	mov eax, [ebp+arg1]
	cmp eax, 0
	jne skip_colorare
	; pixelii din jur se coloreaza cu culoarea din arg6
	pusha
	; mov edx, [ebp+arg6]
	mov dword ptr [edi], 00802bh
	popa
	skip_colorare:
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y, color
	; push color_bg
	push color
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 20
endm

init_pixel macro x, y
	mov eax, [y]
	mov ebx, area_width
	mul ebx
	mov ebx, [x]
	add eax, ebx
	shl eax, 2
	add eax, area
endm

make_horizontal_line macro x, y, len, color
local bucla
	init_pixel x, y
	mov ecx, len
	sub ecx, x
	bucla:
		mov dword ptr[eax],color
		add eax,4
	loop bucla
endm

make_vertical_line macro x, y, len, color
local bucla
	init_pixel x, y
	mov ecx, len
	sub ecx, y
	bucla:
		mov dword ptr[eax],color
		add eax,4*area_width
	loop bucla
endm

chenar_dreptunghi macro x1, y1, x2, y2, color

	make_vertical_line x1, y1, y2, color
	make_horizontal_line x1, y1, x2, color
	make_vertical_line x2, y1, y2, color
	make_horizontal_line x1, y2, x2, color
	
endm

dreptunghi macro x1, y1, x2, y2, color
local bucla, exit
	push edi
	mov esi, y1
	mov edi, y2
	bucla:
		mov [aux1], esi
		make_horizontal_line x1, aux1, x2, color		
		inc esi
		cmp esi, edi
		jge exit
	jmp bucla
	exit:
	pop edi
endm

change_direction macro
local et1,et2,et3,final
;colturi
; 1	2
; 4	3
	cmp [v], 1
	jne et1
		cmp [v+4], 1
		jne et1
			add ecx, 6
			jmp final
		cmp [v+12], 1
		je et3
		mov ecx, 4
	et1:
	
	cmp [v+4], 1
	jne et2
		cmp [v+8], 1
		jne et2
			sub ecx, 2
			jmp final
		;coltul 1 nu mai are cum sa fie in contact, deci e doar 2
		mov ecx, 4
	et2:
	
	cmp [v+8], 1
	jne et3
		cmp [v+12], 1
		jne et3
			sub ecx, 6
			jmp final
		;2 nu mai e in contact, doar 3
		mov ecx, 4
			
	et3:
	
	cmp [v+12],1
	jne final
		add ecx, 2
		;doar 4
	final:
endm

init_vector macro
	mov [v],0
	mov [v+4],0
	mov [v+8],0
	mov [v+12],0
endm

check_border macro
local skip1,skip2,skip3,final
	pop aux2
	pop aux1

	init_vector
	
	mov eax, aux2
	dec eax
	mov ebx, area_width
	mul ebx
	mov ebx, aux1
	add eax, ebx
	dec eax
	shl eax, 2
	add eax, area
	cmp dword ptr [eax], 00802bh
	je skip1
		mov [v], 1
	skip1:
	
	sub eax, area
	shr eax, 2
	add eax, symbol_width
	add eax,2
	shl eax, 2
	add eax, area
	cmp dword ptr [eax], 00802bh
	je skip2
		mov [v+4], 1
	skip2:
	
	sub eax, area
	shr eax, 2
	push eax
	mov eax, area_width
	mov ebx, symbol_height
	inc ebx
	mul ebx
	pop ebx
	add eax, ebx
	shl eax, 2
	add eax, area
	cmp dword ptr [eax], 00802bh
	je skip3
		mov [v+8], 1
	skip3:
	
	sub eax, area
	shr eax, 2
	sub eax, symbol_width
	sub eax, 2
	shl eax, 2
	add eax, area
	cmp dword ptr [eax], 00802bh
	je final
		mov [v+12], 1
	final:
	change_direction
endm

modul macro
local final
	mov aux3, eax
	pop eax
	cmp eax, 0
	jg final
		push ebx
		mov ebx, -1
		mul ebx
		pop ebx
	final:
	push eax
	mov eax, aux3
endm

change_direction2 macro
local sk1, sk2, sk3, sk4, et1, et2, et3, et4, et11, et21, et31, et41
	cmp ecx, 1
	jne sk1
		mov ecx, 7
		mov edx, 1
		jmp et4
	sk1:
	cmp ecx, 3
	jne sk2
		mov ecx, 5
		mov edx, 3
		jmp et4
	sk2:
	cmp ecx, 5
	jne sk3
		mov ecx, 3
		mov edx, 5
		jmp et4
	sk3:
	cmp ecx, 7
	jne sk4
		mov ecx, 1
		mov edx, 7
		jmp et4
	sk4:
	
	cmp edi, 20 ;jos
	jg et1
		cmp edi, 15
		jl et1
		cmp esi, 0
		jg et11
			mov ecx, 6
			mov edx, 2
			jmp et4
		et11:
			mov ecx, 8
			mov edx, 0
		jmp et4
	et1:
	
	cmp edi, -20 ;sus
	jl et2
		cmp edi, -15
		jg et2
		cmp esi, 0
		jg et21
			mov ecx, 2
			mov edx, 6
			jmp et4
		et21:
			mov ecx, 0
			mov edx, 8
		jmp et4
	et2:
	
	cmp esi, -20 ;stanga
	jl et3
		cmp esi, -15
		jg et3
		cmp edi, 0
		jg et31
			mov ecx, 6
			mov edx, 2
			jmp et4
		et31:
			mov ecx, 0
			mov edx, 8
		jmp et4
		
	et3:
	
	cmp esi, 20; dreapta
	jg et4
		cmp esi, 15
		jl et4
		cmp edi, 0
		jg et41
			mov ecx, 8
			mov edx, 0
			jmp et4
		et41:
				mov ecx, 2
				mov edx, 6
	et4:
endm

check_collision macro
	pusha
	
	mov ecx, directie1
	mov eax, [x1]
	mov ebx, [y1]
	add eax, [dir_x+4*ecx]
	add ebx, [dir_y+4*ecx]
	
	mov edx, directie2
	mov esi, [x2]
	mov edi, [y2]
	add eax, [dir_x+4*edx]
	add ebx, [dir_y+4*edx]
	
	sub eax, esi
	sub ebx, edi
	mov esi, eax
	mov edi, ebx
	
	push eax
	modul
	pop eax
	
	push ebx
	modul
	pop ebx
	
	
	cmp eax, symbol_width
	jg final
		cmp ebx, symbol_height
		jg final	
			mov ecx, [directie1]
			mov edx, [directie2]
			change_direction2
			mov [directie1], ecx
			mov [directie2], edx
	final:
	popa
endm

move_ball macro x,y,color
	mov eax, [x]
	mov ebx, [y]
	
	make_text_macro 10, area, eax, ebx, color
	pop ecx
	
	add eax, [dir_x+4*ecx]
	add ebx, [dir_y+4*ecx]
	push eax
	push ebx
	check_border
	
	mov eax, [x]
	mov ebx, [y]
	add eax, [dir_x+4*ecx]
	add ebx, [dir_y+4*ecx]
	
	push ecx
	make_text_macro 0, area, eax, ebx, color
	
	pop ecx

	mov [x], eax
	mov [y], ebx
	push ecx
endm

check_button macro a0, b0, a1, b1, a2, b2, dir
	mov eax, a1
	mov ebx, a2
	mov ecx, a0
	cmp eax, ecx
	jg nu
		cmp ecx, ebx
		jg nu
			mov eax, b1
			mov ebx, b2
			mov ecx, b0
			cmp eax, ecx
			jg nu
				cmp ecx, ebx
				jg nu
					push dir
					move_ball x1,y1,0
					pop directie1
					mov edi, 10
	nu:
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	
	;masa
	dreptunghi 0, 0, 640, 480, 0b33c00h
	dreptunghi 30, 30, 610, 380, 00802bh
	
	;buttons
	dreptunghi 310, 385, 330, 405, 33B9FFh
	dreptunghi 310, 435, 330, 455, 33B9FFh
	dreptunghi 335, 410, 355, 430, 33B9FFh
	dreptunghi 285, 410, 305, 430, 33B9FFh
	
	dreptunghi 285, 385, 305, 405, 33B9FFh
	dreptunghi 335, 385, 355, 405, 33B9FFh
	dreptunghi 285, 435, 305, 455, 33B9FFh
	dreptunghi 335, 435, 355, 455, 33B9FFh
	
	dreptunghi 310, 410, 330, 430, 33FF9Fh
	
	;arrows
	make_text_macro 1, area, 310, 385, 0
	make_text_macro 2, area, 310, 435, 0
	make_text_macro 3, area, 335, 410, 0
	make_text_macro 4, area, 285, 410, 0
	make_text_macro 5, area, 335, 385, 0
	make_text_macro 6, area, 335, 435, 0
	make_text_macro 7, area, 285, 385, 0
	make_text_macro 8, area, 285, 435, 0
	
	;balls
	push directie1
	move_ball x1,y1,0
	pop directie1
	
	push directie2
	move_ball x2,y2,0033cch
	pop directie2
	
	jmp final_draw
	
evt_click:	
	mov edi, 0
	parcurgere_directii:
		check_button [ebp+arg2], [ebp+arg3], [cd1+edi*4], [cd2+edi*4], [cd3+edi*4], [cd4+edi*4], edi
		inc edi
		cmp edi, 8
		jle parcurgere_directii
	jmp final_draw
	
evt_timer:
	mov edi, 15
	bucla_viteza:
		check_collision
		
		push directie1
		move_ball x1,y1,0
		pop directie1
		
		push directie2
		move_ball x2,y2,0033cch
		pop directie2

		dec edi
		cmp edi, 0
	jne bucla_viteza
	

final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

randomizare macro i, j
	mov edi, j
	mov esi, i
	sub edi, esi
	
	call rand
	mov edx, 0
	div edi
	add edx, i
	
endm

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	
	;rand initializare
	push 0
	call time
	add esp, 4

	push eax
	call srand
	add esp, 4
	
	;randomizam coordonatele bilei 1
	randomizare 30, 300
	mov x1, edx
	randomizare 30, 360
	mov y1, edx
	
	;pt bila 2
	randomizare 320, 590
	mov x2, edx
	randomizare 30, 360
	mov y2, edx
	
	; randomizare directie
	randomizare 0, 8
	mov directie1, edx
	
	;pt bila 2
	randomizare 0, 8
	mov directie2, edx
	
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start

; pusha
; push y2
; push x2
; push y1
; push x1
; push offset format_dbg
; call printf
; add esp, 20
; popa