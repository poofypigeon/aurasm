    .text
    .export start
start:
    mov32 r1, my_string
    bl strlen
    bl fibonacci
end:
    b end

; r1 holds pointer to string in memory
; length of string is returned in r1
strlen:
    mov r13, r1     ; move string pointer to scratch
    mvi r1, 0       ; initialize counter
strlen_loop:
    ld r2, [r13] + 1
    cmp r2, 0
    beq lr
    add r1, r1, 1
    b strlen_loop
    
; returns fibonacci number where r1 hold the number of iterations to run
; result is returned in r1
fibonacci:
    mov r13, r1     ; move iteration count to scratch
    mvi r1, 1       ; most recent fibonacci number
    mvi r2, 1       ; second most recent
    cmp r13, 0
fibonacci_loop:
    beq lr          ; break if iterations reached
    add r2, r1, r2
    xor r1, r1, r2  ; swap in place
    xor r2, r2, r1
    xor r1, r1, r2
    sub r13, r13, 1 ; decrement iteration counter
    b fibonacci_loop

    .export multiply
multiply:
    mov r3, r1
    mvi r13, -1
    mvi r1, 0
multiply_loop:
    add r13, r13, 1
    lsr r3, r3, 1
    bcc multiply_loop
    addx r1, r1, r2 lsl r13
    bne multiply_loop
    b lr
   
    .data
my_string
    .word * .string "here is a string"
