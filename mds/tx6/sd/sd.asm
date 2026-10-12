; TX6 SD - Simple606-inspired MDS voice for X.20, version 2.0.
; New layer controls preserve version 1.0 audio at their defaults.
; BODY: 0 = remove this layer; 127 = original layer level. Captured on trigger.
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
; 01: gatehold
; 02: gatepole
; 03: p0
; 04: cos0
; 05: qbase
; 06: bodypole0
; 07: b0
; 08: a1
; 09: a2
; 0a: fast
; 0b: slow
; 0c: rng
; 0d: z1
; 0e: z2
; 0f: fp
; 10: sp
; 11: noiseamp
; 12: glide
; 13: s0
; 14: c0
; 15: d0
; 16: r0
; 17: bodyfast
; 18: bodyslow
; 19: bodypole1

; Local instruction compaction; verify against retained native audio.
init:
    move #>$ffffff,m6
    move #>$ffffff,m0
    clr a r6,r0
    do #26,init_end
    move a1,x:(r0)+
init_end:
    move #>$006063,x0
    move x0,x:(r6+$c)
    rts
trigger:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move #>$ffffff,m1
    clr a
    move a1,x:(r6+$d)
    move a1,x:(r6+$e)
    move a1,x:(r6+$11)
    move y:(r6+$2),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add x0,a
    add #>control_1,a
    move a1,r0
    move r6,a
    move a1,r1
    do #3,control_1_end
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
    add #>control_2,a
    move a1,r0
    move r6,a
    add #>3,a
    move a1,r1
    do #4,control_2_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_2_end:
    move y:(r6+$4),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add x0,a
    add #>control_4,a
    move a1,r0
    move r6,a
    add #>7,a
    move a1,r1
    do #3,control_4_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_4_end:
    move y:(r6+$3),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add #>control_3,a
    move a1,r0
    move r6,a
    add #>10,a
    move a1,r1
    do #2,control_3_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_3_end:
    move #>$544ba2,x0
    move x0,x:(r6+$f)
    move #>$7e62d0,x0
    move x0,x:(r6+$10)
    move #>$3af49a,x0
    move x0,x:(r6+$13)
    move #>$7fffff,x0
    move x0,x:(r6+$16)
    move #>$02a601,x0
    move x0,x:(r6+$12)
    move #>$6c4e06,x0
    move x0,x:(r6+$19)
    move #>$400000,x0
    move x0,x:(r6+$15)
    move x:(r6+$4),a
    move a1,x:(r6+$14)
    move y:(r6+$5),a
    asr #7,a,a
    and #>$7e,a
    add #>layer_table,a
    move a1,r0
    move p:(r0)+,x0
    move x0,x:(r6+$17)
    move p:(r0)+,x0
    move x0,x:(r6+$18)
    rts
render:
    move #>$ffffff,m6
    move x:(r6+$0),a
    tst a
    jeq silent
    sub #>1,a
    move a1,x:(r6+$0)
    move x:(r6+$1),a
    tst a
    jlt gate_ready
    jeq gate_begin
    sub #>1,a
    move a1,x:(r6+$1)
    jmp gate_ready
gate_begin:
    move #>$ffffff,x0
    move x0,x:(r6+$1)
    move x:(r6+$2),y0
    move x:(r6+$f),x0
    mpyr y0,x0,a
    move a1,x:(r6+$f)
    move x:(r6+$10),x0
    mpyr y0,x0,a
    move a1,x:(r6+$10)
    move x:(r6+$6),x0
    mpyr y0,x0,a
    move a1,x:(r6+$6)
    move x:(r6+$19),x0
    mpyr y0,x0,a
    move a1,x:(r6+$19)
