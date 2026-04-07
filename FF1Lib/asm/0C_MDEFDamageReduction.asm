;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  BtlMag_ApplyDamage  [$B8DB :: 0x338EB]
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BtlMag_ApplyDamage:
    LDA math_magrandhit
    CMP #200
    BEQ :+                          ; if the hit/crit roll was 200, this is NOT a crit
      JSR BtlMag_DidSpellConnect    ; See if the spell connected as a critical
      BCC :+                        ; if yes...
        ASL math_basedamage         ; ... do 2x damage
        ROL math_basedamage+1

  : LDA #MATHBUF_MAGDEFENDERHP
    LDX #MATHBUF_MAGDEFENDERHP
    LDY #MATHBUF_BASEDAMAGE
    JSR MathBuf_Sub16               ; HP -= damage
    JMP DrawDamageCombatBox         ; Then draw the damage combat box and exit.



    // load defender mdef detection
    LDA btlmag_defender_magdef      ; load defender magic defense
    // MDEF damage reduction
    BCC :+
      LDA #$FF                      ; (cap at 255)
  : STA btlmag_defender_magdef      ; that's our new MDef!

    LDA math_basedamage             ; get damage
    ADC #$XX                        ; add value to it
    BCC :+
      LDA #$FF                      ; (cap at 255)
  : STA btlmag_defender_absorb      ; that's our new absorb!
















BtlMag_ApplyDamage:
    LDA math_magrandhit
    CMP #200
    BEQ :+                          ; if the hit/crit roll was 200, this is NOT a crit
      JSR BtlMag_DidSpellConnect    ; See if the spell connected as a critical
    BCC :+                        ; if yes...
      ASL math_basedamage         ; ... do 2x damage
      ROL math_basedamage+1
  : LDA #$A7                        ; High byte of Relocated_AbsorbUp
    PHA
    LDA #$B7                        ; Low byte of Relocated_AbsorbUp
    PHA
    LDA #$1C                        ; Load new bank
    JMP SwapPRG
    NOP


    AbsorbBankSwap:
    LDA #$XX                        ; Low byte of DrawDamageCombatBox
    PHA
    LDA #$XX                        ; High byte of DrawDamageCombatBox
    PHA
    LDA #$0C                        ; Load new bank
    JMP SwapPRG


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  MathBuf_Sub16 [$AEAC :: 0x32EBC]
;;
;;  Subtracts two 16-bit value in the math buffer.  Stores result in math buffer.
;;
;;  input:  A = index of math buffer to receive result
;;        X,Y = indexes of math buffer to subtract   (A = X-Y)
;;
;;     Code is same as MathBuf_Add16.  See that routine for details, comments here are sparse.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MathBuf_Sub16:
    PHA
    JSR DoubleXAndY
    
    LDA btl_mathbuf, X
    SEC
    SBC btl_mathbuf, Y
    STA $6BCF
    
    LDA btl_mathbuf+1, X
    SBC btl_mathbuf+1, Y
    STA $6BD0
    
    BCS :+
      LDA #$00
      STA $6BCF
      STA $6BD0
      
  : PLA
    ASL A
    TAX
    LDA $6BCF
    STA btl_mathbuf, X
    LDA $6BD0
    STA btl_mathbuf+1, X
    RTS