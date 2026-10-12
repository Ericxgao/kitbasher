; TX6 LT - Simple606-inspired MDS voice for X.20, version 2.0.
; New layer controls preserve version 1.0 audio at their defaults.
; NOIS: 0 = remove this layer; 127 = original layer level. Captured on trigger.
; OVER: 0 = remove this layer; 127 = original layer level. Captured on trigger.
; Controls: TUNE first, DEC second. Version 1.x kits need parameter remapping.
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

; Local instruction compaction; verify against retained native audio.
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
    do #16,tone0_end
    mpy y0,x0,a
    mac -y1,x1,a x0,x1
    asl a
    rnd a
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
    do #16,tone1_end
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
    move x:(r6+$1c),r2
    do #16,mix_end
    move x:(r3)+,b
    move r2,a
    add b,a
    asr a
    move a1,x1
    move y:(r5)+,y0
    mpy y0,x0,a
    add x1,a
    move a,y:(r7)+
    move b1,x1
    move b1,r2
    move y:(r5)+,y0
    mpy y0,x0,a
    add x1,a
    move a,y:(r7)+
mix_end:
    move r2,x:(r6+$1c)
    rts
silent:
    clr a
    do #32,zero_end
    move a,y:(r7)+
zero_end:
    rts
control_1:
    .dc $000023,$007cf1,$4956ce,$7d9340,$2d0cd0,$3d9921,$07ed82,$000023
    .dc $007cf1,$4956ce,$7d9340,$2d0cd0,$3d9921,$07ed82,$000023,$007cf1
    .dc $4956ce,$7d9340,$2d0cd0,$3d9921,$07ed82,$000023,$007cf1,$4956ce
    .dc $7d9340,$2d0cd0,$3d9921,$07ed82,$00002c,$018a11,$52442d,$7e124f
    .dc $37e07f,$3e1607,$0c323c,$000037,$03b9ff,$59defb,$7e7473,$41f3b8
    .dc $3e76d6,$10fdab,$000042,$06b802,$5f53d5,$7eb60a,$49a8ac,$3eb7b4
    .dc $1531a1,$00004d,$0a3c74,$636d36,$7ee4f9,$4fb590,$3ee632,$18d190
    .dc $000058,$0e0971,$669dc1,$7f0838,$54922b,$3f0927,$1bf040,$000063
    .dc $11f1c8,$692ae9,$7f23a8,$588e71,$3f2466,$1ea23d,$00006e,$15d71d
    .dc $6b411b,$7f39a0,$5be12d,$3f3a39,$20f9dc,$000078,$19a62b,$6cfe0d
    .dc $7f4b9c,$5eb0eb,$3f4c1b,$230667,$000083,$1d5369,$6e7658,$7f5a9a
    .dc $611981,$3f5b05,$24d456,$00008e,$20d87d,$6fb8b4,$7f674c,$632f76
    .dc $3f67a7,$266dbe,$000099,$243271,$70cff0,$7f722e,$650242,$3f727d
    .dc $27dac8,$0000a4,$276081,$71c425,$7f7b9d,$669dc1,$3f7be2,$292217
    .dc $0000af,$2a6343,$729b84,$7f83e0,$680b2e,$3f841c,$2a4916,$0000ba
    .dc $2d3c23,$735ae0,$7f8b29,$6951d5,$3f8b5f,$2b543b,$0000c5,$2fed07
    .dc $740605,$7f91a4,$6a778d,$3f91d4,$2c4739,$0000d0,$327812,$749ffd
    .dc $7f9771,$6b8111,$3f979c,$2d2525,$0000db,$34df7f,$752b3e,$7f9ca9
    .dc $6c723d,$3f9cd0,$2df096,$0000e6,$372587,$75a9cb,$7fa163,$6d4e43
    .dc $3fa185,$2eabbd,$0000f0,$394c57,$761d4d,$7fa5ae,$6e17cc,$3fa5ce
    .dc $2f5876,$0000fb,$3b5601,$768728,$7fa99a,$6ed113,$3fa9b7,$2ff857
    .dc $000106,$3d447b,$76e883,$7fad32,$6f7bfc,$3fad4d,$308cc0,$000111
    .dc $3f1999,$77425b,$7fb081,$701a21,$3fb09a,$3116df,$00011c,$40d714
    .dc $779586,$7fb38f,$70ace2,$3fb3a6,$3197bb,$000127,$427e81,$77e2bc
    .dc $7fb663,$713571,$3fb678,$321039,$000132,$441159,$782a9b,$7fb903
    .dc $71b4d2,$3fb917,$328121,$00013d,$4590fb,$786dab,$7fbb75,$722beb
    .dc $3fbb88,$32eb25,$000148,$46fea6,$78ac65,$7fbdbe,$729b84,$3fbdcf
    .dc $334ee0,$000153,$485b86,$78e730,$7fbfe0,$73044d,$3fbff0,$33acdd
    .dc $00015e,$49a8ac,$791e68,$7fc1e1,$7366e0,$3fc1f0,$340597,$000168
    .dc $4ae716,$79525f,$7fc3c2,$73c3c7,$3fc3d0,$34597a,$000173,$4c17ae
    .dc $79835c,$7fc587,$741b7b,$3fc595,$34a8ea,$00017e,$4d3b4c,$79b19e
    .dc $7fc733,$746e69,$3fc73f,$34f43f,$000189,$4e52b9,$79dd5e,$7fc8c6
    .dc $74bcf2,$3fc8d2,$353bc7,$000194,$4f5ead,$7a06cf,$7fca44,$75076d
    .dc $3fca4f,$357fca,$00019f,$505fd5,$7a2e1f,$7fcbae,$754e28,$3fcbb8
    .dc $35c088,$0001aa,$5156ce,$7a5377,$7fcd05,$75916a,$3fcd0f,$35fe3e
    .dc $0001b5,$52442d,$7a76fb,$7fce4b,$75d173,$3fce55,$36391e,$0001c0
    .dc $53287b,$7a98ce,$7fcf81,$760e7d,$3fcf8a,$36715c,$0001cb,$540436
    .dc $7ab90c,$7fd0a8,$7648bc,$3fd0b1,$36a722,$0001d5,$54d7d6,$7ad7d3
    .dc $7fd1c2,$768060,$3fd1ca,$36da99,$0001e0,$55a3c8,$7af53b,$7fd2cf
    .dc $76b595,$3fd2d7,$370be6,$0001eb,$566874,$7b115a,$7fd3d0,$76e883
    .dc $3fd3d8,$373b2c,$0001f6,$572639,$7b2c47,$7fd4c6,$77194f,$3fd4cd
    .dc $37688a,$000207,$5836b4,$7b5294,$7fd623,$775ec8,$3fd62a,$37a941
    .dc $00020c,$588e71,$7b5ed3,$7fd692,$777503,$3fd699,$37bdfe,$000217
    .dc $593987,$7b7694,$7fd76b,$77a026,$3fd771,$37e648,$000222,$59defb
    .dc $7b8d65,$7fd83a,$77c99f,$3fd841,$380d10,$00022d,$5a7f13,$7ba356
    .dc $7fd902,$77f184,$3fd908,$38326d,$000238,$5b1a10,$7bb873,$7fd9c2
    .dc $7817ee,$3fd9c8,$385671,$000243,$5bb02e,$7bccc7,$7fda7a,$783cf0
    .dc $3fda80,$38792f,$00024d,$5c41a6,$7be05d,$7fdb2c,$78609e,$3fdb32
    .dc $389ab8,$000258,$5cceaf,$7bf340,$7fdbd8,$788309,$3fdbdd,$38bb1c
    .dc $000263,$5d577a,$7c0579,$7fdc7d,$78a444,$3fdc82,$38da69,$00026e
    .dc $5ddc38,$7c1711,$7fdd1c,$78c45c,$3fdd21,$38f8ad,$000279,$5e5d15
    .dc $7c2810,$7fddb6,$78e362,$3fddbb,$3915f6,$000284,$5eda3c,$7c387d
    .dc $7fde4b,$790161,$3fde4f,$39324e,$00028f,$5f53d5,$7c4861,$7fdedb
    .dc $791e68,$3fdedf,$394dc2,$00029a,$5fca05,$7c57c1,$7fdf66,$793a82
    .dc $3fdf6a,$39685c,$0002a5,$603cf1,$7c66a4,$7fdfec,$7955ba,$3fdff0
    .dc $398227,$0002b5,$60e37c,$7c7c1a,$7fe0ae,$797cfd,$3fe0b2,$39a764
control_2:
    .dc $2789fc,$7ff70c,$0424fa,$7fd337,$0244f1,$00b90c,$0217dc,$7b87b9
    .dc $c42fb8,$278e3f,$7ff6a7,$041cd0,$7fd13b,$0251aa,$00bd19,$02232f
    .dc $7b6deb,$c4465e,$279299,$7ff63d,$041478,$7fcf2a,$025ea9,$00c13d
    .dc $022ebd,$7b5384,$c45d7a,$27970a,$7ff5ce,$040bf0,$7fcd00,$026bf2
    .dc $00c578,$023a87,$7b3881,$c4750e,$279b94,$7ff55b,$040338,$7fcabe
    .dc $027985,$00c9cb,$02468e,$7b1cde,$c48d1c,$27a037,$7ff4e2,$03fa4f
    .dc $7fc863,$028765,$00ce37,$0252d3,$7b0097,$c4a5a6,$27a4f2,$7ff464
    .dc $03f134,$7fc5ed,$029592,$00d2ba,$025f57,$7ae3a8,$c4beaf,$27a9c8
    .dc $7ff3e0,$03e7e5,$7fc35b,$02a40e,$00d758,$026c1c,$7ac60d,$c4d839
    .dc $27aeb7,$7ff357,$03de62,$7fc0ac,$02b2dc,$00dc0f,$027923,$7aa7c3
    .dc $c4f246,$27b3c1,$7ff2c7,$03d4a9,$7fbdde,$02c1fd,$00e0e0,$02866d
    .dc $7a88c3,$c50cd9,$27b8e7,$7ff232,$03cab8,$7fbaf1,$02d172,$00e5cd
    .dc $0293fa,$7a690c,$c527f4,$27be28,$7ff195,$03c090,$7fb7e2,$02e13e
    .dc $00ead5,$02a1cd,$7a4897,$c5439a,$27c386,$7ff0f2,$03b62e,$7fb4b1
    .dc $02f163,$00effa,$02afe6,$7a2760,$c55fcd,$27c900,$7ff047,$03ab91
    .dc $7fb15c,$0301e2,$00f53b,$02be47,$7a0563,$c57c8f,$27ce99,$7fef95
    .dc $03a0b9,$7fade1,$0312be,$00fa9a,$02ccf1,$79e29b,$c599e3,$27d44f
    .dc $7feedb,$0395a3,$7faa3f,$0323f8,$010016,$02dbe6,$79bf02,$c5b7cc
    .dc $27da24,$7fee18,$038a4e,$7fa673,$033593,$0105b2,$02eb26,$799a95
    .dc $c5d64b,$27e018,$7fed4e,$037eb9,$7fa27d,$034790,$010b6d,$02fab2
    .dc $79754c,$c5f565,$27e62c,$7fec7a,$0372e3,$7f9e59,$0359f2,$011148
    .dc $030a8d,$794f24,$c6151a,$27ec61,$7feb9c,$0366c9,$7f9a07,$036cbc
    .dc $011744,$031ab7,$792817,$c6356f,$27f2b7,$7feab5,$035a6b,$7f9584
    .dc $037fee,$011d61,$032b33,$79001f,$c65665,$27f92f,$7fe9c4,$034dc7
    .dc $7f90ce,$03938c,$0123a1,$033c00,$78d736,$c67800,$27ffca,$7fe8c8
    .dc $0340dc,$7f8be2,$03a798,$012a04,$034d21,$78ad57,$c69a41,$280688
    .dc $7fe7c1,$0333a7,$7f86bf,$03bc15,$01308a,$035e96,$78827b,$c6bd2d
    .dc $280d6a,$7fe6ae,$032628,$7f8161,$03d104,$013736,$037062,$78569c
    .dc $c6e0c5,$281470,$7fe58f,$03185c,$7f7bc7,$03e669,$013e06,$038286
    .dc $7829b4,$c7050c,$281b9c,$7fe464,$030a42,$7f75ee,$03fc46,$0144fd
    .dc $039503,$77fbbc,$c72a06,$2822ee,$7fe32b,$02fbd9,$7f6fd2,$04129d
    .dc $014c1b,$03a7da,$77ccaf,$c74fb4,$282a67,$7fe1e4,$02ed1d,$7f6971
    .dc $042971,$015360,$03bb0d,$779c83,$c7761a,$283207,$7fe08f,$02de0e
    .dc $7f62c8,$0440c6,$015acf,$03ce9e,$776b34,$c79d3b,$2839d0,$7fdf2a
    .dc $02ceaa,$7f5bd4,$04589d,$016267,$03e28d,$7738b9,$c7c51a,$2841c2
    .dc $7fddb6,$02beef,$7f5490,$0470fa,$016a29,$03f6dc,$77050b,$c7edb9
    .dc $2849dd,$7fdc32,$02aedb,$7f4cfb,$0489df,$017218,$040b8e,$76d023
    .dc $c8171b,$285224,$7fda9c,$029e6c,$7f4510,$04a350,$017a32,$0420a2
    .dc $7699f8,$c84144,$285a96,$7fd8f4,$028d9f,$7f3ccb,$04bd4f,$01827a
    .dc $04361b,$766283,$c86c36,$286334,$7fd73a,$027c74,$7f3429,$04d7e1
    .dc $018af1,$044bfa,$7629bc,$c897f3,$286c00,$7fd56c,$026ae7,$7f2b25
    .dc $04f307,$019397,$046240,$75ef9a,$c8c480,$2874fa,$7fd389,$0258f7
    .dc $7f21bc,$050ec5,$019c6d,$0478f0,$75b415,$c8f1df,$287e22,$7fd191
    .dc $0246a1,$7f17e7,$052b1f,$01a575,$049009,$757723,$c92013,$28877a
    .dc $7fcf83,$0233e4,$7f0da4,$054818,$01aeb0,$04a78f,$7538bc,$c94f1e
    .dc $289103,$7fcd5e,$0220bd,$7f02ed,$0565b3,$01b81e,$04bf82,$74f8d6
    .dc $c97f04,$289abe,$7fcb20,$020d29,$7ef7bc,$0583f4,$01c1c1,$04d7e4
    .dc $74b768,$c9afc8,$28a4ab,$7fc8c9,$01f926,$7eec0d,$05a2de,$01cb9a
    .dc $04f0b6,$747469,$c9e16c,$28aecb,$7fc657,$01e4b2,$7edfda,$05c276
    .dc $01d5aa,$0509fa,$742fcd,$ca13f3,$28b920,$7fc3ca,$01cfcb,$7ed31d
    .dc $05e2bf,$01dff3,$0523b0,$73e98c,$ca4761,$28c3aa,$7fc11f,$01ba6d
    .dc $7ec5d0,$0603bd,$01ea76,$053ddc,$73a19a,$ca7bb7,$28ce6a,$7fbe57
    .dc $01a497,$7eb7ed,$062574,$01f533,$05587d,$7357ec,$cab0fa,$28def2
    .dc $7fb9ef,$0182ed,$7ea1f1,$06596a,$0205c0,$05814f,$72e611,$cb029e
    .dc $28e491,$7fb866,$017775,$7e9a4a,$066b1d,$020b64,$058f26,$72bf33
    .dc $cb1e4d,$28effa,$7fb53b,$016024,$7e8a7b,$068f17,$0216da,$05ab32
    .dc $727010,$cb5663,$28fb9c,$7fb1ec,$01484f,$7e79fa,$06b3db,$022290
    .dc $05c7b8,$721f05,$cb8f70,$29077a,$7fae77,$012ff4,$7e68bf,$06d96d
    .dc $022e88,$05e4bb,$71cc03,$cbc976,$291395,$7faadb,$01170f,$7e56c1
    .dc $06ffd1,$023ac3,$06023c,$717700,$cc0478,$291fec,$7fa717,$00fd9e
    .dc $7e43f8,$07270d,$024742,$06203c,$711fef,$cc4079,$292c82,$7fa327
    .dc $00e39e,$7e305b,$074f25,$025408,$063ebd,$70c6c1,$cc7d7a,$293957
    .dc $7f9f0b,$00c90b,$7e1be1,$07781d,$026115,$065dbf,$706b6b,$ccbb7e
    .dc $29466c,$7f9ac1,$00ade2,$7e0680,$07a1fb,$026e6b,$067d44,$700dde
    .dc $ccfa87,$2953c3,$7f9646,$009220,$7df02e,$07ccc3,$027c0c,$069d4c
    .dc $6fae0c,$cd3a98,$29615c,$7f9198,$0075c3,$7dd8e1,$07f87c,$0289fa
    .dc $06bdda,$6f4be7,$cd7bb3,$296f39,$7f8cb6,$0058c5,$7dc08d,$082529
    .dc $029835,$06deed,$6ee760,$cdbdda,$297d5a,$7f879c,$003b25,$7da727
    .dc $0852d1,$02a6c1,$070087,$6e8068,$ce010e,$298bc1,$7f8248,$001cdf
    .dc $7d8ca2,$088178,$02b59d,$0722a9,$6e16ef,$ce4552,$299a6f,$7f7cb8
    .dc $fffdee,$7d70f4,$08b125,$02c4ce,$074553,$6daae6,$ce8aa6,$29b0fc
    .dc $7f73e9,$ffce3f,$7d4521,$08faa0,$02dc36,$077a55,$6d03e6,$cef4a9
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