gate_ready:
    move x:(r6+$5),a
    move x:(r6+$12),x0
    add x0,a
    move a1,x1
    move #>$79380e,y0
    mpyr y0,x0,a
    move a1,x:(r6+$12)
    move x1,x0
    mpy x0,x0,a
    asr a
    neg a
    add #>$7fffff,a
    move a1,y0
    move a1,x:(r6+$14)
    move x:(r6+$c),x0
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
    move x0,x:(r6+$c)
    move #>mds_scratch_x,r3
    move x:(r6+$7),x0
    move x0,x:(r3)+
    move x:(r6+$8),x0
    move x0,x:(r3)+
    move x:(r6+$9),x0
    move x0,x:(r3)+
    move x:(r6+$d),b
    move x:(r6+$e),x1
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
    move b1,x:(r6+$d)
    move x1,x:(r6+$e)
    move #>mds_scratch_x,r4
    move x:(r6+$13),x0
    move x:(r6+$3),x1
    move x:(r6+$14),y0
    move x:(r6+$15),y1
    do #32,tone0_end
    mpy y0,x0,a
    mac -y1,x1,a x0,x1
    asl a
    rnd a
    move a1,x0
    move a1,x:(r4)+
tone0_end:
    move x0,x:(r6+$13)
    move x1,x:(r6+$3)
    move x:(r6+$17),x0
    move x:(r6+$18),a
    add x0,a
    move a1,n4
    move x:(r6+$17),x0
    move x:(r6+$6),y0
    mpyr y0,x0,a
    move a1,x:(r6+$17)
    move x:(r6+$18),x0
    move x:(r6+$19),y0
    mpyr y0,x0,a
    move a1,x:(r6+$18)
    move x:(r6+$17),x0
    move x:(r6+$18),a
    add x0,a n4,x0
    add x0,a
    asr a
    move a1,n4
    move x:(r6+$a),x0
    move x:(r6+$f),y0
    mpyr y0,x0,a
    move a1,x:(r6+$a)
    move x:(r6+$b),x0
    move x:(r6+$10),y0
    mpyr y0,x0,a
    move a1,x:(r6+$b)
    move x:(r6+$a),x0
    move x:(r6+$b),a
    add x0,a
    move x:(r6+$11),x0
    move a1,b
    move b1,x:(r6+$11)
    add x0,b
    asr b
    move b1,x0
    move n4,y1
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #32,mix_end
    move x:(r3)+,x1 y:(r5)+,y0
    mpy y0,x0,a
    asl a
    mac y1,x1,a
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
    .dc $000006,$000000,$0eab5c,$000009,$000000,$20583d,$000011,$000000
    .dc $405801,$000019,$000000,$50ec66,$000021,$000000,$5ac09f,$000029
    .dc $000000,$6136c5,$000031,$000000,$65c676,$000039,$000000,$6929ec
    .dc $000041,$000000,$6bc76c,$000049,$000000,$6ddba1,$000051,$000000
    .dc $6f8cc8,$000059,$000000,$70f422,$000061,$000000,$72230c,$000069
    .dc $000000,$7325d5,$000071,$000000,$740579,$000079,$000000,$74c8ab
    .dc $000081,$000000,$757484,$000089,$000000,$760cf7,$000091,$000000
    .dc $769520,$000099,$000000,$770f79,$0000a1,$000000,$777e02,$0000a9
    .dc $000000,$77e25c,$0000b1,$000000,$783de0,$0000b9,$000000,$7891ac
    .dc $0000c1,$000000,$78deaf,$0000c9,$000000,$7925b5,$0000d1,$000000
    .dc $796769,$0000d9,$000000,$79a45e,$0000e1,$000000,$79dd15,$0000e9
    .dc $000000,$7a11fa,$0000f1,$000000,$7a436d,$0000fa,$000000,$7a71c1
    .dc $000102,$000005,$7a87d7,$00010a,$000015,$7a5af6,$000112,$000025
    .dc $7a2b1c,$00011a,$000035,$79f7fb,$000122,$000045,$79c13a,$00012a
    .dc $000055,$798673,$000132,$000065,$79472f,$00013a,$000075,$7902e6
    .dc $000142,$000085,$78b8f9,$00014a,$000095,$7868ad,$000152,$0000a5
    .dc $781126,$00015a,$0000b5,$77b15e,$000162,$0000c5,$77481c,$00016a
    .dc $0000d5,$76d3e4,$000172,$0000e5,$7652ea,$00017e,$0000fe,$757484
    .dc $000182,$000106,$75213e,$00018a,$000116,$746a47,$000192,$000126
    .dc $739995,$00019a,$000136,$72a954,$0001a2,$000146,$7191c8,$0001aa
    .dc $000156,$704874,$0001b2,$000166,$6ebec7,$0001ba,$000176,$6cdfe9
    .dc $0001c2,$000186,$6a8cf1,$0001ca,$000196,$679606,$0001d2,$0001a6
    .dc $63ad0d,$0001da,$0001b6,$5e4988,$0001e2,$0001c6,$5666d5,$0001eb
    .dc $0001d6,$49d51a,$0001f3,$0001e6,$332934,$0001ff,$0001ff,$7fffff
