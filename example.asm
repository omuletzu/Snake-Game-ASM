; SIMOTA MIHNEA 
.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern realloc: proc
extern printf: proc
extern memcpy: proc
extern srand: proc
extern rand: proc
extern time: proc
extern fopen: proc
extern fclose: proc
extern fprintf: proc
extern fscanf: proc
extern feof: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Snake",0
area_width EQU 640
area_height EQU 480
area DD 0

counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20



symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc
include golden_apple.inc
include ardei.inc 
include rotten_flash.inc
include red_apple.inc
include smiley.inc
include skin.inc
include zid.inc

;snake --------------------------
lungime DD 0
queue_x DD 0
queue_y DD 0
nr DD 0
cord_x DD 0
cord_y DD 0
d DB "%d ", 0
ciar DB "%c", 0
spatiu DB ", ", 0
last_key DD 0
aux1 DD 0
aux2 DD 0
aux3 DD 0
scor DD 0
game_lost DD 0
mat_rand DD 0
nume DD 0
ind_nume DD 460
pos_act_nume DD 0
counter_enter DD 0
filename DB "scoreboard.txt", 0
open_mod DB "a", 0
read_mod DB "r", 0
file_pointer DD 0
caract_nume DD 0
sleep DD 1000000000
sleep_counter DD 0
;--------------------------------------------------
.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
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
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
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
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
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
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y

add_pos macro x, y				; macro adaugare
	push x
	push y
	call enqueue
	add esp, 8
endm

get_eax macro x, y, len, point
	mov eax, y
	mov ebx, len 
	mul ebx
	add eax, x
	shl eax, 2
	add eax, point
	mov ecx, 400
endm 

wall_oriz macro x, y
local wall_oriz_loop
	get_eax x, y, area_width, area
	mov ecx, 20
	mov ebx, x
	
	wall_oriz_loop:
		push 5
		push offset zid_0
		push y
		push ebx
		call fill_square_image
		add esp, 16
		add eax, 4
		add ebx, 20
	loop wall_oriz_loop
endm

wall_vert macro x, y
local wall_vert_loop
	get_eax x, y, area_width, area
	mov ecx, 20
	mov ebx, y
	
	wall_vert_loop:
		push 5
		push offset zid_0
		push ebx
		push x
		call fill_square_image
		add esp, 16
		add eax, 4
		add ebx, 20
	loop wall_vert_loop
endm

linie_oriz macro x, y, len, point			; macro linie oriz
local bucl_oriz
	get_eax x, y, len, area
	
	bucl_oriz:
		mov dword ptr[eax], 0
		add eax, 4
	loop bucl_oriz
endm
	
linie_vert macro x, y, len, point
local bucl_vert
	get_eax x, y, len, area
	
	bucl_vert:
		mov dword ptr[eax], 0
		add eax, 4 * area_width
	loop bucl_vert	
endm

point_area macro x, y						; ebx are pointer ul
	push x
	push y
	sub x, 49
	sub y, 49
	
	get_eax x, y, 400, mat_rand
	mov ebx, dword ptr[eax]
	pop y
	pop x
endm

afis_scor macro x, y								; afisare cifra scor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, x, y
endm
	
taie_coada macro
	push ecx
	push edx
	mov edi, queue_x
	mov esi, queue_y
	mov ecx, dword ptr[edi]
	mov edx, dword ptr[esi]
	push 0
	push 0FFFFFFh
	push edx
	push ecx
	call fill_square
	add esp, 16
	call dequeue
	pop edx
	pop ecx
endm	
	
pune_bloc macro x, y
	push 5
	push offset zid_0
	push y
	push x
	call fill_square_image
	add esp, 16
endm
	
jmp draw

fill_square_image proc				; patrate de 20x20					
	push ebp
	mov ebp, esp
	pusha 

	get_eax [ebp + 8], [ebp + 12], area_width, area
	mov ecx, 20
	mov edi, [ebp + 16]
	
	fill:
		push ecx
		mov ecx, 20
		trage_linie:
			mov edx, dword ptr[edi]
			mov dword ptr[eax], edx 
			add edi, 4
			add eax, 4
		loop trage_linie
		add eax, 4 * (area_width - 20)
		pop ecx
	loop fill									
	
	mov eax, [ebp + 12]
	sub eax, 49
	mov ebx, 400
	mul ebx
	add eax, [ebp + 8]
	sub eax, 49
	shl eax, 2
	add eax, mat_rand
	mov ebx, [ebp + 20]
	mov dword ptr[eax], ebx
	
	popa
	mov esp, ebp
	pop ebp
	ret
