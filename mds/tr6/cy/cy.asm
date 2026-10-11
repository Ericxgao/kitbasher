; TR6 CY - Simple606-inspired MDS voice for X.20, version 1.1.
; New layer controls preserve version 1.0 audio at their defaults.
; BELL: 0 = remove this layer; 127 = original layer level. Captured on trigger.
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

; Local instruction compaction; verify against retained native audio.
init:
    move #>$ffffff,m6
    move #>$ffffff,m0
    clr a r6,r0
    do #24,init_end
    move a1,x:(r0)+
init_end:
    move #>$606303,x0
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
    asl a
    asl a
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
    asl a
    asl a
    asl a
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
    move #>$07ef9e,x0
    move x0,x:(r6+$10)
    move #>$5b4395,x0
    move x0,x:(r6+$11)
    move #>$7fffff,x0
    move x0,x:(r6+$12)
    move #>$2ca3d7,x0
    move x0,x:(r6+$14)
    move y:(r6+$3),a
    asr #8,a,a
    add #>layer_table,a
    move a1,r0
    move p:(r0)+,x0
    move x0,x:(r6+$13)
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
    move #>$7e7620,y0
    mpyr y0,x0,a
    move a1,x:(r6+$13)
    move x:(r6+$14),x0
    move #>$6eb582,y0
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
    move #>$170a3e,y0
    mpy y0,x0,a
    move a1,x0
    move x:(r6+$15),y0
    mpyr y0,x0,a
    move a1,x:(r6+$16)
    move x:(r6+$15),x0
    move #>$347ae1,y0
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
    .dc $000095,$6eb582,$7eb9a6,$00dcc1,$000095,$6eb582,$7eb9a6,$00dcc1
    .dc $000095,$6eb582,$7eb9a6,$00dcc1,$000095,$6eb582,$7eb9a6,$00dcc1
    .dc $0000bb,$6eb582,$7efcb0,$00af3b,$0000ea,$6eb582,$7f3064,$008c2f
    .dc $000119,$6eb582,$7f52e2,$0074d2,$000148,$6eb582,$7f6b94,$006422
    .dc $000177,$6ed5ac,$7f7e20,$00579c,$0001a5,$709f3f,$7f8c83,$004de0
    .dc $0001d4,$7212a2,$7f9809,$004616,$000203,$734614,$7fa172,$003fb7
    .dc $000232,$7448bc,$7fa95c,$003a68,$000260,$752559,$7faff8,$0035ea
    .dc $00028f,$75e3ca,$7fb5b5,$003210,$0002be,$7689bf,$7fbaa2,$002eba
    .dc $0002ed,$771bc5,$7fbf00,$002bce,$00031b,$779d35,$7fc2ce,$00293b
    .dc $00034a,$7810a9,$7fc62d,$0026f0,$000379,$787864,$7fc93b,$0024e4
    .dc $0003a8,$78d600,$7fcbfa,$00230b,$0003d6,$792afe,$7fce79,$002160
    .dc $000405,$79786e,$7fd0b8,$001fdc,$000434,$79bf43,$7fd2c8,$001e79
    .dc $000463,$7a0068,$7fd4a7,$001db9,$000491,$7a3c6b,$7fd667,$001db9
    .dc $0004c0,$7a73ef,$7fd7f6,$001db9,$0004ef,$7aa768,$7fd976,$001db9
    .dc $00051e,$7ad74d,$7fdad5,$001db9,$00054c,$7b03e5,$7fdc25,$001db9
    .dc $00057b,$7b2da8,$7fdd55,$001db9,$0005aa,$7b54b4,$7fde74,$001db9
    .dc $0005d9,$7b7961,$7fdf74,$001db9,$000607,$7b9bec,$7fe074,$001db9
    .dc $000636,$7bbc62,$7fe164,$001db9,$000665,$7bdb10,$7fe243,$001db9
    .dc $000694,$7bf813,$7fe313,$001db9,$0006c2,$7c1389,$7fe3e3,$001db9
    .dc $0006f1,$7c2d8f,$7fe4a3,$001db9,$000720,$7c4645,$7fe553,$001db9
    .dc $00074f,$7c5dc9,$7fe5f3,$001db9,$00077d,$7c7429,$7fe6a2,$001db9
    .dc $0007ac,$7c8984,$7fe732,$001db9,$0007db,$7c9dd9,$7fe7d2,$001db9
    .dc $00080a,$7cb148,$7fe852,$001db9,$000838,$7cc3cf,$7fe8e2,$001db9
    .dc $000867,$7cd59e,$7fe962,$001db9,$0008ad,$7ceee2,$7fea12,$001db9
    .dc $0008c5,$7cf701,$7fea52,$001db9,$0008f3,$7d06a4,$7feac2,$001db9
    .dc $000922,$7d15bc,$7feb32,$001db9,$000951,$7d2429,$7feb92,$001db9
    .dc $000980,$7d321b,$7fec02,$001db9,$0009ae,$7d3f81,$7fec61,$001db9
    .dc $0009dd,$7d4c6b,$7fecb1,$001db9,$000a0c,$7d58da,$7fed11,$001db9
    .dc $000a3b,$7d64db,$7fed61,$001db9,$000a69,$7d7070,$7fedc1,$001db9
    .dc $000a98,$7d7b98,$7fee11,$001db9,$000ac7,$7d8672,$7fee61,$001db9
    .dc $000af6,$7d90e0,$7feea1,$001db9,$000b24,$7d9b00,$7feef1,$001db9
    .dc $000b53,$7da4d2,$7fef31,$001db9,$000b99,$7db2f1,$7fefa1,$001db9
control_2:
    .dc $0ec9f0,$515ce0,$dd8074,$179895,$146528,$749148,$23629b,$29623c
    .dc $732a51,$0f1235,$50153c,$de0e27,$1791f2,$1429ba,$7410bb,$2399f9
    .dc $2975c0,$729a49,$0f5b74,$4ec49a,$de9d5a,$178a9d,$13eb1a,$738aa1
    .dc $23d1a1,$298556,$720411,$0fa5af,$4d6ab2,$df2e05,$17828c,$13a926
    .dc $72febf,$240987,$2990b5,$716767,$0ff0e9,$4c073c,$dfc026,$1779b3
    .dc $1363bd,$726cd8,$2441a1,$29978f,$70c406,$103d24,$4a99eb,$e053ba
    .dc $177008,$131aba,$71d4ac,$2479e1,$299993,$7019aa,$108a66,$49226e
    .dc $e0e8bb,$17657f,$12cdfa,$7135fa,$24b23b,$29966d,$6f6808,$10d8af
    .dc $47a072,$e17f29,$175a0d,$127d58,$70907c,$24eaa0,$298dc6,$6eaed6
    .dc $112806,$46139e,$e216fd,$174da5,$1228b0,$6fe3ec,$252301,$297f3f
    .dc $6dedc6,$11786e,$447b96,$e2b037,$174039,$11cfdd,$6f3000,$255b4d
    .dc $296a7a,$6d2487,$11c9ed,$42d7fa,$e34ad4,$1731bc,$1172b6,$6e746c
    .dc $259373,$294f14,$6c52c5,$121c88,$412864,$e3e6d2,$172220,$111117
    .dc $6db0e2,$25cb5f,$292ca3,$6b782b,$127046,$3f6c68,$e4842f,$171155
    .dc $10aad9,$6ce50f,$2602fe,$2902bc,$6a945e,$12c52c,$3da396,$e522ec
    .dc $16ff4c,$103fd4,$6c10a0,$263a3a,$28d0f1,$69a702,$131b44,$3bcd76
    .dc $e5c309,$16ebf6,$0fcfe2,$6b333c,$2670fb,$2896cc,$68afb9,$137296
    .dc $39e989,$e66487,$16d73f,$0f5adb,$6a4c8a,$26a729,$2853d8,$67ae20
    .dc $13cb2c,$37f74b,$e70768,$16c118,$0ee09b,$695c2c,$26dcaa,$28079a
    .dc $66a1d2,$14250f,$35f62e,$e7abaf,$16a96e,$0e60fb,$6861c3,$271162
    .dc $27b193,$658a66,$14804c,$33e59e,$e85163,$16902e,$0ddbd6,$675cec
    .dc $274533,$275141,$646771,$14dcf1,$31c4f8,$e8f88a,$167543,$0d5108
    .dc $664d3f,$2777fd,$26e620,$633886,$153b0b,$2f9395,$e9a12e,$165899
    .dc $0cc06e,$653255,$27a9a0,$266fa8,$61fd31,$159aab,$2d50be,$ea4b56
    .dc $163a1b,$0c29e8,$640bc0,$27d9f7,$25ed50,$60b4ff,$15fbe3,$2afbb3
    .dc $eaf714,$1619b2,$0b8d57,$62d911,$2808de,$255e8a,$5f5f79,$165ec7
    .dc $2893a5,$eba474,$15f747,$0aea9f,$6199d6,$28362b,$24c2ca,$5dfc23
    .dc $16c36c,$2617b4,$ec538c,$15d2c3,$0a41a4,$604d9a,$2861b5,$241981
    .dc $5c8a81,$1729ed,$2386f6,$ed046c,$15ac0b,$099250,$5ef3e3,$288b4f
    .dc $23621f,$5b0a13,$179263,$20e063,$edb73e,$158308,$08dc92,$5d8c38
    .dc $28b2ca,$229c15,$597a56,$17fceb,$1e22e5,$ee6c28,$15579d,$082059
    .dc $5c1619,$28d7f4,$21c6d6,$57dac5,$1869aa,$1b4d5c,$ef2330,$1529af
    .dc $075d9c,$5a9106,$28fa99,$20e1d6,$562ad8,$18d8c8,$185e81,$efdc86
    .dc $14f922,$069456,$58fc7b,$291a82,$1fec8b,$546a06,$194a68,$1554ec
    .dc $f09874,$14c5d9,$05c488,$5757f3,$293773,$1ee670,$5297c3,$19bebe
    .dc $122f21,$f15729,$148fb5,$04ee3b,$55a2e5,$295130,$1dcf08,$50b383
    .dc $1a35fc,$0eeb7a,$f218f1,$145698,$04117f,$53dcc7,$296777,$1ca5d8
    .dc $4ebcb6,$1ab064,$0b8833,$f2ddf3,$141a60,$032e6b,$52050e,$297a07
    .dc $1b6a71,$4cb2cd,$1b2e31,$08034c,$f3a6b8,$13daee,$024521,$501b2a
    .dc $298896,$1a1c6d,$4a9538,$1bafb2,$045a94,$f4739f,$139820,$0155cc
    .dc $4e1e8f,$2992db,$18bb71,$486368,$1c3541,$008ba5,$f54504,$1351d4
    .dc $0060a3,$4c0eac,$299887,$174734,$461ccc,$1cbf43,$fc93c4,$f61b7f
    .dc $1307e5,$ff65e7,$49eaf1,$299949,$15bf78,$43c0d6,$1d4e2b,$f86fec
    .dc $f6f7ac,$12ba30,$fe65e9,$47b2ce,$2994cb,$142416,$414ef8,$1de283
    .dc $f41ca5,$f7da3f,$126890,$fd6106,$4565b3,$298ab4,$1274f9,$3ec6a7
    .dc $1e7cee,$ef960a,$f8c405,$1212e1,$fc57ab,$430312,$297aa8,$10b229
    .dc $3c275d,$1f1e30,$ead792,$f9b5e1,$11b8fc,$fb4a57,$408a5f,$296444
    .dc $0edbc4,$397093,$1fc736,$e5dc0e,$fab0c6,$115abb,$fa3998,$3dfb0f
    .dc $294724,$0cf20b,$36a1cd,$207923,$e09d81,$fbb59a,$10f7f8,$f92611
    .dc $3b549c,$2922e0,$0af55d,$33ba90,$20310f,$df5826,$fb0694,$10908c
    .dc $f81078,$389683,$28f70b,$08e642,$30ba69,$1fd4ae,$de5e3c,$fa3553
    .dc $10244f,$f6f99a,$35c046,$28c334,$06c56a,$2da0ef,$1f76ee,$dd6147
    .dc $f9628a,$0fb31b,$f5e257,$32d16f,$2886e8,$0493b2,$2a6dc3,$1ee7bf
    .dc $dbe020,$f82394,$0effab,$f440e2,$2e3c18,$281b90,$012bd8,$25701a
    .dc $1eb755,$db5e3e,$f7b891,$0ec135,$f3b6a7,$2ca83a,$27f308,$000211
    .dc $23b909,$1e5578,$da5846,$f6e1a1,$0e4037,$f2a478,$296d17,$279a7a
    .dc $fda4ea,$2036f9,$1df244,$d94f48,$f60950,$0db9ab,$f19664,$2617d6
    .dc $273781,$fb3c70,$1c9a35,$1d8db9,$d8434d,$f52fbd,$0d2d6e,$f08dcd
    .dc $22a831,$26c998,$f8ca9f,$18e2a8,$1d27da,$d73458,$f454f2,$0c9b5c
    .dc $ef8c30,$1f1df2,$265035,$f651bc,$15104d,$1cc0aa,$d6226c,$f378ff
    .dc $0c0356,$ee9327,$1b78f7,$25cace,$f3d455,$11233a,$1c582a,$d50d89
    .dc $f29bed,$0b653e,$eda465,$17b92f,$2538d7,$f15544,$0d1b9d,$1bee5e
    .dc $d3f5b1,$f1bdcc,$0ac0f7,$ecc1bb,$13de9d,$2499c3,$eed7b6,$08f9c2
    .dc $1b834a,$d2dae6,$f0dea7,$0a1668,$ebed12,$0fe95e,$23ed00,$ec5f29
    .dc $04be10,$1b16f0,$d1bd28,$effe8c,$09657c,$eb2870,$0bd9aa,$233202
    .dc $e9ef73,$006915,$1aa955,$d09c7a,$ef1d88,$08ae20,$ea75ee,$07afd3
    .dc $226838,$e78cbc,$fbfb84,$1a3a7a,$cf78d9,$ee3ba5,$07f046,$e9d7bc
    .dc $036c4c,$218f15,$e53b84,$f77633,$19ca64,$ce5248,$ed58f5,$072be7
    .dc $e9501c,$ff0fb1,$20a60f,$e300a4,$f2da30,$195917,$cd28c4,$ec757e
    .dc $0660ff,$e8e15e,$fa9abd,$1fac9d,$e0e13f,$ee28af,$18e694,$cbfc4d
    .dc $eb9155,$058f90,$e88dda,$f60e57,$1ea23a,$dee2cc,$e9631c,$18389a
    .dc $ca33fd,$ea39c4,$044947,$e848cb,$ef1239,$1cf1d5,$dc2f83,$e218ca
layer_table:
    .dc $000000,$00d99a,$01b333,$028ccd,$036666,$044000,$05199a,$05f333
    .dc $06cccd,$07a666,$088000,$09599a,$0a3333,$0b0ccd,$0be666,$0cc000
    .dc $0d999a,$0e7333,$0f4ccd,$102666,$110000,$11d999,$12b333,$138ccd
    .dc $146666,$154000,$161999,$16f333,$17cccd,$18a666,$198000,$1a5999
    .dc $1b3333,$1c0ccd,$1ce666,$1dc000,$1e9999,$1f7333,$204ccd,$212666
    .dc $220000,$22d999,$23b333,$248ccd,$256666,$264000,$271999,$27f333
    .dc $28cccc,$29a666,$2a8000,$2b5999,$2c3333,$2d0ccc,$2de666,$2ec000
    .dc $2f9999,$307333,$314ccc,$322666,$330000,$33d999,$34b333,$366666