control_2:
    .dc $3a0c22,$7febe9,$01d56a,$7eafc8,$3a09f3,$7feb8c,$01dfc7,$7ea866
    .dc $3a07b7,$7feb2c,$01ea5e,$7ea0db,$3a056f,$7feac8,$01f530,$7e9926
    .dc $3a0319,$7fea62,$020040,$7e9145,$3a00b6,$7fe9f8,$020b8e,$7e8939
    .dc $39fe44,$7fe98b,$02171c,$7e8100,$39fbc4,$7fe91b,$0222ec,$7e7899
    .dc $39f936,$7fe8a7,$022efe,$7e7003,$39f698,$7fe82f,$023b54,$7e673d
    .dc $39f3ec,$7fe7b3,$0247f1,$7e5e46,$39f12f,$7fe734,$0254d4,$7e551d
    .dc $39ee63,$7fe6b0,$026200,$7e4bc1,$39eb86,$7fe628,$026f77,$7e4231
    .dc $39e898,$7fe59b,$027d39,$7e386c,$39e599,$7fe50a,$028b4a,$7e2e70
    .dc $39e288,$7fe474,$0299aa,$7e243d,$39df66,$7fe3d8,$02a85b,$7e19d1
    .dc $39dc30,$7fe338,$02b75f,$7e0f2b,$39d8e8,$7fe293,$02c6b8,$7e0449
    .dc $39d58d,$7fe1e7,$02d667,$7df92b,$39d21d,$7fe137,$02e66f,$7dedd0
    .dc $39ce99,$7fe080,$02f6d2,$7de235,$39cb01,$7fdfc3,$030791,$7dd659
    .dc $39c753,$7fdeff,$0318af,$7dca3c,$39c38f,$7fde35,$032a2e,$7dbddc
    .dc $39bfb5,$7fdd64,$033c10,$7db137,$39bbc3,$7fdc8b,$034e56,$7da44c
    .dc $39b7bb,$7fdbac,$036104,$7d9719,$39b39a,$7fdac4,$03741b,$7d899d
    .dc $39af60,$7fd9d4,$03879e,$7d7bd6,$39ab0e,$7fd8dc,$039b90,$7d6dc3
    .dc $39a6a1,$7fd7dc,$03aff2,$7d5f63,$39a21a,$7fd6d2,$03c4c7,$7d50b2
    .dc $399d78,$7fd5bf,$03da12,$7d41b1,$3998ba,$7fd4a2,$03efd5,$7d325c
    .dc $3993df,$7fd37b,$040613,$7d22b3,$398ee7,$7fd24a,$041ccf,$7d12b3
    .dc $3989d2,$7fd10e,$04340b,$7d025c,$39849d,$7fcfc6,$044bca,$7cf1a9
    .dc $397f49,$7fce73,$046410,$7ce09b,$3979d5,$7fcd13,$047cdf,$7ccf2f
    .dc $397440,$7fcba7,$049639,$7cbd63,$396e89,$7fca2d,$04b023,$7cab35
    .dc $3968af,$7fc8a6,$04caa0,$7c98a4,$3962b1,$7fc710,$04e5b2,$7c85ac
    .dc $395c8f,$7fc56b,$05015c,$7c724c,$395316,$7fc2d8,$052c03,$7c5473
    .dc $394fda,$7fc1f3,$053a8a,$7c4a4a,$394945,$7fc01f,$055814,$7c35a4
    .dc $394288,$7fbe38,$057645,$7c208d,$393ba1,$7fbc40,$059521,$7c0b03
    .dc $39348f,$7fba35,$05b4aa,$7bf502,$392d52,$7fb817,$05d4e6,$7bde8a
    .dc $3925e9,$7fb5e4,$05f5d8,$7bc796,$391e52,$7fb39b,$061784,$7bb025
    .dc $39168b,$7fb13d,$0639ee,$7b9835,$390e95,$7faec8,$065d1a,$7b7fc2
    .dc $39066d,$7fac3b,$06810d,$7b66ca,$38fe12,$7fa995,$06a5cb,$7b4d4a
    .dc $38f583,$7fa6d6,$06cb58,$7b333f,$38ecbf,$7fa3fb,$06f1ba,$7b18a7
    .dc $38e3c4,$7fa104,$0718f4,$7afd7f,$38d5e1,$7f9c5b,$07556c,$7ad3ad
