; TX6 LT - Simple606-inspired MDS voice for X.20, version 2.0.
; 44.1 kHz low tom: two damped tonal modes and full-rate filtered noise. NOIS and OVER retain their layer roles.
; Controls start with TUNE, DEC.
;
; MIT License
; 
; Copyright (c) 2026 Matthew Fecher (AnalogMatthew) - Core DSP Engine
; Copyright (c) 2026 Fadedlimes - Plugin Wrapper & Application
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
;
; X state relative to R6:
; 00: remaining
; 01: fp
; 02: sp
; 03: r0
; 04: r1
; 05: d0
; 06: d1
; 07: p0
; 08: cos0
; 09: p1
; 0a: cos1
; 0b: qbase
; 0c: glide
; 0d: b0
; 0e: a1
; 0f: a2
; 10: rng
; 11: z1
; 12: z2
; 13: fast
; 14: slow
; 15: noiseamp
; 16: gatehold
; 17: gatepole
; 18: s0
; 19: c0
; 1a: s1
; 1b: c1
; 1c: lasttone

init:
    move #>$ffffff,m6
    move #>$ffffff,m0
    clr a r6,r0
    do #29,init_end
    move a1,x:(r0)+
init_end:
    move #>$006061,x0
    move x0,x:(r6+$10)
    rts
trigger:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move #>$ffffff,m1
    clr a
    move a1,x:(r6+$11)
    move a1,x:(r6+$12)
    move a1,x:(r6+$15)
    move a1,x:(r6+$1c)
    move y:(r6+$2),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add x0,a
    asl a
    add x0,a
    add #>control_1,a
    move a1,r0
    move r6,a
    move a1,r1
    do #7,control_1_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_1_end:
    move y:(r6+$1),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    asl a
    asl a
    add x0,a
    add #>control_2,a
    move a1,r0
    move r6,a
    add #>7,a
    move a1,r1
    do #9,control_2_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_2_end:
    move #>$26c493,x0
    move x0,x:(r6+$18)
    move #>$059833,x0
    move x0,x:(r6+$1a)
    move x:(r6+$3),x0
    move x:(r6+$8),y0
    mpyr y0,x0,a
    move a1,x:(r6+$19)
    move x:(r6+$4),x0
    move x:(r6+$a),y0
    mpyr y0,x0,a
    move a1,x:(r6+$1b)
    move y:(r6+$3),a
    asr #7,a,a
    and #>$7e,a
    add #>layer_table,a
    move a1,r0
    move p:(r0)+,x0
    move x0,x:(r6+$13)
    move p:(r0)+,x0
    move x0,x:(r6+$14)
    move y:(r6+$4),a
    asr #7,a,a
    cmp #>127,a
    jeq over_done
    asl #16,a,a
    move a1,y0
    move x:(r6+$1a),x0
    mpyr y0,x0,a
    move a1,x:(r6+$1a)
    move x:(r6+$9),x0
    mpyr y0,x0,a
    move a1,x:(r6+$9)
over_done:
    rts
render:
    move #>$ffffff,m6
    move x:(r6+$0),a
    tst a
    jeq silent
    sub #>1,a
    move a1,x:(r6+$0)
    move x:(r6+$b),a
    move x:(r6+$c),x0
    add x0,a
    move a1,x1
    move #>$7e2da6,y0
    mpyr y0,x0,a
    move a1,x:(r6+$c)
    move x1,x0
    mpy x0,x0,a
    asr a
    neg a
    add #>$7fffff,a
    move a1,y0
    move x:(r6+$3),x0
    mpyr y0,x0,a
    move a1,x:(r6+$19)
    move x:(r6+$10),x0
    move #>$400000,y1
    move #>$fd43fd,y0
    move #>mds_scratch_y,r5
    do #32,noise_end
    mpy y0,x0,a
    asr #1,a,a
    move a0,a
    add #>$c39ec3,a
    move a1,x0
    mpy x0,y1,a
    move a1,y:(r5)+
