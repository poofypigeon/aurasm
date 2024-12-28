    text
    export Vect
Vect    
    mov     lr, 0x10000000
    b       ResetHandler
    b       BusFaultHandler
    b       UsageFaultHandler
    b       SysCallHandler
    b       InstrHandler
    b       SysTickHandler

ResetHandler
        
    
BusFaultHandler
    ; save general register state
    st      r13 [sp] -4
    st      r12 [sp] -4
    st      r11 [sp] -4
    st      r10 [sp] -4
    st      r9  [sp] -4
    st      r8  [sp] -4
    st      r7  [sp] -4
    st      r6  [sp] -4
    st      r5  [sp] -4
    st      r4  [sp] -4
    st      r3  [sp] -4
    st      r2  [sp] -4
    st      r1  [sp] -4
    ; set r13 to base address of saved registers
    mov     r13, sp
    ; switch to system mode
    msr     r1
    btc     r1 0x40
    mrs     r1
    ; load instruction that raised the exception
    ld      r1 [lr - 4]
    ; reconstruct address that triggered fault
    and     r2, r1, 0xF lsl 20  ; mask out base address
    lsr     r2, 20              ; right align
    ld      r2, [r13 + r2]      ; load base address register value