control_4:
    .dc $086f7f,$6f39da,$ccaf04,$089949,$6ecee7,$ccedda,$08c3be,$6e6125
    .dc $cd2db1,$08eee0,$6df081,$cd6e8b,$091aae,$6d7ce8,$cdb069,$09472b
    .dc $6d0645,$cdf34d,$097456,$6c8c83,$ce3737,$09a230,$6c0f8c,$ce7c29
    .dc $09d0ba,$6b8f4a,$cec223,$09fff4,$6b0ba8,$cf0926,$0a2fdf,$6a848d
    .dc $cf5132,$0a607b,$69f9e1,$cf9a48,$0a91c6,$696b8d,$cfe467,$0ac3c3
    .dc $68d978,$d02f90,$0af670,$684388,$d07bc1,$0b29cc,$67a9a2,$d0c8fb
    .dc $0b5dd7,$670bad,$d1173c,$0b9291,$66698c,$d16683,$0bc7f7,$65c324
    .dc $d1b6ce,$0bfe0a,$651858,$d2081c,$0c34c7,$64690a,$d25a6a,$0c6c2d
    .dc $63b51d,$d2adb6,$0ca43a,$62fc72,$d301fd,$0cdceb,$623ee9,$d3573b
    .dc $0d163f,$617c62,$d3ad6d,$0d5032,$60b4bc,$d4048f,$0d8ac1,$5fe7d7
    .dc $d45c9c,$0dc5ea,$5f1590,$d4b590,$0e01a8,$5e3dc3,$d50f64,$0e3df8
    .dc $5d604d,$d56a13,$0e7ad5,$5c7d0b,$d5c597,$0eb83a,$5b93d6,$d621e7
    .dc $0ef623,$5aa489,$d67efe,$0f348a,$59aefd,$d6dcd2,$0f736a,$58b30b
    .dc $d73b5b,$0fb2bb,$57b08a,$d79a8f,$0ff277,$56a753,$d7fa65,$103298
    .dc $55973b,$d85ad1,$107315,$548017,$d8bbc7,$10b3e5,$5361bd,$d91d3c
    .dc $10f502,$523c01,$d97f23,$113660,$510eb6,$d9e16c,$1177f7,$4fd9ae
    .dc $da440b,$11b9bb,$4e9cbc,$daa6ee,$11fba3,$4d57af,$db0a06,$123da1
    .dc $4c0a59,$db6d40,$127faa,$4ab489,$dbd08b,$12e2af,$48a37f,$dc656d
    .dc $1303a7,$47eeb3,$dc9700,$13457f,$467e49,$dcfa00,$138728,$45049a
    .dc $dd5cbb,$13c894,$438171,$ddbf18,$1409af,$41f49b,$de20fd,$144a69
    .dc $405de0,$de8250,$148aaf,$3ebd09,$dee2f4,$14ca6c,$3d11e0,$df42cb
    .dc $15098d,$3b5c2b,$dfa1b5,$1547f9,$399bb1,$dfff92,$15859c,$37d038
    .dc $e05c3e,$15c25b,$35f985,$e0b795,$15fe1e,$34175c,$e11170,$1638c9
    .dc $322981,$e169a7,$167240,$302fb6,$e1c00f,$16c5f1,$2d221d,$e23de5
