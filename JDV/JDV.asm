# Jogo da velha - Player vs CPU
# MIPS (para MARS/QtSPIM)
# Player = 'X' (ASCII 88)
# CPU    = 'O' (ASCII 79)
#
# O jogador digita números 1..9 para as posições:
# 1 2 3
# 4 5 6
# 7 8 9

.data
prompt_move:    .asciiz "\nEscolha uma posicao (1-9): "
invalid_msg:    .asciiz "Entrada invalida ou posicao ocupada. Tente novamente.\n"
player_won:     .asciiz "\nVoce (X) venceu! Parabens!\n"
cpu_won:        .asciiz "\nCPU (O) venceu!\n"
draw_msg:       .asciiz "\nEmpate!\n"
board_msg:      .asciiz "\nTabuleiro:\n"
newline:        .asciiz "\n"
space_str:      .asciiz " "
# board: 9 bytes, 0 = vazio, 'X' = jogador, 'O' = cpu
board:          .space 9

# winning triples (8 triples x 3 indices)
wins:           .word 0,1,2, 3,4,5, 6,7,8,    # rows
                0,3,6, 1,4,7, 2,5,8,        # cols
                0,4,8, 2,4,6               # diagonals

# auxiliares para cpu (cantos e laterais)
corner_indices: .byte 0,2,6,8
side_indices:   .byte 1,3,5,7

.text
.globl main

# -------------------------
# main
# -------------------------
main:
    # inicializa o board com zeros (vazio)
    la $t0, board
    li $t1, 0
init_loop:
    beq $t1, 9, start_game
    sb $zero, 0($t0)
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j init_loop

start_game:
    # loop principal do jogo
game_loop:
    jal print_board

    # --- Jogador ---
player_move:
    la $a0, prompt_move
    li $v0, 4
    syscall

    # ler inteiro
    li $v0, 5
    syscall
    move $t2, $v0        # t2 = pos (1..9) do usuário

    # validar
    li $t3, 1
    li $t4, 9
    blt $t2, $t3, invalid_input
    bgt $t2, $t4, invalid_input

    # indice = pos-1
    addi $t5, $t2, -1    # t5 = index 0..8
    la $t6, board
    add $t6, $t6, $t5
    lb $t7, 0($t6)
    bne $t7, $zero, invalid_input

    # coloca 'X'
    li $t8, 88           # 'X'
    sb $t8, 0($t6)

    # checar se jogador venceu
    li $a0, 88           # char para checar ('X')
    jal check_win_char
    beq $v0, $zero, after_player_check
    # jogador venceu
    la $a0, player_won
    li $v0, 4
    syscall
    jal print_board
    j end_program

invalid_input:
    la $a0, invalid_msg
    li $v0, 4
    syscall
    j player_move

after_player_check:
    # checar empate (tabuleiro cheio)
    jal board_full
    beq $v0, $zero, skip_draw1
    la $a0, draw_msg
    li $v0, 4
    syscall
    jal print_board
    j end_program
skip_draw1:

    # --- CPU ---
    jal cpu_move

    # imprimir tabuleiro pós CPU
    jal print_board

    # checar se CPU venceu
    li $a0, 79           # 'O'
    jal check_win_char
    beq $v0, $zero, skip_cpu_win
    la $a0, cpu_won
    li $v0, 4
    syscall
    j end_program
skip_cpu_win:

    # checar empate novamente
    jal board_full
    beq $v0, $zero, game_loop
    la $a0, draw_msg
    li $v0, 4
    syscall
    j end_program

# -------------------------
# end program
# -------------------------
end_program:
    la $a0, newline
    li $v0, 4
    syscall
    li $v0, 10
    syscall

# -------------------------
# print_board
# imprime o tabuleiro (números onde vazio, X/O onde ocupados)
# usa syscall 11 para imprimir chars e syscall 4 para strings (newline)
# -------------------------
print_board:
    addi $sp, $sp, -8
    sw $ra, 4($sp)

    la $a0, board_msg
    li $v0, 4
    syscall

    la $t0, board
    li $t1, 0        # index 0..8

print_loop:
    beq $t1, 9, print_end
    lb $t2, 0($t0)
    beq $t2, $zero, print_empty_cell
    # ocupado: imprimir char t2 (valor ASCII)
    move $a0, $t2
    li $v0, 11
    syscall
    j after_cell_print

print_empty_cell:
    # imprimir dígito (1..9)
    addi $t3, $t1, 1
    addi $a0, $t3, 48  # ASCII digit in a0
    li $v0, 11
    syscall

after_cell_print:
    # imprimir espaço
    la $a0, space_str
    li $v0, 4
    syscall

    addi $t1, $t1, 1
    addi $t0, $t0, 1

    # se t1 % 3 == 0 imprimir newline
    li $t4, 3
    div $t1, $t4
    mfhi $t5
    beq $t5, $zero, print_nl
    j print_loop

print_nl:
    la $a0, newline
    li $v0, 4
    syscall
    j print_loop

print_end:
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# -------------------------
# check_win_char
# entrada: $a0 = ASCII do char a checar (88='X' ou 79='O')
# ret: $v0 = 1 se alguma tripla vence, 0 caso contrario
# -------------------------
check_win_char:
    addi $sp, $sp, -8
    sw $ra, 4($sp)

    la $t0, wins      # ponteiro para triples
    li $t1, 0         # offset em words processadas (3 words por triple)
    li $t2, 24        # 8*3 = 24 words total

