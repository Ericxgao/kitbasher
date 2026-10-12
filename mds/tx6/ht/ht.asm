; TX6 HT - Simple606-inspired MDS voice for X.20, version 2.1.
; 44.1 kHz high tom: two damped tonal modes and full-rate filtered noise. The quietest third mode is omitted to preserve the CPU budget.
; Controls start with TUNE, DEC. Gain envelopes interpolate per sample.
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
; 0b: b0
; 0c: a1
; 0d: a2
; 0e: rng
; 0f: z1
; 10: z2
; 11: fast
; 12: slow
; 13: noiseamp
; 14: qbase
; 15: glide
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
    move #>$006062,x0
    move x0,x:(r6+$e)
    rts
trigger:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move #>$ffffff,m1
    clr a
    move a1,x:(r6+$f)
    move a1,x:(r6+$10)
    move a1,x:(r6+$13)
    move a1,x:(r6+$1c)
    move y:(r6+$2),a
    asr #8,a,a
    and #$3f,a
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
    and #$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add x0,a
    asl a
    add x0,a
    add #>control_2,a
    move a1,r0
    move r6,a
    add #7,a
    move a1,r1
    do #7,control_2_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_2_end:
    move #>$1713ec,x0
    move x0,x:(r6+$18)
    move #>$04047f,x0
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
    move x0,x:(r6+$11)
    move p:(r0)+,x0
    move x0,x:(r6+$12)
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
    ; M0..M5 are linear on entry (X.20 dispatcher P:$ac..$b2).
    move #>$ffffff,m6
    move x:(r6+$0),a
    tst a
    jeq silent
    sub #1,a
    move a1,x:(r6+$0)
    move x:(r6+$e),x0
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
    move x0,x:(r6+$e)
    move #>mds_scratch_x,r3
    move x:(r6+$b),x0
    move x0,x:(r3)+
    move x:(r6+$c),x0
    move x0,x:(r3)+
    move x:(r6+$d),x0
    move x0,x:(r3)+
    move x:(r6+$f),b
    move x:(r6+$10),x1
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
    move b1,x:(r6+$f)
    move x1,x:(r6+$10)
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
    move x:(r6+$11),x0
    move x:(r6+$1),y0
    mpyr y0,x0,a
    move a1,x:(r6+$11)
    move x:(r6+$12),x0
    move x:(r6+$2),y0
    mpyr y0,x0,a
    move a1,x:(r6+$12)
    move x:(r6+$11),x0
    move x:(r6+$12),a
    add x0,a
    move x:(r6+$13),x0
    move a1,b
    move b1,x:(r6+$13)
    sub x0,b
    asr #5,b,b
    move b1,n1
    move x0,r1
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #32,mix_end
    move x:(r3)+,x1 y:(r5)+,y0
    mpy y0,x0,a  (r1)+n1
    add x1,a  r1,x0
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
    .dc $00001a,$007cf1,$4956ce,$7e2c7a,$7ebbba,$3e2fcf,$3ebd55,$00001a
    .dc $007cf1,$4956ce,$7e2c7a,$7ebbba,$3e2fcf,$3ebd55,$00001a,$007cf1
    .dc $4956ce,$7e2c7a,$7ebbba,$3e2fcf,$3ebd55,$00001a,$007cf1,$4956ce
    .dc $7e2c7a,$7ebbba,$3e2fcf,$3ebd55,$000021,$018a11,$52442d,$7e8c5a
    .dc $7efe58,$3e8e76,$3eff5c,$000029,$03b9ff,$59defb,$7ed658,$7f31b7
    .dc $3ed7b2,$3f325d,$000031,$06b802,$5f53d5,$7f07c4,$7f5401,$3f08b4
    .dc $3f5475,$000039,$0a3c74,$636d36,$7f2b1c,$7f6c85,$3f2bcd,$3f6cda
    .dc $000041,$0e0971,$669dc1,$7f45a5,$7f7eeb,$3f462d,$3f7f2c,$000049
    .dc $11f1c8,$692ae9,$7f5a4d,$7f8d3c,$3f5ab8,$3f8d70,$000052,$15d71d
    .dc $6b411b,$7f6ad5,$7f98b2,$3f6b2c,$3f98db,$00005a,$19a62b,$6cfe0d
    .dc $7f785d,$7fa212,$3f78a5,$3fa235,$000062,$1d5369,$6e7658,$7f83a5
    .dc $7fa9e4,$3f83e2,$3faa01,$00006a,$20d87d,$6fb8b4,$7f8d32,$7fb081
    .dc $3f8d65,$3fb09a,$000072,$243271,$70cff0,$7f9562,$7fb62d,$3f958e
    .dc $3fb643,$00007a,$276081,$71c425,$7f9c7b,$7fbb18,$3f9ca1,$3fbb2a
    .dc $000082,$2a6343,$729b84,$7fa2b1,$7fbf65,$3fa2d3,$3fbf76,$00008a
    .dc $2d3c23,$735ae0,$7fa82c,$7fc331,$3fa84a,$3fc340,$000092,$2fed07
    .dc $740605,$7fad0c,$7fc691,$3fad26,$3fc69e,$00009a,$327812,$749ffd
    .dc $7fb168,$7fc996,$3fb180,$3fc9a2,$0000a3,$34df7f,$752b3e,$7fb555
    .dc $7fcc4e,$3fb56b,$3fcc59,$0000ab,$372587,$75a9cb,$7fb8e2,$7fcec4
    .dc $3fb8f6,$3fcece,$0000b3,$394c57,$761d4d,$7fbc1d,$7fd101,$3fbc2f
    .dc $3fd109,$0000bb,$3b5601,$768728,$7fbf10,$7fd30b,$3fbf20,$3fd313
    .dc $0000c3,$3d447b,$76e883,$7fc1c4,$7fd4eb,$3fc1d3,$3fd4f2,$0000cb
    .dc $3f1999,$77425b,$7fc440,$7fd6a3,$3fc44e,$3fd6aa,$0000d3,$40d714
    .dc $779586,$7fc68c,$7fd83a,$3fc699,$3fd841,$0000db,$427e81,$77e2bc
    .dc $7fc8ac,$7fd9b3,$3fc8b8,$3fd9b9,$0000e3,$441159,$782a9b,$7fcaa6
    .dc $7fdb11,$3fcab1,$3fdb17,$0000ec,$4590fb,$786dab,$7fcc7c,$7fdc57
    .dc $3fcc87,$3fdc5c,$0000f4,$46fea6,$78ac65,$7fce34,$7fdd87,$3fce3d
    .dc $3fdd8c,$0000fc,$485b86,$78e730,$7fcfcf,$7fdea4,$3fcfd8,$3fdea8
    .dc $000104,$49a8ac,$791e68,$7fd150,$7fdfaf,$3fd158,$3fdfb3,$00010c
    .dc $4ae716,$79525f,$7fd2ba,$7fe0a9,$3fd2c2,$3fe0ad,$000114,$4c17ae
    .dc $79835c,$7fd40e,$7fe195,$3fd416,$3fe199,$00011c,$4d3b4c,$79b19e
    .dc $7fd550,$7fe273,$3fd557,$3fe277,$000124,$4e52b9,$79dd5e,$7fd67f
    .dc $7fe345,$3fd686,$3fe349,$00012c,$4f5ead,$7a06cf,$7fd79e,$7fe40c
    .dc $3fd7a4,$3fe40f,$000134,$505fd5,$7a2e1f,$7fd8ae,$7fe4c8,$3fd8b4
    .dc $3fe4cb,$00013d,$5156ce,$7a5377,$7fd9b0,$7fe57b,$3fd9b6,$3fe57e
    .dc $000145,$52442d,$7a76fb,$7fdaa5,$7fe625,$3fdaaa,$3fe627,$00014d
    .dc $53287b,$7a98ce,$7fdb8e,$7fe6c6,$3fdb93,$3fe6c8,$000155,$540436
    .dc $7ab90c,$7fdc6c,$7fe760,$3fdc71,$3fe762,$00015d,$54d7d6,$7ad7d3
    .dc $7fdd40,$7fe7f2,$3fdd44,$3fe7f4,$000165,$55a3c8,$7af53b,$7fde0a
    .dc $7fe87e,$3fde0e,$3fe880,$00016d,$566874,$7b115a,$7fdecb,$7fe904
    .dc $3fdecf,$3fe906,$000175,$572639,$7b2c47,$7fdf84,$7fe984,$3fdf88
    .dc $3fe986,$000181,$5836b4,$7b5294,$7fe08a,$7fea39,$3fe08e,$3fea3b
    .dc $000185,$588e71,$7b5ed3,$7fe0de,$7fea73,$3fe0e2,$3fea75,$00018e
    .dc $593987,$7b7694,$7fe181,$7feae4,$3fe184,$3feae6,$000196,$59defb
    .dc $7b8d65,$7fe21d,$7feb50,$3fe220,$3feb52,$00019e,$5a7f13,$7ba356
    .dc $7fe2b3,$7febb8,$3fe2b6,$3febb9,$0001a6,$5b1a10,$7bb873,$7fe343
    .dc $7fec1c,$3fe346,$3fec1d,$0001ae,$5bb02e,$7bccc7,$7fe3ce,$7fec7c
    .dc $3fe3d1,$3fec7d,$0001b6,$5c41a6,$7be05d,$7fe453,$7fecd8,$3fe456
    .dc $3fecda,$0001be,$5cceaf,$7bf340,$7fe4d4,$7fed31,$3fe4d7,$3fed33
    .dc $0001c6,$5d577a,$7c0579,$7fe550,$7fed87,$3fe553,$3fed89,$0001ce
    .dc $5ddc38,$7c1711,$7fe5c8,$7fedda,$3fe5cb,$3feddc,$0001d7,$5e5d15
    .dc $7c2810,$7fe63c,$7fee2a,$3fe63e,$3fee2c,$0001df,$5eda3c,$7c387d
    .dc $7fe6ab,$7fee78,$3fe6ae,$3fee79,$0001e7,$5f53d5,$7c4861,$7fe717
    .dc $7feec2,$3fe71a,$3feec4,$0001ef,$5fca05,$7c57c1,$7fe780,$7fef0b
    .dc $3fe782,$3fef0c,$0001f7,$603cf1,$7c66a4,$7fe7e5,$7fef51,$3fe7e7
    .dc $3fef52,$000203,$60e37c,$7c7c1a,$7fe877,$7fefb6,$3fe879,$3fefb7