control_3:
    .dc $000000,$000000,$ff3196,$00ce6a,$fe632d,$019cd3,$fd94c3,$026b3d
    .dc $fcc659,$0339a7,$fbf7f0,$040810,$fb2986,$04d67a,$fa5b1d,$05a4e3
    .dc $f98cb3,$06734d,$f8be49,$0741b7,$f7efe0,$081020,$f72176,$08de8a
    .dc $f6530c,$09acf4,$f584a3,$0a7b5d,$f4b639,$0b49c7,$f3e7d0,$0c1830
    .dc $f31966,$0ce69a,$f24afc,$0db504,$f17c93,$0e836d,$f0ae29,$0f51d7
    .dc $efdfbf,$102041,$ef1156,$10eeaa,$ee42ec,$11bd14,$ed7483,$128b7d
    .dc $eca619,$1359e7,$ebd7af,$142851,$eb0946,$14f6ba,$ea3adc,$15c524
    .dc $e96c72,$16938e,$e89e09,$1761f7,$e7cf9f,$183061,$e70136,$18feca
    .dc $e632cc,$19cd34,$e56462,$1a9b9e,$e495f9,$1b6a07,$e3c78f,$1c3871
    .dc $e2f925,$1d06db,$e22abc,$1dd544,$e15c52,$1ea3ae,$e08de9,$1f7217
    .dc $dfbf7f,$204081,$def115,$210eeb,$de22ac,$21dd54,$dd5442,$22abbe
    .dc $dc85d8,$237a28,$dbb76f,$244891,$dae905,$2516fb,$d9b367,$264c99
    .dc $d94c32,$26b3ce,$d87dc8,$278238,$d7af5f,$2850a1,$d6e0f5,$291f0b
    .dc $d6128b,$29ed75,$d54422,$2abbde,$d475b8,$2b8a48,$d3a74f,$2c58b1
    .dc $d2d8e5,$2d271b,$d20a7b,$2df585,$d13c12,$2ec3ee,$d06da8,$2f9258
    .dc $cf9f3e,$3060c2,$ced0d5,$312f2b,$ce026b,$31fd95,$cccccd,$333333
layer_table:
    .dc $000000,$000000,$008e23,$009ff3,$011c46,$013fe6,$01aa69,$01dfd9
    .dc $02388c,$027fcc,$02c6ae,$031fbe,$0354d1,$03bfb1,$03e2f4,$045fa4
    .dc $047117,$04ff97,$04ff3a,$059f8a,$058d5d,$063f7d,$061b80,$06df70
    .dc $06a9a3,$077f63,$0737c6,$081f56,$07c5e8,$08bf48,$08540b,$095f3b
    .dc $08e22e,$09ff2e,$097051,$0a9f21,$09fe74,$0b3f14,$0a8c97,$0bdf07
    .dc $0b1aba,$0c7efa,$0ba8dd,$0d1eed,$0c3700,$0dbee0,$0cc522,$0e5ed2
    .dc $0d5345,$0efec5,$0de168,$0f9eb8,$0e6f8b,$103eab,$0efdae,$10de9e
    .dc $0f8bd1,$117e91,$1019f4,$121e84,$10a817,$12be77,$11363a,$135e6a
    .dc $11c45c,$13fe5c,$12527f,$149e4f,$12e0a2,$153e42,$136ec5,$15de35
    .dc $13fce8,$167e28,$148b0b,$171e1b,$15192e,$17be0e,$15a751,$185e01
    .dc $163574,$18fdf4,$16c397,$199de7,$1751b9,$1a3dd9,$17dfdc,$1addcc
    .dc $186dff,$1b7dbf,$18fc22,$1c1db2,$198a45,$1cbda5,$1a1868,$1d5d98
    .dc $1aa68b,$1dfd8b,$1b34ae,$1e9d7e,$1bc2d1,$1f3d71,$1c50f3,$1fdd63
    .dc $1cdf16,$207d56,$1d6d39,$211d49,$1dfb5c,$21bd3c,$1e897f,$225d2f
    .dc $1f17a2,$22fd22,$1fa5c5,$239d15,$2033e8,$243d08,$20c20b,$24dcfb
    .dc $21502d,$257ced,$21de50,$261ce0,$226c73,$26bcd3,$2388b9,$27fcb9
