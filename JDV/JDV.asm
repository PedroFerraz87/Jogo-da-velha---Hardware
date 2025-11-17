# Jogo da Velha Player vs CPU - MIPS (MARS / QtSPIM)

.data
prompt_move:    .asciiz "\nEscolha uma posicao (1-9): "
invalid_msg:    .asciiz "Entrada invalida. Digite apenas um numero entre 1 e 9.\n"
occupied_msg:   .asciiz "Posicao ocupada. Escolha outra.\n"
player_won:     .asciiz "\nVoce (X) venceu! Parabens!\n"
cpu_won:        .asciiz "\nCPU (O) venceu!\n"
draw_msg:       .asciiz "\nEmpate!\n"
board_msg:      .asciiz "\nTabuleiro:\n"
newline:        .asciiz "\n"
space_str:      .asciiz " "

# board: 9 bytes, 0 = vazio, 'X', 'O'
board:          .space 9

# 8 winning triples (3 words each) = 24 words
wins:           .word 0,1,2, 3,4,5, 6,7,8,    # rows
                0,3,6, 1,4,7, 2,5,8,        # cols
                0,4,8, 2,4,6               # diagonals

# buffers
inbuf:          .space 8      # leitura de entrada do jogador (max 7 chars + null)
fmt_newline:    .asciiz "\n"

.text
.globl main

# -------------------------
# main
# -------------------------
main:
    # inicializa tabuleiro
    jal init_board

game_loop:
    # imprime tabuleiro
    jal print_board

player_turn:
    # pede e lê jogada como string -> parse
    jal read_move       # retorna em $v0: -1 invalid input, -2 occupied, 0..8 index valid
    bltz $v0, handle_player_invalid   # negative -> invalid or occupied
    # $v0 >= 0 => índice válido
    move $t0, $v0       # t0 = index 0..8
    # coloca 'X'
    li $t1, 88          # ASCII 'X'
    la $t2, board
    add $t2, $t2, $t0
    sb $t1, 0($t2)

    # checar se jogador venceu
    li $a0, 88
    jal check_win_char
    beq $v0, $zero, after_player_check
    # jogador venceu
    la $a0, player_won
    li $v0, 4
    syscall
    jal print_board
    j end_program

handle_player_invalid:
    # v0 == -2 => ocupada, -1 => inválida formato
    beq $v0, -2, show_occupied_msg
    # otherwise invalid format
    la $a0, invalid_msg
    li $v0, 4
    syscall
    j player_turn

show_occupied_msg:
    la $a0, occupied_msg
    li $v0, 4
    syscall
    j player_turn

after_player_check:
    # checar empate (tabuleiro cheio)
    jal board_full
    beq $v0, $zero, cpu_phase
    la $a0, draw_msg
    li $v0, 4
    syscall
    jal print_board
    j end_program

cpu_phase:
    # CPU faz jogada (passa nada, usa tabuleiro global)
    jal cpu_move

    # imprime tabuleiro pós CPU
    jal print_board

    # checar se CPU venceu
    li $a0, 79          # 'O'
    jal check_win_char
    beq $v0, $zero, check_draw_after_cpu
    la $a0, cpu_won
    li $v0, 4
    syscall
    j end_program

check_draw_after_cpu:
    jal board_full
    beq $v0, $zero, game_loop
    la $a0, draw_msg
    li $v0, 4
    syscall
    j end_program

# -------------------------
# end_program
# -------------------------
end_program:
    la $a0, newline
    li $v0, 4
    syscall
    li $v0, 10
    syscall

# -------------------------
# init_board
# Zera os 9 bytes do board
# -------------------------
init_board:
    addi $sp, $sp, -8
    sw $ra, 4($sp)

    la $t0, board
    li $t1, 0
init_loop:
    beq $t1, 9, init_done
    sb $zero, 0($t0)
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j init_loop