noise_end:
    move x0,x:(r6+$10)
    move #>mds_scratch_x,r3
    move x:(r6+$d),x0
    move x0,x:(r3)+
    move x:(r6+$e),x0
    move x0,x:(r3)+
    move x:(r6+$f),x0
    move x0,x:(r3)+
    move x:(r6+$11),b
    move x:(r6+$12),x1
    move #>$fffffd,n3
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #32,filter_end
    move x:(r3)+,x0 y:(r5),y0
    mpy y0,x0,a x:(r3)+,x0
    asl a
    add b,a a1,y0
    move a1,y1
    mpy x0,y1,a a1,y:(r5)+
    move x:(r3)+,x0
    asl a x1,b
    add b,a (r3)+n3
    mpy x0,y1,a a1,b
    asl a
    sub y0,a
    move a1,x1
filter_end:
    move b1,x:(r6+$11)
    move x1,x:(r6+$12)
    move #>mds_scratch_x,r4
    move x:(r6+$18),x0
    move x:(r6+$7),x1
    move x:(r6+$19),y0
    move x:(r6+$5),y1
    do #32,tone0_end
    mpy y0,x0,a
    mac -y1,x1,a x0,x1
    asl a
    move a1,x0
    move a1,x:(r4)+
tone0_end:
    move x0,x:(r6+$18)
    move x1,x:(r6+$7)
    move #>mds_scratch_x,r4
    move x:(r6+$1a),x0
    move x:(r6+$9),x1
    move x:(r6+$1b),y0
    move x:(r6+$6),y1
    do #32,tone1_end
    mpy y0,x0,a
    mac -y1,x1,a x0,x1
    asl a
    rnd a x:(r4),b
    add b,a a1,x0
    move a1,x:(r4)+
tone1_end:
    move x0,x:(r6+$1a)
    move x1,x:(r6+$9)
    move x:(r6+$13),x0
    move x:(r6+$1),y0
    mpyr y0,x0,a
    move a1,x:(r6+$13)
    move x:(r6+$14),x0
    move x:(r6+$2),y0
    mpyr y0,x0,a
    move a1,x:(r6+$14)
    move x:(r6+$13),x0
    move x:(r6+$14),a
    add x0,a
    move x:(r6+$15),x0
    move a1,b
    move b1,x:(r6+$15)
    add x0,b
    asr b
    move b1,x0
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #32,mix_end
    move x:(r3)+,x1 y:(r5)+,y0
    mpy y0,x0,a
    add x1,a
    move a,y:(r7)+
mix_end:
    rts
silent:
    clr a
    do #32,zero_end
    move a,y:(r7)+
zero_end:
    rts
control_1:
    .dc $000023,$007cf1,$4956ce,$7ec824,$4befd6,$3ec9a0,$168668,$000023
    .dc $007cf1,$4956ce,$7ec824,$4befd6,$3ec9a0,$168668,$000023,$007cf1
    .dc $4956ce,$7ec824,$4befd6,$3ec9a0,$168668,$000023,$007cf1,$4956ce
    .dc $7ec824,$4befd6,$3ec9a0,$168668,$00002c,$018a11,$52442d,$7f0838
    .dc $54922b,$3f0927,$1bf040,$000037,$03b9ff,$59defb,$7f39a0,$5be12d
    .dc $3f3a39,$20f9dc,$000042,$06b802,$5f53d5,$7f5a9a,$611981,$3f5b05
    .dc $24d456,$00004d,$0a3c74,$636d36,$7f722e,$650242,$3f727d,$27dac8
    .dc $000058,$0e0971,$669dc1,$7f83e0,$680b2e,$3f841c,$2a4916,$000063
    .dc $11f1c8,$692ae9,$7f91a4,$6a778d,$3f91d4,$2c4739,$00006e,$15d71d
    .dc $6b411b,$7f9ca9,$6c723d,$3f9cd0,$2df096,$000078,$19a62b,$6cfe0d
    .dc $7fa5ae,$6e17cc,$3fa5ce,$2f5876,$000083,$1d5369,$6e7658,$7fad32
    .dc $6f7bfc,$3fad4d,$308cc0,$00008e,$20d87d,$6fb8b4,$7fb38f,$70ace2
    .dc $3fb3a6,$3197bb,$000099,$243271,$70cff0,$7fb903,$71b4d2,$3fb917
    .dc $328121,$0000a4,$276081,$71c425,$7fbdbe,$729b84,$3fbdcf,$334ee0
    .dc $0000af,$2a6343,$729b84,$7fc1e1,$7366e0,$3fc1f0,$340597,$0000ba
    .dc $2d3c23,$735ae0,$7fc587,$741b7b,$3fc595,$34a8ea,$0000c5,$2fed07
    .dc $740605,$7fc8c6,$74bcf2,$3fc8d2,$353bc7,$0000d0,$327812,$749ffd
    .dc $7fcbae,$754e28,$3fcbb8,$35c088,$0000db,$34df7f,$752b3e,$7fce4b
    .dc $75d173,$3fce55,$36391e,$0000e6,$372587,$75a9cb,$7fd0a8,$7648bc
    .dc $3fd0b1,$36a722,$0000f0,$394c57,$761d4d,$7fd2cf,$76b595,$3fd2d7
    .dc $370be6,$0000fb,$3b5601,$768728,$7fd4c6,$77194f,$3fd4cd,$37688a
    .dc $000106,$3d447b,$76e883,$7fd692,$777503,$3fd699,$37bdfe,$000111
    .dc $3f1999,$77425b,$7fd83a,$77c99f,$3fd841,$380d10,$00011c,$40d714
    .dc $779586,$7fd9c2,$7817ee,$3fd9c8,$385671,$000127,$427e81,$77e2bc
    .dc $7fdb2c,$78609e,$3fdb32,$389ab8,$000132,$441159,$782a9b,$7fdc7d
    .dc $78a444,$3fdc82,$38da69,$00013d,$4590fb,$786dab,$7fddb6,$78e362
    .dc $3fddbb,$3915f6,$000148,$46fea6,$78ac65,$7fdedb,$791e68,$3fdedf
    .dc $394dc2,$000153,$485b86,$78e730,$7fdfec,$7955ba,$3fdff0,$398227
    .dc $00015e,$49a8ac,$791e68,$7fe0ed,$7989ae,$3fe0f0,$39b370,$000168
    .dc $4ae716,$79525f,$7fe1de,$79ba8f,$3fe1e1,$39e1e3,$000173,$4c17ae
    .dc $79835c,$7fe2c0,$79e8a3,$3fe2c4,$3a0dbd,$00017e,$4d3b4c,$79b19e
    .dc $7fe396,$7a1425,$3fe399,$3a3734,$000189,$4e52b9,$79dd5e,$7fe460
    .dc $7a3d4a,$3fe463,$3a5e79,$000194,$4f5ead,$7a06cf,$7fe51f,$7a6442
    .dc $3fe522,$3a83b6,$00019f,$505fd5,$7a2e1f,$7fe5d4,$7a8939,$3fe5d7
    .dc $3aa714,$0001aa,$5156ce,$7a5377,$7fe680,$7aac55,$3fe682,$3ac8b5
    .dc $0001b5,$52442d,$7a76fb,$7fe723,$7acdb9,$3fe725,$3ae8b9,$0001c0
    .dc $53287b,$7a98ce,$7fe7be,$7aed84,$3fe7c1,$3b073e,$0001cb,$540436
    .dc $7ab90c,$7fe852,$7b0bd4,$3fe854,$3b245e,$0001d5,$54d7d6,$7ad7d3
    .dc $7fe8df,$7b28c1,$3fe8e1,$3b4030,$0001e0,$55a3c8,$7af53b,$7fe966
    .dc $7b4464,$3fe968,$3b5aca,$0001eb,$566874,$7b115a,$7fe9e6,$7b5ed3
    .dc $3fe9e8,$3b7442,$0001f6,$572639,$7b2c47,$7fea61,$7b7820,$3fea63
    .dc $3b8ca7,$000207,$5836b4,$7b5294,$7feb10,$7b9c1e,$3feb11,$3baf64
    .dc $00020c,$588e71,$7b5ed3,$7feb48,$7ba7a0,$3feb49,$3bba81,$000217
    .dc $593987,$7b7694,$7febb4,$7bbdf2,$3febb5,$3bd013,$000222,$59defb
    .dc $7b8d65,$7fec1c,$7bd363,$3fec1d,$3be4cf,$00022d,$5a7f13,$7ba356
    .dc $7fec7f,$7be800,$3fec81,$3bf8c2,$000238,$5b1a10,$7bb873,$7fecdf
    .dc $7bfbd6,$3fece1,$3c0bf7,$000243,$5bb02e,$7bccc7,$7fed3c,$7c0eef
    .dc $3fed3d,$3c1e78,$00024d,$5c41a6,$7be05d,$7fed95,$7c2155,$3fed96
    .dc $3c304f,$000258,$5cceaf,$7bf340,$7fedea,$7c3313,$3fedec,$3c4185
    .dc $000263,$5d577a,$7c0579,$7fee3d,$7c4431,$3fee3e,$3c5222,$00026e
    .dc $5ddc38,$7c1711,$7fee8d,$7c54b8,$3fee8e,$3c622e,$000279,$5e5d15
    .dc $7c2810,$7feeda,$7c64af,$3feedb,$3c71b1,$000284,$5eda3c,$7c387d
    .dc $7fef24,$7c741d,$3fef25,$3c80b1,$00028f,$5f53d5,$7c4861,$7fef6c
    .dc $7c8309,$3fef6d,$3c8f34,$00029a,$5fca05,$7c57c1,$7fefb2,$7c917a
    .dc $3fefb3,$3c9d41,$0002a5,$603cf1,$7c66a4,$7feff5,$7c9f75,$3feff6
    .dc $3caadd,$0002b5,$60e37c,$7c7c1a,$7ff056,$7cb39d,$3ff057,$3cbe7f