check_win_loop:
    beq $t1, $t2, check_win_end
    lw $t3, 0($t0)    # indice a
    lw $t4, 4($t0)    # indice b
    lw $t5, 8($t0)    # indice c

    la $t6, board
    add $t7, $t6, $t3
    lb $t7, 0($t7)
    add $t8, $t6, $t4
    lb $t8, 0($t8)
    add $t9, $t6, $t5
    lb $t9, 0($t9)

    # comparar com $a0 (char alvo)
    beq $t7, $a0, chk_b
    j next_triple
chk_b:
    beq $t8, $a0, chk_c
    j next_triple
chk_c:
    beq $t9, $a0, win_here
    j next_triple

win_here:
    li $v0, 1
    j check_win_done

next_triple:
    addi $t0, $t0, 12   # avança 3 words (12 bytes)
    addi $t1, $t1, 3
    j check_win_loop

check_win_end:
    li $v0, 0

check_win_done:
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# -------------------------
# board_full
# ret $v0 = 1 se cheio, 0 caso contrario
# -------------------------
board_full:
    addi $sp, $sp, -8
    sw $ra, 4($sp)

    la $t0, board
    li $t1, 0

bf_loop:
    beq $t1, 9, bf_full
    lb $t2, 0($t0)
    beq $t2, $zero, bf_not_full
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j bf_loop

bf_not_full:
    li $v0, 0
    j bf_done

bf_full:
    li $v0, 1

bf_done:
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# =============================================
# CPU MOVE — IA simples: vencer > bloquear > centro > canto > lado
# =============================================

# -------------------------
# cpu_move
# estrategia:
# 1) tentar vencer ('O') colocando temporário em cada casa vazia
# 2) bloquear o jogador ('X') do mesmo jeito
# 3) jogar no centro
# 4) jogar em cantos
# 5) jogar no primeiro espaço vazio
# -------------------------
cpu_move:
    # PROLOGO
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 12($sp)
    sw $s1, 8($sp)
    sw $s2, 4($sp)

    la $s0, board        # ponteiro do tabuleiro

####################################################
# 1) TENTAR VENCER
####################################################
try_win:
    li $s1, 0            # index 0..8
win_loop:
    beq $s1, 9, try_block

    add $s2, $s0, $s1
    lb $t0, 0($s2)
    bne $t0, $zero, win_next

    # tenta 'O'
    li $t1, 79
    sb $t1, 0($s2)

    move $a0, $t1
    jal check_win_char
    beq $v0, $zero, undo_win_try

    # ACHOU jogada vencedora!
    j cpu_move_done_restore

undo_win_try:
    sb $zero, 0($s2)     # desfaz tentativa

win_next:
    addi $s1, $s1, 1
    j win_loop

####################################################
# 2) BLOQUEAR JOGADOR
####################################################
try_block:
    li $s1, 0
block_loop:
    beq $s1, 9, try_center

    add $s2, $s0, $s1
    lb $t0, 0($s2)
    bne $t0, $zero, block_next

    # tenta 'X'
    li $t1, 88
    sb $t1, 0($s2)

    move $a0, $t1
    jal check_win_char
    beq $v0, $zero, undo_block_try

    # BLOQUEIA colocando 'O'
    li $t2, 79
    sb $t2, 0($s2)
    j cpu_move_done_restore

undo_block_try:
    sb $zero, 0($s2)

block_next:
    addi $s1, $s1, 1
    j block_loop

####################################################
# 3) JOGAR NO CENTRO (pos 5, índice 4)
####################################################
try_center:
    addi $s2, $s0, 4
    lb $t0, 0($s2)
    bne $t0, $zero, try_corners

    li $t1, 79
    sb $t1, 0($s2)
    j cpu_move_done_restore

####################################################
# 4) CANTOS (0,2,6,8)
####################################################
try_corners:
    # canto 0
    lb $t0, 0($s0)
    beq $t0, $zero, put_corner0

    # canto 2
    addi $s2, $s0, 2
    lb $t0, 0($s2)
    beq $t0, $zero, put_corner2

    # canto 6
    addi $s2, $s0, 6
    lb $t0, 0($s2)
    beq $t0, $zero, put_corner6

    # canto 8
    addi $s2, $s0, 8
    lb $t0, 0($s2)
    beq $t0, $zero, put_corner8

    j try_first_free

put_corner0:
    li $t1, 79
    sb $t1, 0($s0)
    j cpu_move_done_restore

put_corner2:
    li $t1, 79
    sb $t1, 0($s2)
    j cpu_move_done_restore

put_corner6:
    li $t1, 79
    sb $t1, 0($s2)
    j cpu_move_done_restore

put_corner8:
    li $t1, 79
    sb $t1, 0($s2)
    j cpu_move_done_restore

####################################################
# 5) PRIMEIRA LIVRE
####################################################
try_first_free:
    li $s1, 0
first_free_loop:
    beq $s1, 9, cpu_move_done_restore

    add $s2, $s0, $s1
    lb $t0, 0($s2)
    bne $t0, $zero, next_free

    li $t1, 79
    sb $t1, 0($s2)
    j cpu_move_done_restore

next_free:
    addi $s1, $s1, 1
    j first_free_loop

####################################################
# FIM — restaura stack e retorna
####################################################
cpu_move_done_restore:
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra