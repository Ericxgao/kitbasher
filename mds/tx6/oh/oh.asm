; TX6 OH - Simple606-inspired MDS voice for X.20, version 2.1.
; Gain envelopes interpolate per sample between 32-sample endpoints.
; METL: 0 = noise only; 64 = original blend; 127 = metal only. Captured on trigger.
; Controls: TUNE first, DEC second. Same parameter layout as version 2.0.
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
; Local instruction compaction; verify against retained native audio.
init:
    move #>$ffffff,m6
    move #>$ffffff,m0
    clr a r6,r0
    do #26,init_end
    move a1,x:(r0)+
init_end:
    move #>$606302,x0
    move x0,x:(r6+$d)
    rts
trigger:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move #>$ffffff,m1
    clr a
    move a1,x:(r6+$16)
    move a1,x:(r6+$17)
    move a1,x:(r6+$e)
    move a1,x:(r6+$f)
    move y:(r6+$2),a
    asr #8,a,a
    and #$3f,a
    move a1,a
    asl #2,a,a
    add #>control_1,a
    move a1,r0
    move r6,a
    move a1,r1
    do #4,control_1_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_1_end:
    move y:(r6+$1),a
    asr #8,a,a
    and #$3f,a
    clr a a1,x0
    add x0,a
    asl #3,a,a
    add x0,a
    add #>control_2,a
    move a1,r0
    move r6,a
    add #4,a
    move a1,r1
    do #9,control_2_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_2_end:
    move #>$0b79a7,x0
    move x0,x:(r6+$10)
    move #>$5cd845,x0
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
    ; M0..M5 are linear on entry (X.20 dispatcher P:$ac..$b2).
    move #>$ffffff,m6
    move x:(r6+$0),a
    tst a
    jeq silent
    sub #1,a
    move a1,x:(r6+$0)
    move a1,x0
    move x:(r6+$3),y0
    mpy y0,x0,a
    asl #23,a,a
    move #>$7fffff,x0
    cmp x0,a
    tgt x0,a
    move a1,n4
    move x:(r6+$16),r0
    move x:(r6+$17),r1
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
    move a1,n5
    move x:(r6+$13),a
    add #>$400000,a
    move a1,x0
    move x:(r6+$18),y0
    mpy y0,x0,a
    move a1,x0
    move n5,y0
    mpyr y0,x0,a
    move a1,x:(r6+$16)
    move r0,x0
    sub x0,a
    asr #5,a,a
    move a1,n0
    move n5,x0
    move x:(r6+$19),y0
    mpy y0,x0,a
    move x:(r6+$14),x0
    add x0,a
    asr a
    move a1,x:(r6+$17)
    move r1,x0
    sub x0,a
    asr #5,a,a
    move a1,n1
    move x:(r6+$d),x0
    move #>$400000,y1
    move #>$fd43fd,y0
    move #>mds_scratch_y,r5
    mpy y0,x0,a
    asr #1,a,a
    move a0,a
    add #>$c39ec3,a
    move a1,x0
    mpy x0,y1,a
    do #31,noise_end
    mpy y0,x0,a  a,y:(r5)+
    asr #1,a,a
    move a0,a
    add #>$c39ec3,a
    move a1,x0
    mpy x0,y1,a
noise_end:
    move a1,y:(r5)+
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
    move #31,m5
    move x:(r3)+,x0 y:(r5),y0
    do #32,filter_end
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
    sub y0,a  x:(r3)+,x0  y:(r5),y0
    move a1,x1
filter_end:
    move #>$ffffff,m5
    move b1,x:(r6+$e)
    move x1,x:(r6+$f)
    move #>mds_scratch_x,r4
    move x:(r6+$7),y0
    move x:(r6+$8),y1
    move x:(r6+$9),x0
    do #32,tone0_end
    mpy y0,x0,a
    asl a
    sub y1,a  y0,y1
    move a,x:(r4)+  a,y0
tone0_end:
    move y0,x:(r6+$7)
    move y1,x:(r6+$8)
    move #>mds_scratch_x,r4
    move x:(r6+$a),y0
    move x:(r6+$b),y1
    move x:(r6+$c),x0
    do #32,tone1_end
    mpy y0,x0,a  x:(r4),b
    asl a
    sub y1,a  y0,y1
    add b,a  a1,y0
    move a1,x:(r4)+
tone1_end:
    move y0,x:(r6+$a)
    move y1,x:(r6+$b)
    move r0,y1
    move r1,x0
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #32,mix_end
    move x:(r3)+,x1 y:(r5)+,y0
    mpy y0,x0,a  (r1)+n1
    mac y1,x1,a  (r0)+n0
    asl a  r0,y1
    asl a  r1,x0
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
    .dc $00007a,$6ac3ad,$7cd64a,$010d59,$00007a,$6ac3ad,$7cd64a,$010d59
    .dc $00007a,$6ac3ad,$7cd64a,$010d59,$00007a,$6ac3ad,$7cd64a,$010d59
    .dc $00009a,$6ac3ad,$7d7b98,$00d5c7,$0000c0,$6ac3ad,$7dfb7c,$00ab07
    .dc $0000e6,$6ac3ad,$7e5105,$008e87,$00010d,$6ac3ad,$7e8e39,$007a2b
    .dc $000133,$6ac3ad,$7ebc2f,$006ae3,$000159,$6ac3ad,$7ee00c,$005f04
    .dc $000180,$6ac3ad,$7efcb0,$005584,$0001a6,$6ac3ad,$7f1433,$004dbe
    .dc $0001cc,$6ac3ad,$7f27c2,$004744,$0001f3,$6ac3ad,$7f3857,$0041c7
    .dc $000219,$6ac3ad,$7f4693,$003d15,$00023f,$6ac3ad,$7f52e2,$003902
    .dc $000266,$6ac3ad,$7f5db4,$003572,$00028c,$6ac3ad,$7f6739,$00324e
    .dc $0002b2,$6ac3ad,$7f6faf,$002f8e,$0002d9,$6ac3ad,$7f7747,$002f8e
    .dc $0002ff,$6ac3ad,$7f7e20,$002f8e,$000325,$6ac3ad,$7f844a,$002f8e
    .dc $00034c,$6ac3ad,$7f89e5,$002f8e,$000372,$6ac3ad,$7f8f00,$002f8e
    .dc $000398,$6ac3ad,$7f93bc,$002f8e,$0003be,$6ac3ad,$7f9809,$002f8e
    .dc $0003e5,$6b365b,$7f9c06,$002f8e,$00040b,$6beb11,$7f9fb3,$002f8e
    .dc $000431,$6c93fa,$7fa331,$002f8e,$000458,$6d3226,$7fa65e,$002f8e
    .dc $00047e,$6dc694,$7fa95c,$002f8e,$0004a4,$6e5232,$7fac1b,$002f8e
    .dc $0004cb,$6ed5ac,$7faeb9,$002f8e,$0004f1,$6f51b8,$7fb138,$002f8e
    .dc $000517,$6fc700,$7fb386,$002f8e,$00053e,$703609,$7fb5b5,$002f8e
    .dc $000564,$709f3f,$7fb7c4,$002f8e,$00058a,$71032e,$7fb9b3,$002f8e
    .dc $0005b1,$71621e,$7fbb92,$002f8e,$0005d7,$71bc81,$7fbd51,$002f8e
    .dc $0005fd,$7212a2,$7fbf00,$002f8e,$000624,$7264cf,$7fc08f,$002f8e
    .dc $00064a,$72b346,$7fc20f,$002f8e,$000670,$72fe47,$7fc37e,$002f8e
    .dc $000697,$734614,$7fc4dd,$002f8e,$0006bd,$738ad3,$7fc62d,$002f8e
    .dc $0006e3,$73ccb8,$7fc77c,$002f8e,$00071d,$742aae,$7fc93b,$002f8e
    .dc $000730,$7448bc,$7fc9cb,$002f8e,$000756,$74831b,$7fcaeb,$002f8e
    .dc $00077c,$74bb3e,$7fcbfa,$002f8e,$0007a3,$74f14f,$7fccfa,$002f8e
    .dc $0007c9,$752559,$7fcdf9,$002f8e,$0007ef,$755785,$7fcee9,$002f8e
    .dc $000816,$7587ef,$7fcfd9,$002f8e,$00083c,$75b6a2,$7fd0b8,$002f8e
    .dc $000862,$75e3ca,$7fd188,$002f8e,$000889,$760f64,$7fd258,$002f8e
    .dc $0008af,$76398d,$7fd328,$002f8e,$0008d5,$766251,$7fd3e7,$002f8e
    .dc $0008fc,$7689bf,$7fd4a7,$002f8e,$000922,$76b001,$7fd557,$002f8e
    .dc $000948,$76d507,$7fd607,$002f8e,$000982,$770a86,$7fd706,$002f8e
control_2:
    .dc $0ce378,$46f954,$dbb3d1,$179895,$146528,$749148,$23629b,$29623c
    .dc $732a51,$0d1a80,$455d63,$dc1ec2,$1791f2,$1429ba,$7410bb,$2399f9
    .dc $2975c0,$729a49,$0d51ed,$43b61e,$dc897c,$178a9d,$13eb1a,$738aa1
    .dc $23d1a1,$298556,$720411,$0d89be,$420334,$dcf3e9,$17828c,$13a926
    .dc $72febf,$240987,$2990b5,$716767,$0dc1f0,$404450,$dd5df2,$1779b3
    .dc $1363bd,$726cd8,$2441a1,$29978f,$70c406,$0dfa82,$3e7918,$ddc780
    .dc $177008,$131aba,$71d4ac,$2479e1,$299993,$7019aa,$0e336f,$3ca134
    .dc $de307a,$17657f,$12cdfa,$7135fa,$24b23b,$29966d,$6f6808,$0e6cb7
    .dc $3abc4b,$de98bb,$175a0d,$127d58,$70907c,$24eaa0,$298dc6,$6eaed6
    .dc $0ea656,$38c9ea,$df0045,$174da5,$1228b0,$6fe3ec,$252301,$297f3f
    .dc $6dedc6,$0ee04c,$36c9b4,$df66ef,$174039,$11cfdd,$6f3000,$255b4d
    .dc $296a7a,$6d2487,$0f1a95,$34bb3a,$dfcca1,$1731bc,$1172b6,$6e746c
    .dc $259373,$294f14,$6c52c5,$0f5530,$329e10,$e0313e,$172220,$111117
    .dc $6db0e2,$25cb5f,$292ca3,$6b782b,$0f901c,$3071be,$e094ac,$171155
    .dc $10aad9,$6ce50f,$2602fe,$2902bc,$6a945e,$0fcb57,$2e35ca,$e0f6cd
    .dc $16ff4c,$103fd4,$6c10a0,$263a3a,$28d0f1,$69a702,$1006e0,$2be9b4
    .dc $e15786,$16ebf6,$0fcfe2,$6b333c,$2670fb,$2896cc,$68afb9,$1042b7
    .dc $298cf4,$e1b6b9,$16d73f,$0f5adb,$6a4c8a,$26a729,$2853d8,$67ae20
    .dc $107edb,$271efe,$e2144a,$16c118,$0ee09b,$695c2c,$26dcaa,$28079a
    .dc $66a1d2,$10bb4c,$249f3b,$e27019,$16a96e,$0e60fb,$6861c3,$271162
    .dc $27b193,$658a66,$10f809,$220d11,$e2ca0a,$16902e,$0ddbd6,$675cec
    .dc $274533,$275141,$646771,$113514,$1f67d9,$e321fd,$167543,$0d5108
    .dc $664d3f,$2777fd,$26e620,$633886,$11726f,$1caee5,$e377d6,$165899
    .dc $0cc06e,$653255,$27a9a0,$266fa8,$61fd31,$11b019,$19e17e,$e3cb75
    .dc $163a1b,$0c29e8,$640bc0,$27d9f7,$25ed50,$60b4ff,$11ee16,$16fee2
    .dc $e41cbb,$1619b2,$0b8d57,$62d911,$2808de,$255e8a,$5f5f79,$122c69
    .dc $140642,$e46b8d,$15f747,$0aea9f,$6199d6,$28362b,$24c2ca,$5dfc23
    .dc $126b13,$10f6c4,$e4b7cc,$15d2c3,$0a41a4,$604d9a,$2861b5,$241981
    .dc $5c8a81,$12aa1b,$0dcf80,$e5015d,$15ac0b,$099250,$5ef3e3,$288b4f
    .dc $23621f,$5b0a13,$12e984,$0a8f81,$e54824,$158308,$08dc92,$5d8c38
    .dc $28b2ca,$229c15,$597a56,$132955,$0735c2,$e58c06,$15579d,$082059
    .dc $5c1619,$28d7f4,$21c6d6,$57dac5,$136994,$03c12b,$e5ccee,$1529af
    .dc $075d9c,$5a9106,$28fa99,$20e1d6,$562ad8,$13aa47,$003094,$e60ac3
    .dc $14f922,$069456,$58fc7b,$291a82,$1fec8b,$546a06,$13eb7a,$fc82bf
    .dc $e64574,$14c5d9,$05c488,$5757f3,$293773,$1ee670,$5297c3,$142d34
    .dc $f8b65a,$e67cf3,$148fb5,$04ee3b,$55a2e5,$295130,$1dcf08,$50b383
    .dc $146f83,$f4c9fa,$e6b134,$145698,$04117f,$53dcc7,$296777,$1ca5d8
    .dc $4ebcb6,$14b273,$f0bc19,$e6e234,$141a60,$032e6b,$52050e,$297a07
    .dc $1b6a71,$4cb2cd,$14f614,$ec8b17,$e70ff2,$13daee,$024521,$501b2a
    .dc $298896,$1a1c6d,$4a9538,$153a74,$e83531,$e73a8e,$139820,$0155cc
    .dc $4e1e8f,$2992db,$18bb71,$486368,$157faf,$e3b876,$e761ed,$1351d4
    .dc $0060a3,$4c0eac,$299887,$174734,$461ccc,$15c5db,$df12d1,$e78648
    .dc $1307e5,$ff65e7,$49eaf1,$299949,$15bf78,$43c0d6,$160d16,$da41f9
    .dc $e7a7c6,$12ba30,$fe65e9,$47b2ce,$2994cb,$142416,$414ef8,$165589
    .dc $d5435b,$e7c6a6,$126890,$fd6106,$4565b3,$298ab4,$1274f9,$3ec6a7
    .dc $169f64,$d01417,$e7e31d,$1212e1,$fc57ab,$430312,$297aa8,$10b229
    .dc $3c275d,$16eae3,$cab0ff,$e7fd9c,$11b8fc,$fb4a57,$408a5f,$296444
    .dc $0edbc4,$397093,$16ec18,$c6ccab,$e7b3f8,$115abb,$fa3998,$3dfb0f
    .dc $294724,$0cf20b,$36a1cd,$16736f,$c5904a,$e6ccbd,$10f7f8,$f92611
    .dc $3b549c,$2922e0,$0af55d,$33ba90,$15f9a3,$c450ef,$e5e531,$10908c
    .dc $f81078,$389683,$28f70b,$08e642,$30ba69,$157eb7,$c30e8e,$e4fd63
    .dc $10244f,$f6f99a,$35c046,$28c334,$06c56a,$2da0ef,$1502b7,$c1c8fc
    .dc $e41520,$0fb31b,$f5e257,$32d16f,$2886e8,$0493b2,$2a6dc3,$1446b0
    .dc $bfdab4,$e2b836,$0effab,$f440e2,$2e3c18,$281b90,$012bd8,$25701a
    .dc $14077b,$bf3454,$e243b8,$0ec135,$f3b6a7,$2ca83a,$27f308,$000211
    .dc $23b909,$13883f,$bde536,$e15ad0,$0e4037,$f2a478,$296d17,$279a7a
    .dc $fda4ea,$2036f9,$1307f9,$bc92c4,$e0719d,$0db9ab,$f19664,$2617d6
    .dc $273781,$fb3c70,$1c9a35,$1286a6,$bb3d00,$df885f,$0d2d6e,$f08dcd
    .dc $22a831,$26c998,$f8ca9f,$18e2a8,$12044a,$b9e3cc,$de9f09,$0c9b5c
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
    .dc $000000,$45cfab,$248312,$00872b,$45cfab,$248312,$010e56,$45cfab
    .dc $248312,$019581,$45cfab,$248312,$021cac,$45cfab,$248312,$02a3d7
    .dc $45cfab,$248312,$032b02,$45cfab,$248312,$03b22d,$45cfab,$248312
    .dc $043958,$45cfab,$248312,$04c083,$45cfab,$248312,$0547ae,$45cfab
    .dc $248312,$05ced9,$45cfab,$248312,$065604,$45cfab,$248312,$06dd2f
    .dc $45cfab,$248312,$07645a,$45cfab,$248312,$07eb85,$45cfab,$248312
    .dc $0872b0,$45cfab,$248312,$08f9db,$45cfab,$248312,$098106,$45cfab
    .dc $248312,$0a0831,$45cfab,$248312,$0a8f5c,$45cfab,$248312,$0b1687
    .dc $45cfab,$248312,$0b9db2,$45cfab,$248312,$0c24dd,$45cfab,$248312
    .dc $0cac08,$45cfab,$248312,$0d3333,$45cfab,$248312,$0dba5e,$45cfab
    .dc $248312,$0e4189,$45cfab,$248312,$0ec8b4,$45cfab,$248312,$0f4fdf
    .dc $45cfab,$248312,$0fd70a,$45cfab,$248312,$105e35,$45cfab,$248312
    .dc $10e560,$45cfab,$248312,$10e560,$439850,$235a57,$10e560,$4160f5
    .dc $22319b,$10e560,$3f299b,$2108e0,$10e560,$3cf240,$1fe024,$10e560
    .dc $3abae5,$1eb769,$10e560,$38838a,$1d8ead,$10e560,$364c30,$1c65f2
    .dc $10e560,$3414d5,$1b3d36,$10e560,$31dd7a,$1a147b,$10e560,$2fa61f
    .dc $18ebbf,$10e560,$2d6ec5,$17c304,$10e560,$2b376a,$169a48,$10e560
    .dc $29000f,$15718d,$10e560,$26c8b4,$1448d1,$10e560,$24915a,$132016
    .dc $10e560,$2259ff,$11f75a,$10e560,$2022a4,$10ce9f,$10e560,$1deb49
    .dc $0fa5e3,$10e560,$1bb3ef,$0e7d28,$10e560,$197c94,$0d546c,$10e560
    .dc $174539,$0c2bb1,$10e560,$150dde,$0b02f5,$10e560,$12d683,$09da3a
    .dc $10e560,$109f29,$08b17e,$10e560,$0e67ce,$0788c3,$10e560,$0c3073
    .dc $066007,$10e560,$09f918,$05374c,$10e560,$07c1be,$040e90,$10e560
    .dc $058a63,$02e5d5,$10e560,$035308,$01bd19,$10e560,$000000,$000000