init_done:
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# -------------------------
# print_board
# imprime o tabuleiro (dígitos 1..9 para vazios, X/O para ocupados)
# Convenção: nenhum argumento, retorna nada
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
    # ocupado: imprimir char t2
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
# read_move
# Lê string do usuário e valida.
# Retorna em $v0:
#   -1 => formato inválido (não é número único 1..9)
#   -2 => posição ocupada
#    0..8 => índice válido e posição livre
# Convenção: nenhum argumento; usa inbuf buffer
# -------------------------
read_move:
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)    # s0 usado como ponteiro do board
    sw $s1, 12($sp)
    sw $s2, 8($sp)

    la $s0, inbuf
    li $a1, 8          # tamanho do buffer
    move $a0, $s0
    li $v0, 8          # syscall read_string
    syscall

    # parse: procurar primeiro caractere não-space
    la $t0, inbuf
    li $t1, 0          # offset
    li $t2, 0          # found flag
parse_loop:
    lb $t3, 0($t0)
    beqz $t3, parse_done      # string terminou sem número
    # se for '\n' ou '\r' sair (string de fim)
    li $t4, 10
    beq $t3, $t4, parse_done
    li $t4, 13
    beq $t3, $t4, parse_done
    # ignorar espaços e tabs
    li $t4, 32
    beq $t3, $t4, parse_skip
    li $t4, 9
    beq $t3, $t4, parse_skip
    # encontrou caractere
    li $t2, 1
    j parse_found
parse_skip:
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j parse_loop

parse_done:
    # não encontrou caractere significativo
    li $v0, -1
    j rm_return

parse_found:
    # $t3 contém o caractere candidato; verificar se é dígito '1'..'9'
    li $t4, 49         # '1'
    li $t5, 57         # '9'
    blt $t3, $t4, rm_invalid
    bgt $t3, $t5, rm_invalid
    # verificar se há apenas caracteres em branco depois (evitar "12", "1a")
    # avança ponteiro para próximo
    addi $t0, $t0, 1
    lb $t6, 0($t0)
    # pular espaços/tabs até newline or null
    parse_trail:
        beqz $t6, parse_trail_done
        li $t7, 10
        beq $t6, $t7, parse_trail_done
        li $t7, 13
        beq $t6, $t7, parse_trail_done
        li $t7, 32
        beq $t6, $t7, parse_trail_skip
        li $t7, 9
        beq $t6, $t7, parse_trail_skip
        # algum outro caractere (ex: letra) => inválido
        j rm_invalid
    parse_trail_skip:
        addi $t0, $t0, 1
        lb $t6, 0($t0)
        j parse_trail
    parse_trail_done:
    # converte char digit em índice
    li $t7, 48
    sub $t8, $t3, $t7   # t8 = digit as integer (1..9)
    addi $t8, $t8, -1   # t8 = index 0..8

    # verificar se posição livre
    la $t9, board
    add $t9, $t9, $t8
    lb $tA, 0($t9)
    bne $tA, $zero, rm_occupied

    # posição livre: retorna índice em $v0
    move $v0, $t8
    j rm_return

rm_invalid:
    li $v0, -1
    j rm_return

rm_occupied:
    li $v0, -2

rm_return:
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addi $sp, $sp, 24
    jr $ra

# -------------------------
# check_win_char
# entrada: $a0 = ASCII char to check (88 = 'X' or 79 = 'O')
# retorno: $v0 = 1 se vence, 0 caso contrário
# -------------------------
check_win_char:
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)

    la $s0, wins       # pointer to wins table
    li $t0, 0          # index in words processed
    li $t1, 24         # total words = 8*3 = 24

check_win_loop:
    beq $t0, $t1, check_win_end
    lw $t2, 0($s0)     # a
    lw $t3, 4($s0)     # b
    lw $t4, 8($s0)     # c

    la $t5, board
    add $t6, $t5, $t2
    lb $t6, 0($t6)
    add $t7, $t5, $t3
    lb $t7, 0($t7)
    add $t8, $t5, $t4
    lb $t8, 0($t8)

    # comparar com $a0 (target char)
    bne $t6, $a0, nxt_triple
    bne $t7, $a0, nxt_triple
    bne $t8, $a0, nxt_triple

    # todos iguais -> win
    li $v0, 1
    j cw_done