control_2:
    .dc $2727f7,$7ffdc3,$04df04,$7ff4cd,$012279,$005c86,$0217dc,$7b87b9
    .dc $c42fb8,$272a20,$7ffdaa,$04daf3,$7ff44e,$0128d5,$005e8d,$02232f
    .dc $7b6deb,$c4465e,$272c55,$7ffd8f,$04d6cc,$7ff3ca,$012f55,$00609f
    .dc $022ebd,$7b5384,$c45d7a,$272e96,$7ffd73,$04d28d,$7ff33f,$0135f9
    .dc $0062bc,$023a87,$7b3881,$c4750e,$2730e4,$7ffd57,$04ce36,$7ff2af
    .dc $013cc3,$0064e6,$02468e,$7b1cde,$c48d1c,$27333f,$7ffd38,$04c9c6
    .dc $7ff218,$0143b2,$00671b,$0252d3,$7b0097,$c4a5a6,$2735a6,$7ffd19
    .dc $04c53e,$7ff17a,$014ac9,$00695d,$025f57,$7ae3a8,$c4beaf,$27381b
    .dc $7ffcf8,$04c09c,$7ff0d6,$015207,$006bac,$026c1c,$7ac60d,$c4d839
    .dc $273a9e,$7ffcd6,$04bbe0,$7ff02a,$01596e,$006e07,$027923,$7aa7c3
    .dc $c4f246,$273d2e,$7ffcb2,$04b70a,$7fef76,$0160fe,$007070,$02866d
    .dc $7a88c3,$c50cd9,$273fcc,$7ffc8c,$04b218,$7feebb,$0168b9,$0072e7
    .dc $0293fa,$7a690c,$c527f4,$274279,$7ffc65,$04ad0a,$7fedf7,$01709f
    .dc $00756b,$02a1cd,$7a4897,$c5439a,$274534,$7ffc3c,$04a7e0,$7fed2b
    .dc $0178b1,$0077fd,$02afe6,$7a2760,$c55fcd,$2747ff,$7ffc12,$04a298
    .dc $7fec55,$0180f1,$007a9d,$02be47,$7a0563,$c57c8f,$274ad8,$7ffbe5
    .dc $049d33,$7feb77,$01895f,$007d4d,$02ccf1,$79e29b,$c599e3,$274dc2
    .dc $7ffbb7,$0497b0,$7fea8e,$0191fc,$00800b,$02dbe6,$79bf02,$c5b7cc
    .dc $2750bb,$7ffb86,$04920d,$7fe99b,$019ac9,$0082d9,$02eb26,$799a95
    .dc $c5d64b,$2753c5,$7ffb53,$048c4b,$7fe89d,$01a3c8,$0085b6,$02fab2
    .dc $79754c,$c5f565,$2756e0,$7ffb1e,$048668,$7fe794,$01acf9,$0088a4
    .dc $030a8d,$794f24,$c6151a,$275a0b,$7ffae7,$048064,$7fe67f,$01b65e
    .dc $008ba2,$031ab7,$792817,$c6356f,$275d48,$7ffaad,$047a3e,$7fe55e
    .dc $01bff7,$008eb1,$032b33,$79001f,$c65665,$276097,$7ffa71,$0473f5
    .dc $7fe430,$01c9c6,$0091d1,$033c00,$78d736,$c67800,$2763f8,$7ffa32
    .dc $046d89,$7fe2f5,$01d3cc,$009502,$034d21,$78ad57,$c69a41,$27676b
    .dc $7ff9f0,$0466f8,$7fe1ac,$01de0b,$009845,$035e96,$78827b,$c6bd2d
    .dc $276af1,$7ff9ab,$046043,$7fe054,$01e882,$009b9b,$037062,$78569c
    .dc $c6e0c5,$276e8b,$7ff964,$045967,$7fdeee,$01f335,$009f03,$038286
    .dc $7829b4,$c7050c,$277238,$7ff919,$045265,$7fdd77,$01fe23,$00a27e
    .dc $039503,$77fbbc,$c72a06,$2775f9,$7ff8ca,$044b3b,$7fdbef,$02094e
    .dc $00a60d,$03a7da,$77ccaf,$c74fb4,$2779cf,$7ff879,$0443e9,$7fda57
    .dc $0214b9,$00a9b0,$03bb0d,$779c83,$c7761a,$277dba,$7ff823,$043c6e
    .dc $7fd8ac,$022063,$00ad67,$03ce9e,$776b34,$c79d3b,$2781ba,$7ff7ca
    .dc $0434c8,$7fd6ee,$022c4e,$00b133,$03e28d,$7738b9,$c7c51a,$2785d0
    .dc $7ff76d,$042cf7,$7fd51d,$02387d,$00b515,$03f6dc,$77050b,$c7edb9
    .dc $2789fc,$7ff70c,$0424fa,$7fd337,$0244f0,$00b90c,$040b8e,$76d023
    .dc $c8171b,$278e3f,$7ff6a7,$041cd0,$7fd13b,$0251a8,$00bd19,$0420a2
    .dc $7699f8,$c84144,$279299,$7ff63d,$041478,$7fcf2a,$025ea8,$00c13d
    .dc $04361b,$766283,$c86c36,$27970b,$7ff5ce,$040bf0,$7fcd00,$026bf0
    .dc $00c578,$044bfa,$7629bc,$c897f3,$279b95,$7ff55a,$040338,$7fcabe
    .dc $027983,$00c9cb,$046240,$75ef9a,$c8c480,$27a037,$7ff4e2,$03fa4f
    .dc $7fc863,$028763,$00ce37,$0478f0,$75b415,$c8f1df,$27a4f3,$7ff464
    .dc $03f134,$7fc5ed,$02958f,$00d2ba,$049009,$757723,$c92013,$27a9c8
    .dc $7ff3e0,$03e7e5,$7fc35b,$02a40c,$00d758,$04a78f,$7538bc,$c94f1e
    .dc $27aeb8,$7ff357,$03de62,$7fc0ac,$02b2d9,$00dc0f,$04bf82,$74f8d6
    .dc $c97f04,$27b3c2,$7ff2c7,$03d4a9,$7fbdde,$02c1fa,$00e0e0,$04d7e4
    .dc $74b768,$c9afc8,$27b8e8,$7ff231,$03cab8,$7fbaf1,$02d16f,$00e5cd
    .dc $04f0b6,$747469,$c9e16c,$27be29,$7ff195,$03c090,$7fb7e2,$02e13b
    .dc $00ead5,$0509fa,$742fcd,$ca13f3,$27c387,$7ff0f2,$03b62e,$7fb4b1
    .dc $02f160,$00effa,$0523b0,$73e98c,$ca4761,$27c902,$7ff047,$03ab91
    .dc $7fb15c,$0301df,$00f53b,$053ddc,$73a19a,$ca7bb7,$27ce9a,$7fef95
    .dc $03a0b9,$7fade1,$0312ba,$00fa9a,$05587d,$7357ec,$cab0fa,$27d737
    .dc $7fee7a,$039000,$7fa85e,$032cb5,$0102e0,$05814f,$72e611,$cb029e
    .dc $27da25,$7fee18,$038a4e,$7fa673,$03358e,$0105b2,$058f26,$72bf33
    .dc $cb1e4d,$27e01a,$7fed4d,$037eb9,$7fa27d,$03478c,$010b6d,$05ab32
    .dc $727010,$cb5663,$27e62e,$7fec79,$0372e3,$7f9e59,$0359ee,$011148
    .dc $05c7b8,$721f05,$cb8f70,$27ec63,$7feb9c,$0366c9,$7f9a07,$036cb6
    .dc $011744,$05e4bb,$71cc03,$cbc976,$27f2b9,$7feab5,$035a6b,$7f9584
    .dc $037fe9,$011d61,$06023c,$717700,$cc0478,$27f931,$7fe9c4,$034dc7
    .dc $7f90ce,$039387,$0123a1,$06203c,$711fef,$cc4079,$27ffcc,$7fe8c8
    .dc $0340dc,$7f8be2,$03a792,$012a04,$063ebd,$70c6c1,$cc7d7a,$28068a
    .dc $7fe7c1,$0333a7,$7f86bf,$03bc0f,$01308a,$065dbf,$706b6b,$ccbb7e
    .dc $280d6c,$7fe6ae,$032628,$7f8161,$03d0fd,$013736,$067d44,$700dde
    .dc $ccfa87,$281472,$7fe58f,$03185c,$7f7bc7,$03e662,$013e06,$069d4c
    .dc $6fae0c,$cd3a98,$281b9e,$7fe463,$030a42,$7f75ee,$03fc3e,$0144fd
    .dc $06bdda,$6f4be7,$cd7bb3,$2822f1,$7fe32a,$02fbd9,$7f6fd2,$041295
    .dc $014c1b,$06deed,$6ee760,$cdbdda,$282a6a,$7fe1e3,$02ed1d,$7f6971
    .dc $042968,$015360,$070087,$6e8068,$ce010e,$28320a,$7fe08e,$02de0e
    .dc $7f62c8,$0440bc,$015acf,$0722a9,$6e16ef,$ce4552,$2839d3,$7fdf2a
    .dc $02ceaa,$7f5bd4,$045893,$016267,$074553,$6daae6,$ce8aa6,$2845ce
    .dc $7fdcf5,$02b6f0,$7f50d0,$047d50,$016e1b,$077a55,$6d03e6,$cef4a9