fill_square_image endp

fill_square proc				; patrate de 20x20					
	push ebp
	mov ebp, esp
	pusha 

	get_eax [ebp + 8], [ebp + 12], area_width, area
	mov ecx, 20
	
	fill:
		push ecx
		mov ecx, 20
		trage_linie:
			mov edx, [ebp + 16]
			mov dword ptr[eax], edx 
			add eax, 4
		loop trage_linie
		add eax, 4 * (area_width - 20)
		pop ecx
	loop fill									
	
	mov eax, [ebp + 12]
	sub eax, 49
	mov ebx, 400
	mul ebx
	add eax, [ebp + 8]
	sub eax, 49
	shl eax, 2
	add eax, mat_rand
	mov ebx, [ebp + 20]
	mov dword ptr[eax], ebx
	
	popa
	mov esp, ebp
	pop ebp
	ret
fill_square endp

get_rand proc
	push ebp
	mov ebp, esp
	pusha
	
		call rand
		
		mov edx, 0
		mov ebx, 20
		div ebx
		mov aux2, edx
		mov eax, edx						; in eax e un nr random
		mov ebx, 20
		mul ebx
		add eax, 50
		mov aux1, eax
		
	popa
	mov eax, aux1
	mov ebx, aux2
	mov esp, ebp
	pop ebp
	ret
get_rand endp

update_q proc							; ecx - x, edx - y
	push ebp
	mov ebp, esp
	pusha 
	push edx
	
		add_pos ecx, edx
		point_area ecx, edx
		
		pop edx
		push 5
		push offset var_0
		push edx
		push ecx
		call fill_square_image
		add esp, 16
		
	cmp ebx, 5									; chenar sau el insusi
	jne not_game_over
	
		mov game_lost, 1
		jmp iesi
		
	not_game_over:
	cmp ebx, 4							; ardei 
	jne not_ardei
		mov sleep_counter, 40
		
		mov aux3, 0
		jmp not_random
	not_ardei:
	
	cmp ebx, 2							; mar auriu
	jne not_mar_auriu
		inc scor
		mov aux3, 0
		jmp not_random
	not_mar_auriu:
	
	cmp ebx, 3							; mancare stricata
	jne not_random
		taie_coada
		mov aux3, 0
	
	not_random:
	cmp ebx, 1
	je get_random_cord								; mar simplu
	
		taie_coada
		jmp exit_update				
		
	get_random_cord:
		call get_rand				; pune alta mancare														
		mov ecx, eax
		call get_rand
		mov edx, eax
		point_area ecx, edx
		
	cmp ebx, 0
	jne get_random_cord
		
		push 1
		push offset red_apple_0
		push edx
		push ecx
		call fill_square_image
		add esp, 16
		
	exit_update:									; obiect random
	
		call get_rand
		mov ecx, eax
		call get_rand
		mov edx, eax
		point_area ecx, edx
		
	cmp ebx, 0
	jne exit_update
	
		call get_rand
		cmp ebx, 10
		jne iesi
		
		cmp aux3, 1
		je iesi 
		
		mov aux3, 1
		
		call get_rand
		
		cmp ebx, 7						; pune ardei iute
		jg rand_salt1
			push 4
			push offset ardei_0
			push edx
			push ecx
			call fill_square_image
			add esp, 16
			jmp iesi
			
		rand_salt1:
		
		cmp ebx, 13						; pune mar auriu
		jg rand_salt2
			push 2
			push offset golden_apple_0
			push edx
			push ecx
			call fill_square_image
			add esp, 16
			jmp iesi
		
		rand_salt2:						; pune mancare stricata
			push 3
			push offset rotten_flash_0
			push edx
			push ecx
			call fill_square_image
			add esp, 16
			
	iesi:
	
	popa
	mov esp, ebp
	pop ebp
	ret
update_q endp

