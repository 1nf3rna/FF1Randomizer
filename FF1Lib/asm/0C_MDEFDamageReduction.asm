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

  :+
  LDA #$XX                        ; High byte of Relocated_AbsorbUp
  PHA
  LDA #$XX                        ; Low byte of Relocated_AbsorbUp
  PHA
  LDA #$1C                        ; Load new bank
  JMP SwapPRG
  NOP


  LDA battle_defenderisplayer
  BEQ @BtlMag_ApplyDamageBankSwap ; skip if defender is enemy

  LDA battle_defenderisplayer
  BNE @BtlMag_ApplyDamageBankSwap ; skip if defender is player


  // subtract MDEF from damage
  SEC
  LDA math_basedamage             ; load damage dealt low byte
  SBC btlmag_defender_magdef      ; subtract defender magic defense
  STA math_basedamage             ; store damage
  LDA math_basedamage+1           ; load damage dealt high byte
  SBC #$00                        ; subtract borrow
  STA math_basedamage+1           ; store damage
  BCS :+
    LDA #$01
    STA math_basedamage             ; store damage
    LDA #$00
    STA math_basedamage+1           ; store damage
          

  // Clamp btlmag_defender_magdef to max reduction
  LDA #$XX                        ; load max reduction
  CMP btlmag_defender_magdef      ; compare to defender magic defense
  BCS use_value                   ; branch if max < magdef
  LDA btlmag_defender_magdef      ; load defender magic defense
use_value:
  STA temp8                       ; store reduction value
  SEC
  LDA math_basedamage             ; load damage dealt low byte
  SBC temp8                       ; subtract reduction value
  STA math_basedamage             ; store damage
  LDA math_basedamage+1           ; load damage dealt high byte
  SBC #$00                        ; subtract borrow
  STA math_basedamage+1           ; store damage
  BCS :+
    LDA #$01
    STA math_basedamage             ; store damage
    LDA #$00
    STA math_basedamage+1           ; store damage


  // subtract percentage of MDEF from damage
  LDA btlmag_defender_magdef
  STA temp
  LDA #$00
  STA temp_hi
  LDX percent

  ; simple multiply (8x8 → high byte only)
  LDY #8
mul:
  LSR X
  BCC skip
  CLC
  ADC temp
skip:
  ROR A
  DEY
  BNE mul

  ; A now = (btlmag_defender_magdef * percent) / 256

  SEC
  LDA math_basedamage
  SBC A
  STA math_basedamage

  LDA math_basedamage+1
  SBC #$00
  STA math_basedamage+1
  BCS :+
    LDA #$01
    STA math_basedamage             ; store damage
    LDA #$00
    STA math_basedamage+1           ; store damage


  // Progressive damage reduction
brackets
[0-x]               0 reduction
[x-y]               /2 reduction
[y-z]               /4 reduction
[z-a]               /8 reduction
[a-b]               /16 reduction
[b-c]               /32 reduction
[c-d]               /64 reduction
[d-e]               /128 reduction
[e-255]             /256 reduction
bracketCounter
runningMDEFTotal
remainingMDEF
MDEFChunk

Y = running LUT index
X = loop counter

loadDefenderMDEF:
  LDY #$00
  STY runningMDEFTotal            ; zero running total
  LDA btlmag_defender_magdef      ; load defender mdef into A
  STA remainingMDEF               ; store A in remaining

loadBracket:
  //copy Y to X
  TYA
  TAX
  LDA bracket_lut,Y               ; load mdef bracket chunk value
  STA MDEFChunk                   ; store chunk

checkRemaining:
  LDA remainingMDEF               ; load remaining
  CMP MDEFChunk                   ; compare remaining to chunk
  BMI setupRemaining              ; skip subtract if remaining < chunk

subtractChunk:
  SEC                             ; set carry for subtraction
  SBC MDEFChunk                   ; subtract chunk from remaining
  STA remainingMDEF               ; store reduced remaining
  LDA MDEFChunk                   ; load MDEFChunk into A
  BNE ShiftLoop                   ; branch to shift loop

setupRemaining:
  STA MDEFChunk                   ; store remaining in MDEFChunk
  LDA #$00
  STA remainingMDEF               ; zero remaining
  STA MDEFChunk                   ; load MDEFChunk

ShiftLoop:
  CPX #$00                        ; check if counter = 0
  BEQ :
    LSR A                         ; right shift A
    DEX                           ; reduce counter
    JMP ShiftLoop                 ; return to start of subroutine
  CLC
  ADC runningMDEFTotal            ; add chunk percent to A
  STA runningMDEFTotal            ; store total mdef
  LDA remainingMDEF               ; load remaining
  CMP #$00                        ; check if remaining = 0
  BEQ :
    INC Y                         ; increment lut index
    JMP loadBracket               ; return to start of MDEF processing

  SEC
  LDA math_basedamage           ; load damage dealt low byte
  SBC runningMDEFTotal          ; subtract reduction value
  STA math_basedamage           ; store damage
  LDA math_basedamage+1         ; load damage dealt high byte
  SBC #$00                      ; subtract borrow
  STA math_basedamage+1         ; store damage
  BCS :+
    LDA #$01
    STA math_basedamage             ; store damage
    LDA #$00
    STA math_basedamage+1           ; store damage


  :+
  LDA #MATHBUF_MAGDEFENDERHP
  LDX #MATHBUF_MAGDEFENDERHP
  LDY #MATHBUF_BASEDAMAGE
  JSR MathBuf_Sub16               ; HP -= damage
  JMP DrawDamageCombatBox         ; Then draw the damage combat box and exit.

BtlMag_ApplyDamageBankSwap:
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 56

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  DoubleXAndY [$AF5D :: 0x32F6D]
;;
;;  X *= 2
;;  Y *= 2
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DoubleXAndY:
    TXA     ; Double X!
    ASL A
    TAX
    
    TYA     ; Double Y!
    ASL A
    TAY
    
    RTS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 44
;;
;;  BtlMag_DidSpellConnect  [$B87E :: 0x3388E]
;;
;;    Sets C if a spell connects with its target, or clears C if it misses
;;
;;  input:  math_hitchance  = chance for the spell to connect
;;          math_magrandhit = random number between 0,200
;;
;;  output: C = set if spell connected
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BtlMag_DidSpellConnect:
    LDY #MATHBUF_HITCHANCE      ; compare hit chance
    LDX #MATHBUF_MAGRANDHIT     ; to mag rand hit
    JMP MathBuf_Compare

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  MathBuf_Compare [$ADEA :: 0x32DFA]
;;
;;  Compares two entries in the math buffer.
;;
;;  input:  X,Y = indexes of math buffer to compare
;;
;;  output:   C = set if Y >= X, clear if Y < X
;;            N = set if high byte of Y < high byte of X
;;
;;            All other flags are cleared.... **INCLUDING THE I FLAG**.  This is very strange.
;;         Since IRQs are not used by the game, this doesn't matter.  But still, very strange.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MathBuf_Compare:
    JSR DoubleXAndY         ; Double X,Y so we can use them as proper indexes
    LDA btl_mathbuf+1, Y    ; Get high byte of Y entry
    CMP btl_mathbuf+1, X    ; Compare to high byte of X entry
    BEQ :+                  ;  if not equal...
      PHP
      PLA
      AND #$81              ; preserve NC flags, but clear all other flags
      PHA
      PLP
      RTS                   ; and exit
    
  : LDA btl_mathbuf, Y      ; if high bytes were equal, compare low bytes
    CMP btl_mathbuf, X
    PHP
    PLA
    AND #$01                ; this time, only preserve the C flag
    PHA
    PLP
    RTS