nxt_triple:
    addi $s0, $s0, 12   # advance 3 words (12 bytes)
    addi $t0, $t0, 3
    j check_win_loop

check_win_end:
    li $v0, 0

cw_done:
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# -------------------------
# board_full
# retorna $v0 = 1 se cheio, 0 caso contrário
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
# CPU MOVE — estrategia: vencer > bloquear > centro > cantos > primeiro livre
# Retorno: nada (altera board global)
# Salva $s0-$s2 e $ra
# =============================================
cpu_move:
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)

    la $s0, board    # base pointer

    # 1) tentar vencer (colocar 'O' temporariamente e testar)
    li $s1, 0
cpu_try_win_loop:
    beq $s1, 9, cpu_try_block
    add $s2, $s0, $s1
    lb $t0, 0($s2)
    bne $t0, $zero, cpu_win_next
    # tenta 'O'
    li $t1, 79        # 'O'
    sb $t1, 0($s2)
    move $a0, $t1
    jal check_win_char
    beq $v0, $zero, cpu_undo_try_win
    # encontrou jogada vencedora -> já gravada
    j cpu_done_cleanup
cpu_undo_try_win:
    sb $zero, 0($s2)
cpu_win_next:
    addi $s1, $s1, 1
    j cpu_try_win_loop

    # 2) bloquear jogador 'X'
cpu_try_block:
    li $s1, 0
cpu_block_loop:
    beq $s1, 9, cpu_try_center
    add $s2, $s0, $s1
    lb $t0, 0($s2)
    bne $t0, $zero, cpu_block_next
    # tenta 'X' temporario
    li $t1, 88
    sb $t1, 0($s2)
    move $a0, $t1
    jal check_win_char
    beq $v0, $zero, cpu_undo_block_try
    # se for ameaça, colocar 'O' para bloquear
    li $t2, 79
    sb $t2, 0($s2)
    j cpu_done_cleanup
cpu_undo_block_try:
    sb $zero, 0($s2)
cpu_block_next:
    addi $s1, $s1, 1
    j cpu_block_loop

    # 3) centro (index 4)
cpu_try_center:
    la $t3, board
    addi $t4, $t3, 4
    lb $t5, 0($t4)
    bne $t5, $zero, cpu_try_corners
    li $t6, 79
    sb $t6, 0($t4)
    j cpu_done_cleanup

    # 4) cantos 0,2,6,8
cpu_try_corners:
    # canto 0
    la $t3, board
    lb $t7, 0($t3)
    beq $t7, $zero, cpu_put_corner0
    # canto 2
    addi $t8, $t3, 2
    lb $t7, 0($t8)
    beq $t7, $zero, cpu_put_corner2
    # canto 6
    addi $t9, $t3, 6
    lb $t7, 0($t9)
    beq $t7, $zero, cpu_put_corner6
    # canto 8
    addi $s2, $t3, 8
    lb $t7, 0($s2)
    beq $t7, $zero, cpu_put_corner8
    j cpu_try_first_free

cpu_put_corner0:
    li $tA, 79
    sb $tA, 0($t3)
    j cpu_done_cleanup
cpu_put_corner2:
    li $tA, 79
    sb $tA, 0($t8)
    j cpu_done_cleanup
cpu_put_corner6:
    li $tA, 79
    sb $tA, 0($t9)
    j cpu_done_cleanup
cpu_put_corner8:
    li $tA, 79
    sb $tA, 0($s2)
    j cpu_done_cleanup

    # 5) primeira livre
cpu_try_first_free:
    li $s1, 0
cpu_first_free_loop:
    beq $s1, 9, cpu_done_cleanup
    add $s2, $s0, $s1
    lb $t0, 0($s2)
    bne $t0, $zero, cpu_first_free_next
    li $t1, 79
    sb $t1, 0($s2)
    j cpu_done_cleanup
cpu_first_free_next:
    addi $s1, $s1, 1
    j cpu_first_free_loop

cpu_done_cleanup:
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addi $sp, $sp, 24
    jr $ra