draw proc															; mat_rand ->  0 gol, 1 mar, 2 mar auriu, 3 mancare stricata, 4 ardei iute, 5 sarpe
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp + arg1]
	cmp eax, 0
	jne not_init
	mov eax, area_width						; initializare fereastra alb
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	
	mov eax, 30									; initializare locuri nume pt final
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov nume, eax
	
	mov eax, 405 * 405						;initializare mat_rand
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov mat_rand, eax
	
	mov esi, 0
	mat_rand_init:
		mov dword ptr[eax + 4 * esi], 0
		inc esi
	cmp esi, 400 * 400 - 1
	jne mat_rand_init
	
	mov last_key, 0				; initial sta pe loc
	mov eax, 400
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	
	add_pos 250, 250								; pune sarpele in mijloc initial
	push 5
	push offset var_0
	push 250
	push 250
	call fill_square_image
	add esp, 16
	
	call time					; seed pt rand
	push eax
	call srand
	add esp, 4
	
	wall_oriz 50, 50								; pune zid
	wall_oriz 50, 430
	wall_vert 430, 50
	wall_vert 50, 50
	
	pune_bloc 110, 110					; blocuri pe harta 
	pune_bloc 110, 130
	pune_bloc 130, 130
	pune_bloc 350, 350
	pune_bloc 330, 350
	
	loop_init_mar:
	call get_rand				; pune mancare initial, pune marul dupa wall												
	mov ecx, eax
	call get_rand
	mov edx, eax
	
	point_area ecx, edx 
	cmp ebx, 0
	jne loop_init_mar
	
	push 1 
	push offset red_apple_0
	push ecx
	push edx
	call fill_square_image
	add esp, 16								; final mancare init
	
	mov edi, mat_rand
	mov dword ptr[edi + (200 * area_width + 200) * 4], 1
	
	linie_oriz 50, 50, area_width, area								; ecran (50, 50) -> (450, 450)
	linie_vert 50, 50, area_width, area
	linie_oriz 50, 450, area_width, area
	linie_vert 450, 50, area_width, area
	
	not_init:
	
	cmp game_lost, 1									; verificare game over
	je exit_program
	
	jmp jump_exit_program
	
	exit_program:
		make_text_macro 'G', area, 460, 70
		make_text_macro 'A', area, 470, 70
		make_text_macro 'M', area, 480, 70
		make_text_macro 'E', area, 490, 70
		make_text_macro ' ', area, 500, 70
		make_text_macro 'O', area, 510, 70
		make_text_macro 'V', area, 520, 70
		make_text_macro 'E', area, 530, 70
		make_text_macro 'R', area, 540, 70
		
		make_text_macro 'I', area, 460, 90
		make_text_macro 'N', area, 470, 90
		make_text_macro 'T', area, 480, 90
		make_text_macro 'R', area, 490, 90
		make_text_macro 'O', area, 500, 90
		make_text_macro 'D', area, 510, 90
		make_text_macro 'U', area, 520, 90
		make_text_macro ' ', area, 530, 90
		make_text_macro 'N', area, 540, 90
		make_text_macro 'U', area, 550, 90
		make_text_macro 'M', area, 560, 90
		make_text_macro 'E', area, 570, 90
		
		mov ebx, [ebp + arg1]
		cmp ebx, 3
		jne finish
		
			mov ebx, [ebp + arg2]
			make_text_macro ebx, area, ind_nume, 130
			add ind_nume, 10
			mov eax, nume
			mov ecx, pos_act_nume
			shl ecx, 2
			add eax, ecx
			inc pos_act_nume
			mov dword ptr[eax], ebx
			
			cmp ebx, 13
			jne finish
				inc counter_enter
				
				cmp counter_enter, 1
				jne exit_program2
				
				push offset open_mod							; deschide fisier sa scrie cu append
				push offset filename
				call fopen
				add esp, 8
				mov ebx, eax
				
				mov edi, nume									; scrie numele litera cu litera
				mov esi, 0
				sub pos_act_nume, 2
				cmp pos_act_nume, 0
				jl exit_program2
				
				push scor
				push offset d 
				push ebx
				call fprintf
				add esp, 12
				
				loop_printf:
					push dword ptr[edi + 4 * esi]
					push offset ciar
					push ebx
					call fprintf
					add esp, 12
					inc esi
				cmp esi, pos_act_nume
				jng loop_printf
				
				push offset spatiu
				push ebx
				call fprintf
				add esp, 8
				
				push ebx
				call fclose
				add esp, 4
				
				mov edi, area									; sterge matricea si scorul
				mov ecx, 640 * 480
				sterge_ecran:
					mov dword ptr[edi], 0FFFFFFh
					add edi, 4
				loop sterge_ecran
				
				push offset read_mod							; deschide fisierul sa citeasca din el
				push offset filename
				call fopen
				add esp, 8
				mov ebx, eax
				mov aux2, 30									; aux2 e y pentru afisare
				
				fscanf_loop:									; de fiecare data se citeste scor + caractere nume (pana la prima virgula)
					push ebx									; citeste scor
					push offset aux1
					push offset d 
					push ebx
					call fscanf
					add esp, 12
					
					pusha										; verifica daca e ultima virgula din fisier , daca da iese
					push ebx
					call feof
					add esp, 4
					cmp eax, 0
					jne exit_game_over
					popa
					
					mov ebx, 10									; afiseaza pe ecran scorul
					mov eax, aux1
					afis_scor 30, aux2
					afis_scor 20, aux2
					afis_scor 10, aux2
					pop ebx
					
					push ebx									; citeste caracterele si le afiseaza
					mov aux3, 50
					loop_citire_nume:
						push offset caract_nume 				; caract_nume retine caracterul citit
						push offset ciar
						push ebx
						call fscanf
						add esp, 12
						
						make_text_macro caract_nume, area, aux3, aux2
						add aux3, 10
						
					cmp caract_nume, ','						; pana la prima virgula citita
					jne loop_citire_nume
					
					add aux2, 20
					pop ebx
				
				jmp fscanf_loop
					
				exit_game_over:	
		jmp finish 
	
	jump_exit_program:									; terminare verificare game over
	
	make_text_macro 'S', area, 10, 0
	make_text_macro 'C', area, 20, 0
	make_text_macro 'O', area, 30, 0
	make_text_macro 'R', area, 40, 0
	
	mov ebx, 10											; scor						
	mov eax, scor
	afis_scor 30, 20
	afis_scor 20, 20
	afis_scor 10, 20
	
	mov ebx, [ebp + arg1]
	cmp ebx, 3
	jne not_new_key
		mov ebx, [ebp + arg2]
		cmp ebx, 37
		jne else_key1
			cmp last_key, 39
			jne else_key1
				mov ebx, last_key
				jmp update_snake
		else_key1:
		
		cmp ebx, 38
		jne else_key2
			cmp last_key, 40
			jne else_key2
				mov ebx, last_key
				jmp update_snake
		else_key2:
		cmp ebx, 39
		jne else_key3
			cmp last_key, 37
			jne else_key3
				mov ebx, last_key
				jmp update_snake
		else_key3:
		cmp ebx, 40
		jne else_key4
			cmp last_key, 38
			jne else_key4
				mov ebx, last_key
				jmp update_snake
		else_key4:
		jmp update_snake
		
	not_new_key:
		mov ebx, last_key

	; cmp sleep_counter, 0
	; jg update_snake
	
		; push ecx
		; mov ecx, sleep
		; loop_sleep:
		; loop loop_sleep
		; pop ecx
		
	update_snake:
	; dec sleep_counter
	
	mov eax, lungime							; update snake
	dec eax
	shl eax, 2
	mov edi, queue_x
	add edi, eax
	mov ecx, dword ptr[edi]
	mov esi, queue_y
	add esi, eax 
	mov edx, dword ptr[esi]
	
	cmp ebx, 37				; stanga
	jne salt1
		sub ecx, 20
		cmp ecx, 70
		jnl continue1
			mov game_lost, 1
			jmp exit_program
			
		continue1:
		call update_q
		jmp salt_final
			
	salt1:
	cmp ebx, 38					; sus
	jne salt2
		sub edx, 20
		cmp edx, 70
		jnl continue2
			mov game_lost, 1
			jmp exit_program
			
		continue2:
		call update_q
		jmp salt_final
			
	salt2:
		
	cmp ebx, 39					; dreapta
	jne salt3
		add ecx, 20
		cmp ecx, 410
		jng continue3
			mov game_lost, 1
			jmp exit_program
			
		continue3:
		call update_q
		jmp salt_final
			
	salt3:
	cmp ebx, 40					; jos
	jne salt_final
		add edx, 20
		cmp edx, 410
		jng continue4
			mov game_lost, 1
			jmp exit_program
			
		continue4:
		call update_q
		jmp salt_final
		
	salt_final:
	mov last_key, ebx
	