layer_table:
    .dc $000000,$000000,$01999a,$0023d7,$033333,$0047ae,$04cccd,$006b85
    .dc $066666,$008f5c,$080000,$00b333,$09999a,$00d70a,$0b3333,$00fae1
    .dc $0ccccd,$011eb8,$0e6666,$01428f,$100000,$016666,$11999a,$018a3e
    .dc $133333,$01ae15,$14cccd,$01d1ec,$166666,$01f5c3,$180000,$02199a
    .dc $19999a,$023d71,$1b3333,$026148,$1ccccd,$02851f,$1e6666,$02a8f6
    .dc $200000,$02cccd,$219999,$02f0a4,$233333,$03147b,$24cccd,$033852
    .dc $266666,$035c29,$280000,$038000,$299999,$03a3d7,$2b3333,$03c7ae
    .dc $2ccccd,$03eb85,$2e6666,$040f5c,$300000,$043333,$319999,$04570a
    .dc $333333,$047ae2,$34cccd,$049eb9,$366666,$04c290,$380000,$04e667
    .dc $399999,$050a3e,$3b3333,$052e15,$3ccccd,$0551ec,$3e6666,$0575c3
    .dc $400000,$05999a,$419999,$05bd71,$433333,$05e148,$44cccd,$06051f
    .dc $466666,$0628f6,$480000,$064ccd,$499999,$0670a4,$4b3333,$06947b
    .dc $4ccccc,$06b852,$4e6666,$06dc29,$500000,$070000,$519999,$0723d7
    .dc $533333,$0747ae,$54cccc,$076b85,$566666,$078f5d,$580000,$07b334
    .dc $599999,$07d70b,$5b3333,$07fae2,$5ccccc,$081eb9,$5e6666,$084290
    .dc $600000,$086667,$619999,$088a3e,$633333,$08ae15,$666666,$08f5c3
