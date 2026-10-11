; TR6 CH - Simple606-inspired MDS voice for X.20, version 1.1.
; New layer controls preserve version 1.0 audio at their defaults.
; METL: 0 = noise only; 64 = original blend; 127 = metal only. Captured on trigger.
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
; 03: fade
; 04: b0
; 05: a1
; 06: a2
; 07: s0
; 08: p0
; 09: c0
; 0a: s1
; 0b: p1
; 0c: c1
; 0d: rng
; 0e: z1
; 0f: z2
; 10: fast
; 11: slow
; 12: attack
; 13: bell
; 14: click
; 15: envelope
; 16: tonegain
; 17: noisegain
; 18: metal_tone
; 19: metal_noise

; Local instruction compaction; verify against retained native audio.
init:
    move #>$ffffff,m6
    move #>$ffffff,m0
    clr a r6,r0
    do #26,init_end
    move a1,x:(r0)+
init_end:
    move #>$606301,x0
    move x0,x:(r6+$d)
    rts
trigger:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move #>$ffffff,m1
    clr a
    move a1,x:(r6+$e)
    move a1,x:(r6+$f)
    move y:(r6+$1),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl #2,a,a
    add #>control_1,a
    move a1,r0
    move r6,a
    move a1,r1
    do #4,control_1_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_1_end:
    move y:(r6+$2),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl #3,a,a
    add x0,a
    add #>control_2,a
    move a1,r0
    move r6,a
    add #>4,a
    move a1,r1
    do #9,control_2_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_2_end:
    move #>$700000,x0
    move x0,x:(r6+$10)
    move #$0,x0
    move x0,x:(r6+$11)
    move #>$7fffff,x0
    move x0,x:(r6+$12)
    move #>$2ccccd,x0
    move x0,x:(r6+$13)
    move y:(r6+$3),a
    asr #8,a,a
    move a1,a
    asl a a1,x0
    add x0,a
    add #>metal_table,a
    move a1,r0
    move p:(r0)+,x0
    move x0,x:(r6+$18)
    move p:(r0)+,x0
    move x0,x:(r6+$19)
    move p:(r0)+,x0
    move x0,x:(r6+$14)
    rts
render:
    move #>$ffffff,m6
    move x:(r6+$0),a
    tst a
    jeq silent
    sub #>1,a
    move a1,x:(r6+$0)
    move a1,x0
    move x:(r6+$3),y0
    mpy y0,x0,a
    asl #23,a,a
    move #>$7fffff,x0
    cmp x0,a
    tgt x0,a
    move a1,n4
    move x:(r6+$10),x0
    move x:(r6+$1),y0
    mpyr y0,x0,a
    move a1,x:(r6+$10)
    move x:(r6+$11),x0
    move x:(r6+$2),y0
    mpyr y0,x0,a
    move a1,x:(r6+$11)
    move x:(r6+$12),x0
    move #>$1dfcd2,y0
    mpyr y0,x0,a
    move a1,x:(r6+$12)
    move x:(r6+$13),x0
    move #>$7db2f1,y0
    mpyr y0,x0,a
    move a1,x:(r6+$13)
    move x:(r6+$14),x0
    move #>$647ff1,y0
    mpyr y0,x0,a
    move a1,x:(r6+$14)
    move x:(r6+$12),x0
    move #>$7fffff,a
    sub x0,a
    move a1,y0
    move x:(r6+$10),a
    move x:(r6+$11),x0
    add x0,a
    move a1,x0
    mpy y0,x0,a
    move a1,x0
    move n4,y0
    mpyr y0,x0,a
    move a1,x:(r6+$15)
    move x:(r6+$13),a
    add #>$400000,a
    move a1,x0
    move x:(r6+$18),y0
    mpy y0,x0,a
    move a1,x0
    move x:(r6+$15),y0
    mpyr y0,x0,a
    move a1,x:(r6+$16)
    move x:(r6+$15),x0
    move x:(r6+$19),y0
    mpy y0,x0,a
    move x:(r6+$14),x0
    add x0,a
    asr a
    move a1,x:(r6+$17)
    move x:(r6+$d),x0
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
    move x0,x:(r6+$d)
    move #>mds_scratch_x,r3
    move x:(r6+$4),x0
    move x0,x:(r3)+
    move x:(r6+$5),x0
    move x0,x:(r3)+
    move x:(r6+$6),x0
    move x0,x:(r3)+
    move x:(r6+$e),b
    move x:(r6+$f),x1
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
    move b1,x:(r6+$e)
    move x1,x:(r6+$f)
    move #>mds_scratch_x,r4
    move x:(r6+$7),x0
    move x:(r6+$8),x1
    move x:(r6+$9),y0
    do #32,tone0_end
    mpy y0,x0,a
    asl a
    sub x1,a x0,x1
    move a1,x0
    move a1,x:(r4)+
tone0_end:
    move x0,x:(r6+$7)
    move x1,x:(r6+$8)
    move #>mds_scratch_x,r4
    move x:(r6+$a),x0
    move x:(r6+$b),x1
    move x:(r6+$c),y0
    do #32,tone1_end
    mpy y0,x0,a
    asl a
    sub x1,a x0,x1
    move x:(r4),b
    add b,a a1,x0
    move a1,x:(r4)+
tone1_end:
    move x0,x:(r6+$a)
    move x1,x:(r6+$b)
    move x:(r6+$16),y1
    move x:(r6+$17),x0
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #32,mix_end
    move x:(r3)+,x1 y:(r5)+,y0
    mpy y0,x0,a
    mac y1,x1,a
    asl #2,a,a
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
    .dc $000027,$6ac3ad,$6ac3ad,$03510d,$000027,$6ac3ad,$6ac3ad,$03510d
    .dc $000027,$6ac3ad,$6ac3ad,$03510d,$000027,$6ac3ad,$6ac3ad,$03510d
    .dc $000027,$6ac3ad,$6ac3ad,$03510d,$000027,$6ac3ad,$6ac3ad,$03510d
    .dc $000027,$6ac3ad,$6ac3ad,$03510d,$000027,$6ac3ad,$6ac3ad,$03510d
    .dc $000027,$6bcf00,$6bcf00,$03510d,$00002b,$6de27e,$6de27e,$02fa9a
    .dc $000030,$6f9308,$6f9308,$02ae3e,$000035,$70f9e0,$70f9e0,$027027
    .dc $00003a,$722863,$722863,$023c0e,$00003f,$732ad1,$732ad1,$021040
    .dc $000043,$740a27,$740a27,$021040,$000048,$74cd07,$74cd07,$021040
    .dc $00004d,$7578a1,$7578a1,$021040,$000052,$7610e5,$7610e5,$021040
    .dc $000056,$7698d6,$7698d6,$021040,$00005b,$7712f8,$7712f8,$021040
    .dc $000060,$77815c,$77815c,$021040,$000065,$77e592,$77e592,$021040
    .dc $00006a,$7840ed,$7840ed,$021040,$00006e,$7894a2,$7894a2,$021040
    .dc $000073,$78e187,$78e187,$021040,$000078,$792872,$792872,$021040
    .dc $00007d,$796a0e,$796a0e,$021040,$000081,$79a6eb,$79a6eb,$021040
    .dc $000086,$79df8c,$79df8c,$021040,$00008b,$7a1456,$7a1456,$021040
    .dc $000090,$7a45bf,$7a45bf,$021040,$000094,$7a73ff,$7a73ff,$021040
    .dc $000099,$7a9f6f,$7a9f6f,$021040,$00009e,$7ac83a,$7ac83a,$021040
    .dc $0000a3,$7aeebb,$7aeebb,$021040,$0000a8,$7b131d,$7b131d,$021040
    .dc $0000ac,$7b357d,$7b357d,$021040,$0000b1,$7b55f8,$7b55f8,$021040
    .dc $0000b6,$7b74da,$7b74da,$021040,$0000bb,$7b9223,$7b9223,$021040
    .dc $0000bf,$7badfe,$7badfe,$021040,$0000c4,$7bc88b,$7bc88b,$021040
    .dc $0000c9,$7be1d8,$7be1d8,$021040,$0000ce,$7bf9f4,$7bf9f4,$021040
    .dc $0000d3,$7c10fd,$7c10fd,$021040,$0000d7,$7c2711,$7c2711,$021040
    .dc $0000dc,$7c3c21,$7c3c21,$021040,$0000e3,$7c5a23,$7c5a23,$021040
    .dc $0000e6,$7c63be,$7c63be,$021040,$0000ea,$7c7659,$7c7659,$021040
    .dc $0000ef,$7c882d,$7c882d,$021040,$0000f4,$7c9958,$7c9958,$021040
    .dc $0000f9,$7ca9e9,$7ca9e9,$021040,$0000fd,$7cb9d0,$7cb9d0,$021040
    .dc $000102,$7cc91d,$7cc91d,$021040,$000107,$7cd7e0,$7cd7e0,$021040
    .dc $00010c,$7ce627,$7ce627,$021040,$000111,$7cf3e4,$7cf3e4,$021040
    .dc $000115,$7d0134,$7d0134,$021040,$00011a,$7d0e08,$7d0e08,$021040
    .dc $00011f,$7d1a70,$7d1a70,$021040,$000124,$7d267c,$7d267c,$021040
    .dc $000128,$7d321b,$7d321b,$021040,$000130,$7d42df,$7d42df,$021040
control_2:
    .dc $099625,$51d14b,$d6c9f3,$179895,$146528,$749148,$23629b,$29623c
    .dc $732a51,$09c01f,$507e72,$d72713,$1791f2,$1429ba,$7410bb,$2399f9
    .dc $2975c0,$729a49,$09ea5e,$4f2253,$d78422,$178a9d,$13eb1a,$738aa1
    .dc $23d1a1,$298556,$720411,$0a14df,$4dbcb0,$d7e10a,$17828c,$13a926
    .dc $72febf,$240987,$2990b5,$716767,$0a3f9c,$4c4d53,$d83dac,$1779b3
    .dc $1363bd,$726cd8,$2441a1,$29978f,$70c406,$0a6a92,$4ad3ee,$d89a04
    .dc $177008,$131aba,$71d4ac,$2479e1,$299993,$7019aa,$0a95bd,$495047
    .dc $d8f5f2,$17657f,$12cdfa,$7135fa,$24b23b,$29966d,$6f6808,$0ac116
    .dc $47c21c,$d9515c,$175a0d,$127d58,$70907c,$24eaa0,$298dc6,$6eaed6
    .dc $0aec9b,$462928,$d9ac28,$174da5,$1228b0,$6fe3ec,$252301,$297f3f
    .dc $6dedc6,$0b1846,$448526,$da063c,$174039,$11cfdd,$6f3000,$255b4d
    .dc $296a7a,$6d2487,$0b4411,$42d5cc,$da5f7c,$1731bc,$1172b6,$6e746c
    .dc $259373,$294f14,$6c52c5,$0b6ff9,$411ad2,$dab7cb,$172220,$111117
    .dc $6db0e2,$25cb5f,$292ca3,$6b782b,$0b9bf6,$3f53e7,$db0f0c,$171155
    .dc $10aad9,$6ce50f,$2602fe,$2902bc,$6a945e,$0bc805,$3d80c0,$db651e
    .dc $16ff4c,$103fd4,$6c10a0,$263a3a,$28d0f1,$69a702,$0bf41e,$3ba10b
    .dc $dbb9e3,$16ebf6,$0fcfe2,$6b333c,$2670fb,$2896cc,$68afb9,$0c203e
    .dc $39b471,$dc0d39,$16d73f,$0f5adb,$6a4c8a,$26a729,$2853d8,$67ae20
    .dc $0c4c5e,$37ba9f,$dc5efe,$16c118,$0ee09b,$695c2c,$26dcaa,$28079a
    .dc $66a1d2,$0c7877,$35b33a,$dcaf10,$16a96e,$0e60fb,$6861c3,$271162
    .dc $27b193,$658a66,$0ca483,$339de4,$dcfd48,$16902e,$0ddbd6,$675cec
    .dc $274533,$275141,$646771,$0cd07e,$317a40,$dd4983,$167543,$0d5108
    .dc $664d3f,$2777fd,$26e620,$633886,$0cfc5f,$2f47e7,$dd9398,$165899
    .dc $0cc06e,$653255,$27a9a0,$266fa8,$61fd31,$0d2821,$2d0676,$dddb61
    .dc $163a1b,$0c29e8,$640bc0,$27d9f7,$25ed50,$60b4ff,$0d53bd,$2ab580
    .dc $de20b3,$1619b2,$0b8d57,$62d911,$2808de,$255e8a,$5f5f79,$0d7f2c
    .dc $285497,$de6365,$15f747,$0aea9f,$6199d6,$28362b,$24c2ca,$5dfc23
    .dc $0daa67,$25e347,$dea34a,$15d2c3,$0a41a4,$604d9a,$2861b5,$241981
    .dc $5c8a81,$0dd567,$23611a,$dee037,$15ac0b,$099250,$5ef3e3,$288b4f
    .dc $23621f,$5b0a13,$0e0025,$20cd92,$df19fd,$158308,$08dc92,$5d8c38
    .dc $28b2ca,$229c15,$597a56,$0e2a9a,$1e282e,$df506c,$15579d,$082059
    .dc $5c1619,$28d7f4,$21c6d6,$57dac5,$0e54bd,$1b7068,$df8354,$1529af
    .dc $075d9c,$5a9106,$28fa99,$20e1d6,$562ad8,$0e7e87,$18a5b4,$dfb282
    .dc $14f922,$069456,$58fc7b,$291a82,$1fec8b,$546a06,$0ea7f0,$15c77d
    .dc $dfddc4,$14c5d9,$05c488,$5757f3,$293773,$1ee670,$5297c3,$0ed0f0
    .dc $12d52d,$e004e7,$148fb5,$04ee3b,$55a2e5,$295130,$1dcf08,$50b383
    .dc $0ef97d,$0fce25,$e027b4,$145698,$04117f,$53dcc7,$296777,$1ca5d8
    .dc $4ebcb6,$0f218f,$0cb1be,$e045f5,$141a60,$032e6b,$52050e,$297a07
    .dc $1b6a71,$4cb2cd,$0f491c,$097f4d,$e05f73,$13daee,$024521,$501b2a
    .dc $298896,$1a1c6d,$4a9538,$0f701b,$06361d,$e073f7,$139820,$0155cc
    .dc $4e1e8f,$2992db,$18bb71,$486368,$0f9681,$02d575,$e08348,$1351d4
    .dc $0060a3,$4c0eac,$299887,$174734,$461ccc,$0fbc41,$ff5c90,$e08d41
    .dc $1307e5,$ff65e7,$49eaf1,$299949,$15bf78,$43c0d6,$0fe152,$fbcaa8
    .dc $e09184,$12ba30,$fe65e9,$47b2ce,$2994cb,$142416,$414ef8,$1005a7
    .dc $f81eea,$e08feb,$126890,$fd6106,$4565b3,$298ab4,$1274f9,$3ec6a7
    .dc $102932,$f4587e,$e08840,$1212e1,$fc57ab,$430312,$297aa8,$10b229
    .dc $3c275d,$104be4,$f07687,$e07a4e,$11b8fc,$fb4a57,$408a5f,$296444
    .dc $0edbc4,$397093,$106dae,$ec7823,$e065e3,$115abb,$fa3998,$3dfb0f
    .dc $294724,$0cf20b,$36a1cd,$108e7e,$e85c69,$e04ad0,$10f7f8,$f92611
    .dc $3b549c,$2922e0,$0af55d,$33ba90,$10ae41,$e4226e,$e028ed,$10908c
    .dc $f81078,$389683,$28f70b,$08e642,$30ba69,$10cce5,$dfc93a,$e00000
    .dc $10244f,$f6f99a,$35c046,$28c334,$06c56a,$2da0ef,$10ea4d,$db4ff9
    .dc $dfd021,$0fb31b,$f5e257,$32d16f,$2886e8,$0493b2,$2a6dc3,$1113e6
    .dc $d45bee,$df7b04,$0effab,$f440e2,$2e3c18,$281b90,$012bd8,$25701a
    .dc $11210a,$d1f993,$df5b1a,$0ec135,$f3b6a7,$2ca83a,$27f308,$000211
    .dc $23b909,$113a25,$cd1ab6,$df1606,$0e4037,$f2a478,$296d17,$279a7a
    .dc $fda4ea,$2036f9,$115193,$c81852,$deca13,$0db9ab,$f19664,$2617d6
    .dc $273781,$fb3c70,$1c9a35,$11672f,$c2f1b6,$de7798,$0d2d6e,$f08dcd
    .dc $22a831,$26c998,$f8ca9f,$18e2a8,$117ad9,$bda615,$de1ed5,$0c9b5c
    .dc $ef8c30,$1f1df2,$265035,$f651bc,$15104d,$1180e6,$b8871e,$ddb5a7
    .dc $0c0356,$ee9327,$1b78f7,$25cace,$f3d455,$11233a,$10fc80,$b726d3
    .dc $dccc2e,$0b653e,$eda465,$17b92f,$2538d7,$f15544,$0d1b9d,$107714
    .dc $b5c2ec,$dbe2d1,$0ac0f7,$ecc1bb,$13de9d,$2499c3,$eed7b6,$08f9c2
    .dc $0ff0a7,$b45b48,$daf98a,$0a1668,$ebed12,$0fe95e,$23ed00,$ec5f29
    .dc $04be10,$0f693a,$b2efd4,$da1065,$09657c,$eb2870,$0bd9aa,$233202
    .dc $e9ef73,$006915,$0ee0ce,$b1806f,$d9276c,$08ae20,$ea75ee,$07afd3
    .dc $226838,$e78cbc,$fbfb84,$0e5763,$b00d14,$d83ebc,$07f046,$e9d7bc
    .dc $036c4c,$218f15,$e53b84,$f77633,$0dcd00,$ae9588,$d75646,$072be7
    .dc $e9501c,$ff0fb1,$20a60f,$e300a4,$f2da30,$0d41a2,$ad19b8,$d66e2a
    .dc $0660ff,$e8e15e,$fa9abd,$1fac9d,$e0e13f,$ee28af,$0cb54f,$ab998c
    .dc $d58679,$058f90,$e88dda,$f60e57,$1ea23a,$dee2cc,$e9631c,$0be10a
    .dc $a950cf,$d42bd6,$044947,$e848cb,$ef1239,$1cf1d5,$dc2f83,$e218ca
metal_table:
    .dc $000000,$45cfab,$273333,$00872b,$45cfab,$273333,$010e56,$45cfab
    .dc $273333,$019581,$45cfab,$273333,$021cac,$45cfab,$273333,$02a3d7
    .dc $45cfab,$273333,$032b02,$45cfab,$273333,$03b22d,$45cfab,$273333
    .dc $043958,$45cfab,$273333,$04c083,$45cfab,$273333,$0547ae,$45cfab
    .dc $273333,$05ced9,$45cfab,$273333,$065604,$45cfab,$273333,$06dd2f
    .dc $45cfab,$273333,$07645a,$45cfab,$273333,$07eb85,$45cfab,$273333
    .dc $0872b0,$45cfab,$273333,$08f9db,$45cfab,$273333,$098106,$45cfab
    .dc $273333,$0a0831,$45cfab,$273333,$0a8f5c,$45cfab,$273333,$0b1687
    .dc $45cfab,$273333,$0b9db2,$45cfab,$273333,$0c24dd,$45cfab,$273333
    .dc $0cac08,$45cfab,$273333,$0d3333,$45cfab,$273333,$0dba5e,$45cfab
    .dc $273333,$0e4189,$45cfab,$273333,$0ec8b4,$45cfab,$273333,$0f4fdf
    .dc $45cfab,$273333,$0fd70a,$45cfab,$273333,$105e35,$45cfab,$273333
    .dc $10e560,$45cfab,$273333,$10e560,$439850,$25f49f,$10e560,$4160f5
    .dc $24b60b,$10e560,$3f299b,$237777,$10e560,$3cf240,$2238e3,$10e560
    .dc $3abae5,$20fa4f,$10e560,$38838a,$1fbbbc,$10e560,$364c30,$1e7d28
    .dc $10e560,$3414d5,$1d3e94,$10e560,$31dd7a,$1c0000,$10e560,$2fa61f
    .dc $1ac16c,$10e560,$2d6ec5,$1982d8,$10e560,$2b376a,$184444,$10e560
    .dc $29000f,$1705b0,$10e560,$26c8b4,$15c71c,$10e560,$24915a,$148888
    .dc $10e560,$2259ff,$1349f5,$10e560,$2022a4,$120b61,$10e560,$1deb49
    .dc $10cccd,$10e560,$1bb3ef,$0f8e39,$10e560,$197c94,$0e4fa5,$10e560
    .dc $174539,$0d1111,$10e560,$150dde,$0bd27d,$10e560,$12d683,$0a93e9
    .dc $10e560,$109f29,$095555,$10e560,$0e67ce,$0816c1,$10e560,$0c3073
    .dc $06d82d,$10e560,$09f918,$05999a,$10e560,$07c1be,$045b06,$10e560
    .dc $058a63,$031c72,$10e560,$035308,$01ddde,$10e560,$000000,$000000
