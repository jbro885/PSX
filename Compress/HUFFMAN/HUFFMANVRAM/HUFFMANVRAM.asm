; PSX 'Bare Metal' HUFFMAN VRAM Decode Demo by krom (Peter Lemon):
.psx
.create "HUFFMANVRAM.bin", 0x80010000

.include "LIB/PSX.INC" ; Include PSX Definitions
.include "LIB/PSX_GPU.INC" ; Include PSX GPU Definitions & Macros

.org 0x80010000 ; Entry Point Of Code

la a0,IO_BASE ; A0 = I/O Port Base Address ($1F80XXXX)

; Setup Screen Mode
WRGP1 GPURESET,0  ; Write GP1 Command Word (Reset GPU)
WRGP1 GPUDISPEN,0 ; Write GP1 Command Word (Enable Display)
WRGP1 GPUDISPM,HRES640+VRES480+BPP24+VNTSC ; Write GP1 Command Word (Set Display Mode: 640x480, 24BPP, NTSC, Vertical Interlace)
WRGP1 GPUDISPH,0xC60260 ; Write GP1 Command Word (Horizontal Display Range 608..3168)
WRGP1 GPUDISPV,0x07E018 ; Write GP1 Command Word (Vertical Display Range 24..504)

; Setup Drawing Area
WRGP0 GPUDRAWM,0x000400   ; Write GP0 Command Word (Drawing To Display Area Allowed Bit 10)
WRGP0 GPUDRAWATL,0x000000 ; Write GP0 Command Word (Set Drawing Area Top Left X1=0, Y1=0)
WRGP0 GPUDRAWABR,0x03BD3F ; Write GP0 Command Word (Set Drawing Area Bottom Right X2=319, Y2=239)
WRGP0 GPUDRAWOFS,0x000000 ; Write GP0 Command Word (Set Drawing Offset X=0, Y=0)

; Memory Transfer
CopyRectCPU 0,0, 960,480 ; Copy Rectangle (CPU To VRAM): X,Y, Width,Height
ori s0,r0,0              ; S0 = DATA Word
ori s1,r0,0              ; S1 = DATA Word Byte Shift Amount
ori s2,r0,24             ; S2 = DATA Word Byte Shift Amount End

la a1,Huff  ; A1 = Source Address

lw t0,0(a1) ; T0 = Data Length & Header Info
addiu a1,4  ; Add 4 To Huffman Offset
srl t0,8    ; T0 = Data Length

lbu t1,0(a1) ; T1 = (Tree Table Size / 2) - 1
addiu a1,1   ; A1 = Tree Table Offset
sll t1,1     ; T1 <<= 1
addiu t1,1   ; T1 = Tree Table Size
addu t1,a1   ; T1 = Compressed Bitstream Offset

subiu a1,5  ; A1 = Source Address
ori t6,r0,0 ; T6 = Branch/Leaf Flag (0 = Branch 1 = Leaf)
ori t7,r0,5 ; T7 = Tree Table Offset (Reset)
HuffChunkLoop:
  lw t2,0(t1)   ; T2 = Node Bits (Bit31 = First Bit)
  addiu t1,4    ; Add 4 To Compressed Bitstream Offset
  lui t3,0x8000 ; T3 = Node Bit Shifter

  HuffByteLoop: 
    beqz t0,HuffEnd ; IF (Data Length == 0) HuffEnd
    addu t4,a1,t7 ; T4 = Tree Table Offset (Delay Slot)
    beqz t3,HuffChunkLoop ; IF (Node Bit Shifter == 0) HuffChunkLoop
    lbu t4,0(t4) ; T4 = Next Node (Delay Slot)
    beqz t6,HuffBranch ; Test T6 Branch/Leaf Flag (0 = Branch 1 = Leaf)
    andi t5,t4,0x3F ; T5 = Offset To Next Child Node (Delay Slot)

    ; Write Bytes As GP0 Packet Words
    sllv t4,s1      ; Data Byte <<= DATA Word Byte Shift Amount
    or s0,t4        ; Store Data Byte To DATA Word IF Leaf
    bne s1,s2,SkipGP0Write
    addiu s1,8      ; DATA Word Byte Shift Amount += 8 (Delay Slot)
    sw s0,GP0(a0)   ; Write GP0 Packet Word
    ori s0,r0,0     ; Reset DATA Word
    ori s1,r0,0     ; Reset DATA Word Byte Shift Amount
    SkipGP0Write:

    subiu t0,1  ; Data Length--
    ori t7,r0,5 ; T7 = Tree Table Offset (Reset)
    j HuffByteLoop
    ori t6,r0,0 ; T6 = Branch (Delay Slot)

    HuffBranch:
      sll t5,1     ; T5 <<= 1
      addiu t5,2   ; T5 = Node0 Child Offset * 2 + 2
      andi t7,-2   ; T7 = Tree Offset NOT 1
      addu t7,t5   ; T7 = Node0 Child Offset
      and t5,t2,t3 ; Test Node Bit (0 = Node0, 1 = Node1)
      beqz t5,HuffNodeEnd
      andi t5,t4,0x80 ; T5 = Test Node0 End Flag (Delay Slot)
      andi t5,t4,0x40 ; T5 = Test Node1 End Flag
      addiu t7,1      ; T7 = Node1 Child Offset + 1
      HuffNodeEnd:
        beqz t5,HuffByteLoop ; Test Node End Flag (1 = Next Child Node Is Data)
        srl t3,1 ; Shift T3 To Next Node Bit (Delay Slot)
        j HuffByteLoop
        ori t6,r0,1 ; T6 = Leaf (Delay Slot)
  HuffEnd:

Loop:
  b Loop
  nop ; Delay Slot

Huff:
  .incbin "Image.huff" ; Include 640x480 24BPP Compressed Image Data (200500 Bytes)

.close