control_2:
    .dc $17c0a3,$7ffc67,$03fede,$7ffe79,$02f2ef,$79d294,$c5e5de,$17c467
    .dc $7ffc3e,$03febe,$7ffe67,$0302a9,$79b008,$c60553,$17c840,$7ffc14
    .dc $03fe9d,$7ffe55,$0312b3,$798cbb,$c62566,$17cc2f,$7ffbe7,$03fe7c
    .dc $7ffe42,$03230e,$7968a9,$c6461c,$17d034,$7ffbb9,$03fe5a,$7ffe2e
    .dc $0333bb,$7943cf,$c66775,$17d44e,$7ffb88,$03fe37,$7ffe1a,$0344bb
    .dc $791e27,$c68976,$17d880,$7ffb56,$03fe14,$7ffe04,$035610,$78f7ae
    .dc $c6ac20,$17dcc9,$7ffb21,$03fdef,$7ffdee,$0367bc,$78d05e,$c6cf77
    .dc $17e12a,$7ffaea,$03fdca,$7ffdd6,$0379bf,$78a834,$c6f37e,$17e5a3
    .dc $7ffab0,$03fda4,$7ffdbe,$038c1c,$787f2a,$c71837,$17ea35,$7ffa74
    .dc $03fd7d,$7ffda4,$039ed3,$78553c,$c73da6,$17eee1,$7ffa35,$03fd56
    .dc $7ffd8a,$03b1e7,$782a65,$c763cd,$17f3a6,$7ff9f3,$03fd2d,$7ffd6e
    .dc $03c558,$77fea0,$c78ab0,$17f885,$7ff9af,$03fd04,$7ffd50,$03d928
    .dc $77d1e7,$c7b251,$17fd80,$7ff967,$03fcd9,$7ffd32,$03ed5a,$77a436
    .dc $c7dab3,$180297,$7ff91c,$03fcae,$7ffd12,$0401ed,$777587,$c803da
    .dc $1807c9,$7ff8ce,$03fc82,$7ffcf1,$0416e4,$7745d5,$c82dc9,$180d19
    .dc $7ff87d,$03fc54,$7ffcce,$042c41,$77151b,$c85882,$181285,$7ff828
    .dc $03fc26,$7ffcaa,$044205,$76e351,$c88409,$181810,$7ff7cf,$03fbf7
    .dc $7ffc84,$045830,$76b074,$c8b061,$181dba,$7ff772,$03fbc6,$7ffc5d
    .dc $046ec6,$767c7d,$c8dd8d,$182383,$7ff711,$03fb95,$7ffc34,$0485c8
    .dc $764766,$c90b90,$18296c,$7ff6ac,$03fb62,$7ffc09,$049d36,$761128
    .dc $c93a6d,$182f75,$7ff642,$03fb2e,$7ffbdc,$04b514,$75d9bf,$c96a27
    .dc $1835a0,$7ff5d3,$03faf9,$7ffbad,$04cd61,$75a122,$c99ac3,$183bed
    .dc $7ff560,$03fac3,$7ffb7c,$04e621,$75674c,$c9cc42,$18425d,$7ff4e8
    .dc $03fa8c,$7ffb49,$04ff54,$752c37,$c9fea8,$1848f1,$7ff46a,$03fa53
    .dc $7ffb13,$0518fc,$74efdb,$ca31f8,$184fa9,$7ff3e7,$03fa19,$7ffadb
    .dc $05331b,$74b231,$ca6636,$185686,$7ff35e,$03f9de,$7ffaa1,$054db2
    .dc $747333,$ca9b64,$185d89,$7ff2ce,$03f9a1,$7ffa64,$0568c3,$7432d9
    .dc $cad186,$1864b2,$7ff239,$03f963,$7ffa25,$05844f,$73f11c,$cb089f
    .dc $186c03,$7ff19d,$03f924,$7ff9e2,$05a059,$73adf5,$cb40b1,$18737d
    .dc $7ff0fa,$03f8e3,$7ff99d,$05bce0,$73695b,$cb79c1,$187b1f,$7ff04f
    .dc $03f8a1,$7ff954,$05d9e8,$732348,$cbb3d0,$1882ec,$7fef9e,$03f85d
    .dc $7ff909,$05f772,$72dbb3,$cbeee4,$188ae4,$7feee4,$03f818,$7ff8ba
    .dc $06157e,$729295,$cc2afd,$189307,$7fee22,$03f7d1,$7ff867,$063410
    .dc $7247e4,$cc681f,$189b57,$7fed57,$03f789,$7ff811,$065327,$71fb9a
    .dc $cca64e,$18a3d5,$7fec84,$03f73f,$7ff7b7,$0672c6,$71adac,$cce58c
    .dc $18ac82,$7feba7,$03f6f3,$7ff75a,$0692ee,$715e13,$cd25dd,$18b55f
    .dc $7feac1,$03f6a6,$7ff6f8,$06b3a1,$710cc6,$cd6742,$18be6c,$7fe9d0
    .dc $03f656,$7ff691,$06d4df,$70b9bb,$cda9bf,$18c7aa,$7fe8d4,$03f605
    .dc $7ff626,$06f6ab,$7064eb,$cded56,$18d11c,$7fe7ce,$03f5b3,$7ff5b7
    .dc $071906,$700e4a,$ce320b,$18dac1,$7fe6bc,$03f55e,$7ff542,$073bf0
    .dc $6fb5d0,$ce77e0,$18e49b,$7fe59d,$03f507,$7ff4c8,$075f6b,$6f5b73
    .dc $cebed7,$18f3c8,$7fe3d8,$03f481,$7ff407,$0795b7,$6ed048,$cf2b6f
    .dc $18f8f3,$7fe33a,$03f454,$7ff3c4,$07a81b,$6ea0e8,$cf5035,$190372
    .dc $7fe1f4,$03f3f7,$7ff33a,$07cd51,$6e40a7,$cf9aa2,$190e2b,$7fe09f
    .dc $03f398,$7ff2a9,$07f31d,$6dde59,$cfe63a,$19191f,$7fdf3c,$03f337
    .dc $7ff212,$081980,$6d79f6,$d032ff,$19244e,$7fddc8,$03f2d3,$7ff174
    .dc $08407b,$6d1372,$d080f5,$192fbb,$7fdc45,$03f26e,$7ff0cf,$08680e
    .dc $6caac2,$d0d01c,$193b66,$7fdab0,$03f206,$7ff023,$08903c,$6c3fdb
    .dc $d12077,$194750,$7fd909,$03f19b,$7fef6f,$08b903,$6bd2b2,$d17207
    .dc $19537b,$7fd74f,$03f12f,$7feeb3,$08e266,$6b633b,$d1c4cd,$195fe9
    .dc $7fd582,$03f0bf,$7fedef,$090c65,$6af16a,$d218cb,$196c9a,$7fd3a1
    .dc $03f04d,$7fed23,$093701,$6a7d34,$d26e02,$197990,$7fd1aa,$03efd9
    .dc $7fec4d,$096239,$6a068d,$d2c473,$1986cd,$7fcf9d,$03ef62,$7feb6e
    .dc $098e0f,$698d67,$d31c1f,$199452,$7fcd79,$03eee8,$7fea84,$09ba83
    .dc $6911b8,$d37506,$19a21f,$7fcb3c,$03ee6b,$7fe991,$09e795,$689370
    .dc $d3cf2a,$19b761,$7fc7b2,$03edaa,$7fe80f,$0a2c58,$67d10e,$d458b1
layer_table:
    .dc $000000,$000000,$013333,$000ccd,$026666,$00199a,$03999a,$002666
    .dc $04cccd,$003333,$060000,$004000,$073333,$004ccd,$086666,$00599a
    .dc $09999a,$006666,$0acccd,$007333,$0c0000,$008000,$0d3333,$008ccd
    .dc $0e6666,$00999a,$0f999a,$00a666,$10cccd,$00b333,$120000,$00c000
    .dc $133333,$00cccd,$146666,$00d99a,$15999a,$00e666,$16cccd,$00f333
    .dc $180000,$010000,$193333,$010ccd,$1a6666,$01199a,$1b999a,$012666
    .dc $1ccccd,$013333,$1e0000,$014000,$1f3333,$014ccd,$206666,$01599a
    .dc $21999a,$016666,$22cccd,$017333,$240000,$018000,$253333,$018ccd
    .dc $266666,$01999a,$27999a,$01a666,$28cccd,$01b333,$2a0000,$01c000
    .dc $2b3333,$01cccd,$2c6667,$01d999,$2d999a,$01e666,$2ecccd,$01f333
    .dc $300000,$020000,$313333,$020ccd,$326667,$021999,$33999a,$022666
    .dc $34cccd,$023333,$360000,$024000,$373333,$024ccd,$386667,$025999
    .dc $39999a,$026666,$3acccd,$027333,$3c0000,$028000,$3d3333,$028ccd
    .dc $3e6667,$029999,$3f999a,$02a666,$40cccd,$02b333,$420000,$02c000
    .dc $433333,$02cccd,$446667,$02d999,$45999a,$02e666,$46cccd,$02f333
    .dc $480000,$030000,$493333,$030ccd,$4a6667,$031999,$4ccccd,$033333