evt_timer:								
	inc counter
	
	jmp finish
	
	enqueue proc
		push ebp
		mov ebp, esp
		pusha
		
			cmp lungime, 0
			jne not_zero
				mov eax, 4
				push eax
				call malloc
				add esp, 4
				mov queue_x, eax
				
				mov eax, 4
				push eax
				call malloc
				add esp, 4
				mov queue_y, eax
				
				mov eax, [ebp + 8]
				mov edi, queue_y
				mov dword ptr[edi], eax
				mov eax, [ebp + 12]
				mov edi, queue_x
				mov dword ptr[edi], eax
				
				jmp iesi
			
			not_zero:
				mov eax, lungime							; queue_x
				inc eax
				shl eax, 2
				push eax
				call malloc
				add esp, 4
				
				mov edi, queue_x
				mov esi, 0
				loop_copy1:
					mov ebx, dword ptr[edi + 4 * esi]
					mov dword ptr[eax + 4 * esi], ebx
					inc esi
				cmp esi, lungime
				jne loop_copy1
				
				
				mov eax, lungime
				inc eax
				shl eax, 2
				push eax
				push queue_x
				call realloc
				add esp, 8
				
				mov esi, 0
				mov edx, eax
				loop_copy2:
					mov ebx, dword ptr[edx + 4 * esi]
					mov dword ptr[eax + 4 * esi], ebx
					inc esi
				cmp esi, lungime
				jne loop_copy2
				mov queue_x, eax
				
				mov eax, [ebp + 12]
				mov edi, lungime
				shl edi, 2
				add edi, queue_x
				mov dword ptr[edi], eax
				
				mov eax, lungime							; queue_y
				inc eax
				shl eax, 2
				push eax
				call malloc
				add esp, 4
				
				mov edi, queue_y
				mov esi, 0
				loop_copy3:
					mov ebx, dword ptr[edi + 4 * esi]
					mov dword ptr[eax + 4 * esi], ebx
					inc esi
				cmp esi, lungime
				jne loop_copy3
				
				
				mov eax, lungime
				inc eax
				shl eax, 2
				push eax
				push queue_y
				call realloc
				add esp, 8
				
				mov esi, 0
				mov edx, eax
				loop_copy4:
					mov ebx, dword ptr[edx + 4 * esi]
					mov dword ptr[eax + 4 * esi], ebx
					inc esi
				cmp esi, lungime
				jne loop_copy4
				mov queue_y, eax
				
				mov eax, [ebp + 8]
				mov edi, lungime
				shl edi, 2
				add edi, queue_y
				mov dword ptr[edi], eax

		iesi:
		inc lungime
		inc scor
		
		popa
		mov esp, ebp
		pop ebp
		ret
	enqueue endp
	
	dequeue proc
		push ebp
		mov ebp, esp
		pusha
			
			dec scor
			dec lungime
			cmp lungime, 0
			jne not_game_lost
				mov game_lost, 1
				jmp eticheta_game_lost
			
			not_game_lost:
			mov eax, lungime
			dec eax
			
			mov esi, 0
			mov edi, queue_x
			mov ecx, queue_y
			
			del_ele:
				mov ebx, dword ptr[edi + 4 * esi + 4]
				mov dword ptr[edi + 4 * esi], ebx
				mov ebx, dword ptr[ecx + 4 * esi + 4]
				mov dword ptr[ecx + 4 * esi], ebx
				inc esi
			cmp esi, eax
			jng del_ele
			
			mov eax, lungime
			shl eax, 2
			push eax
			push queue_x
			call realloc
			add esp, 8
			
			mov eax, lungime
			shl eax, 2
			push eax
			push queue_y
			call realloc
			add esp, 8
			
		eticheta_game_lost:
		popa
		mov esp, ebp
		pop ebp
		ret
	dequeue endp
	
finish:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

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
	exit_program2:
	push 0
	call exit
end start
 