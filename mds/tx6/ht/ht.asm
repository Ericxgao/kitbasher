; TX6 HT - Simple606-inspired MDS voice for X.20, version 2.0.
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
; 05: r2
; 06: d0
; 07: d1
; 08: d2
; 09: p0
; 0a: cos0
; 0b: p1
; 0c: cos1
; 0d: p2
; 0e: cos2
; 0f: b0
; 10: a1
; 11: a2
; 12: rng
; 13: z1
; 14: z2
; 15: fast
; 16: slow
; 17: noiseamp
; 18: qbase
; 19: glide
; 1a: gatehold
; 1b: gatepole
; 1c: s0
; 1d: c0
; 1e: s1
; 1f: c1
; 20: s2
; 21: c2
; 22: lasttone

; Local instruction compaction; verify against retained native audio.
init:
    move #>$ffffff,m6
    move #>$ffffff,m0
    clr a r6,r0
    do #35,init_end
    move a1,x:(r0)+
init_end:
    move #>$006062,x0
    move x0,x:(r6+$12)
    rts
trigger:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move #>$ffffff,m1
    clr a
    move a1,x:(r6+$13)
    move a1,x:(r6+$14)
    move a1,x:(r6+$17)
    move a1,x:(r6+$22)
    move y:(r6+$2),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    asl a
    asl a
    add x0,a
    add #>control_1,a
    move a1,r0
    move r6,a
    move a1,r1
    do #9,control_1_end
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
    add #>9,a
    move a1,r1
    do #9,control_2_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_2_end:
    move #>$1713ec,x0
    move x0,x:(r6+$1c)
    move #>$04047f,x0
    move x0,x:(r6+$1e)
    move #>$0ed2aa,x0
    move x0,x:(r6+$20)
    move x:(r6+$3),x0
    move x:(r6+$a),y0
    mpyr y0,x0,a
    move a1,x:(r6+$1d)
    move x:(r6+$4),x0
    move x:(r6+$c),y0
    mpyr y0,x0,a
    move a1,x:(r6+$1f)
    move x:(r6+$5),x0
    move x:(r6+$e),y0
    mpyr y0,x0,a
    move a1,x:(r6+$21)
    move y:(r6+$3),a
    asr #7,a,a
    and #>$7e,a
    add #>layer_table,a
    move a1,r0
    move p:(r0)+,x0
    move x0,x:(r6+$15)
    move p:(r0)+,x0
    move x0,x:(r6+$16)
    move y:(r6+$4),a
    asr #7,a,a
    cmp #>127,a
    jeq over_done
    asl #16,a,a
    move a1,y0
    move x:(r6+$1e),x0
    mpyr y0,x0,a
    move a1,x:(r6+$1e)
    move x:(r6+$b),x0
    mpyr y0,x0,a
    move a1,x:(r6+$b)
    move x:(r6+$20),x0
    mpyr y0,x0,a
    move a1,x:(r6+$20)
    move x:(r6+$d),x0
    mpyr y0,x0,a
    move a1,x:(r6+$d)
over_done:
    rts
render:
    move #>$ffffff,m6
    move x:(r6+$0),a
    tst a
    jeq silent
    sub #>1,a
    move a1,x:(r6+$0)
    move x:(r6+$12),x0
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
    move x0,x:(r6+$12)
    move #>mds_scratch_x,r3
    move x:(r6+$f),x0
    move x0,x:(r3)+
    move x:(r6+$10),x0
    move x0,x:(r3)+
    move x:(r6+$11),x0
    move x0,x:(r3)+
    move x:(r6+$13),b
    move x:(r6+$14),x1
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
    move b1,x:(r6+$13)
    move x1,x:(r6+$14)
    move #>mds_scratch_x,r4
    move x:(r6+$1c),x0
    move x:(r6+$9),x1
    move x:(r6+$1d),y0
    move x:(r6+$6),y1
    do #16,tone0_end
    mpy y0,x0,a
    mac -y1,x1,a x0,x1
    asl a
    rnd a
    move a1,x0
    move a1,x:(r4)+
tone0_end:
    move x0,x:(r6+$1c)
    move x1,x:(r6+$9)
    move #>mds_scratch_x,r4
    move x:(r6+$1e),x0
    move x:(r6+$b),x1
    move x:(r6+$1f),y0
    move x:(r6+$7),y1
    do #16,tone1_end
    mpy y0,x0,a
    mac -y1,x1,a x0,x1
    asl a
    rnd a x:(r4),b
    add b,a a1,x0
    move a1,x:(r4)+
tone1_end:
    move x0,x:(r6+$1e)
    move x1,x:(r6+$b)
    move #>mds_scratch_x,r4
    move x:(r6+$20),x0
    move x:(r6+$d),x1
    move x:(r6+$21),y0
    move x:(r6+$8),y1
    do #16,tone2_end
    mpy y0,x0,a
    mac -y1,x1,a x0,x1
    asl a
    rnd a x:(r4),b
    add b,a a1,x0
    move a1,x:(r4)+
tone2_end:
    move x0,x:(r6+$20)
    move x1,x:(r6+$d)
    move x:(r6+$15),x0
    move x:(r6+$1),y0
    mpyr y0,x0,a
    move a1,x:(r6+$15)
    move x:(r6+$16),x0
    move x:(r6+$2),y0
    mpyr y0,x0,a
    move a1,x:(r6+$16)
    move x:(r6+$15),x0
    move x:(r6+$16),a
    add x0,a
    move x:(r6+$17),x0
    move a1,b
    move b1,x:(r6+$17)
    add x0,b
    asr b
    move b1,x0
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #16,mix_end
    move x:(r3)+,x1 y:(r5)+,y0
    mpy y0,x0,a
    add x1,a
    move a,y:(r7)+
    move y:(r5)+,y0
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
    .dc $00001a,$007cf1,$4956ce,$7c5f9f,$7d7aaa,$4d8a1b,$3c6cc6,$3d8105
    .dc $177c5f,$00001a,$007cf1,$4956ce,$7c5f9f,$7d7aaa,$4d8a1b,$3c6cc6
    .dc $3d8105,$177c5f,$00001a,$007cf1,$4956ce,$7c5f9f,$7d7aaa,$4d8a1b
    .dc $3c6cc6,$3d8105,$177c5f,$00001a,$007cf1,$4956ce,$7c5f9f,$7d7aaa
    .dc $4d8a1b,$3c6cc6,$3d8105,$177c5f,$000021,$018a11,$52442d,$7d1cec
    .dc $7dfeb7,$55fc11,$3d2541,$3e02bc,$1ce15c,$000029,$03b9ff,$59defb
    .dc $7daf64,$7e64ba,$5d1b31,$3db4c0,$3e674e,$21dcc4,$000031,$06b802
    .dc $5f53d5,$7e1169,$7ea8e9,$622dbf,$3e1524,$3eaab5,$25a70e,$000039
    .dc $0a3c74,$636d36,$7e579b,$7ed9b4,$65f860,$3e5a5b,$3edb06,$289ded
    .dc $000041,$0e0971,$669dc1,$7e8c5a,$7efe58,$68e8de,$3e8e76,$3eff5c
    .dc $2afe09,$000049,$11f1c8,$692ae9,$7eb570,$7f1ae0,$6b411b,$3eb71b
    .dc $3f1bad,$2cef7d,$000052,$15d71d,$6b411b,$7ed658,$7f31b7,$6d2af1
    .dc $3ed7b2,$3f325d,$2e8d98,$00005a,$19a62b,$6cfe0d,$7ef14a,$7f446a
    .dc $6ec235,$3ef269,$3f44f3,$2feb79,$000062,$1d5369,$6e7658,$7f07c4
    .dc $7f5401,$701a21,$3f08b4,$3f5475,$3116df,$00006a,$20d87d,$6fb8b4
    .dc $7f1acb,$7f6134,$714064,$3f1b98,$3f6196,$3219e9,$000072,$243271
    .dc $70cff0,$7f2b1c,$7f6c85,$723f05,$3f2bcd,$3f6cda,$32fc30,$00007a
    .dc $276081,$71c425,$7f3943,$7f7655,$731d81,$3f39dd,$3f769f,$33c385
    .dc $000082,$2a6343,$729b84,$7f45a5,$7f7eeb,$73e191,$3f462d,$3f7f2c
    .dc $34746f,$00008a,$2d3c23,$735ae0,$7f5094,$7f867f,$748fa5,$3f510c
    .dc $3f86b9,$35127f,$000092,$2fed07,$740605,$7f5a4d,$7f8d3c,$752b3e
    .dc $3f5ab8,$3f8d70,$35a08e,$00009a,$327812,$749ffd,$7f6300,$7f9344
    .dc $75b725,$3f6360,$3f9372,$3620eb,$0000a3,$34df7f,$752b3e,$7f6ad5
    .dc $7f98b2,$76359e,$3f6b2c,$3f98db,$369579,$0000ab,$372587,$75a9cb
    .dc $7f71ec,$7f9d9b,$76a880,$3f723a,$3f9dc1,$36ffc5,$0000b3,$394c57
    .dc $761d4d,$7f785d,$7fa212,$771151,$3f78a5,$3fa235,$37611b,$0000bb
    .dc $3b5601,$768728,$7f7e40,$7fa626,$777156,$3f7e82,$3fa646,$37ba90
    .dc $0000c3,$3d447b,$76e883,$7f83a5,$7fa9e4,$77c99f,$3f83e2,$3faa01
    .dc $380d10,$0000cb,$3f1999,$77425b,$7f889c,$7fad54,$781b11,$3f88d4
    .dc $3fad6f,$385963,$0000d3,$40d714,$779586,$7f8d32,$7fb081,$786670
    .dc $3f8d65,$3fb09a,$38a032,$0000db,$427e81,$77e2bc,$7f9171,$7fb372
    .dc $78ac65,$3f91a0,$3fb389,$38e212,$0000e3,$441159,$782a9b,$7f9562
    .dc $7fb62d,$78ed7e,$3f958e,$3fb643,$391f83,$0000ec,$4590fb,$786dab
    .dc $7f990e,$7fb8b8,$792a3a,$3f9937,$3fb8cc,$3958f2,$0000f4,$46fea6
    .dc $78ac65,$7f9c7b,$7fbb18,$796305,$3f9ca1,$3fbb2a,$398ec1,$0000fc
    .dc $485b86,$78e730,$7f9faf,$7fbd50,$79983d,$3f9fd4,$3fbd62,$39c145
    .dc $000104,$49a8ac,$791e68,$7fa2b1,$7fbf65,$79ca38,$3fa2d3,$3fbf76
    .dc $39f0c9,$00010c,$4ae716,$79525f,$7fa584,$7fc15a,$79f93e,$3fa5a4
    .dc $3fc169,$3a1d8f,$000114,$4c17ae,$79835c,$7fa82c,$7fc331,$7a2590
    .dc $3fa84a,$3fc340,$3a47d3,$00011c,$4d3b4c,$79b19e,$7faaae,$7fc4ee
    .dc $7a4f69,$3faaca,$3fc4fb,$3a6fc8,$000124,$4e52b9,$79dd5e,$7fad0c
    .dc $7fc691,$7a76fb,$3fad26,$3fc69e,$3a959f,$00012c,$4f5ead,$7a06cf
    .dc $7faf49,$7fc81e,$7a9c76,$3faf62,$3fc82a,$3ab980,$000134,$505fd5
    .dc $7a2e1f,$7fb168,$7fc996,$7ac003,$3fb180,$3fc9a2,$3adb93,$00013d
    .dc $5156ce,$7a5377,$7fb36b,$7fcafb,$7ae1c6,$3fb382,$3fcb06,$3afbf8
    .dc $000145,$52442d,$7a76fb,$7fb555,$7fcc4e,$7b01e2,$3fb56b,$3fcc59
    .dc $3b1acf,$00014d,$53287b,$7a98ce,$7fb726,$7fcd91,$7b2074,$3fb73b
    .dc $3fcd9b,$3b3834,$000155,$540436,$7ab90c,$7fb8e2,$7fcec4,$7b3d99
    .dc $3fb8f6,$3fcece,$3b5440,$00015d,$54d7d6,$7ad7d3,$7fba89,$7fcfe9
    .dc $7b5969,$3fba9c,$3fcff2,$3b6f0a,$000165,$55a3c8,$7af53b,$7fbc1d
    .dc $7fd101,$7b73fc,$3fbc2f,$3fd109,$3b88a9,$00016d,$566874,$7b115a
    .dc $7fbd9f,$7fd20c,$7b8d65,$3fbdb0,$3fd214,$3ba12e,$000175,$572639
    .dc $7b2c47,$7fbf10,$7fd30b,$7ba5b9,$3fbf20,$3fd313,$3bb8ab,$000181
    .dc $5836b4,$7b5294,$7fc11c,$7fd477,$7bc853,$3fc12b,$3fd47e,$3bda1d
    .dc $000185,$588e71,$7b5ed3,$7fc1c4,$7fd4eb,$7bd363,$3fc1d3,$3fd4f2
    .dc $3be4cf,$00018e,$593987,$7b7694,$7fc308,$7fd5cb,$7be8d7,$3fc317
    .dc $3fd5d2,$3bf993,$000196,$59defb,$7b8d65,$7fc440,$7fd6a3,$7bfd74
    .dc $3fc44e,$3fd6aa,$3c0d88,$00019e,$5a7f13,$7ba356,$7fc56c,$7fd773
    .dc $7c1145,$3fc579,$3fd779,$3c20bc,$0001a6,$5b1a10,$7bb873,$7fc68c
    .dc $7fd83a,$7c2456,$3fc699,$3fd841,$3c3338,$0001ae,$5bb02e,$7bccc7
    .dc $7fc7a1,$7fd8fa,$7c36b1,$3fc7ae,$3fd900,$3c4507,$0001b6,$5c41a6
    .dc $7be05d,$7fc8ac,$7fd9b3,$7c4861,$3fc8b8,$3fd9b9,$3c5632,$0001be
    .dc $5cceaf,$7bf340,$7fc9ae,$7fda65,$7c596e,$3fc9b9,$3fda6b,$3c66c2
    .dc $0001c6,$5d577a,$7c0579,$7fcaa6,$7fdb11,$7c69e2,$3fcab1,$3fdb17
    .dc $3c76bf,$0001ce,$5ddc38,$7c1711,$7fcb95,$7fdbb7,$7c79c4,$3fcba0
    .dc $3fdbbc,$3c8630,$0001d7,$5e5d15,$7c2810,$7fcc7c,$7fdc57,$7c891c
    .dc $3fcc87,$3fdc5c,$3c951d,$0001df,$5eda3c,$7c387d,$7fcd5c,$7fdcf2
    .dc $7c97f1,$3fcd66,$3fdcf7,$3ca38c,$0001e7,$5f53d5,$7c4861,$7fce34
    .dc $7fdd87,$7ca649,$3fce3d,$3fdd8c,$3cb182,$0001ef,$5fca05,$7c57c1
    .dc $7fcf04,$7fde18,$7cb429,$3fcf0e,$3fde1c,$3cbf07,$0001f7,$603cf1
    .dc $7c66a4,$7fcfcf,$7fdea4,$7cc199,$3fcfd8,$3fdea8,$3ccc1f,$000203
    .dc $60e37c,$7c7c1a,$7fd0f2,$7fdf6d,$7cd4f8,$3fd0fa,$3fdf72,$3cdf01
control_2:
    .dc $186c03,$7ff19d,$03f924,$7ff9e2,$0d7698,$7fe4fd,$02f2ef,$79d294
    .dc $c5e5de,$18737d,$7ff0fa,$03f8e3,$7ff99d,$0d6ee8,$7fe3cb,$0302a9
    .dc $79b008,$c60553,$187b1f,$7ff04f,$03f8a1,$7ff954,$0d670c,$7fe28c
    .dc $0312b3,$798cbb,$c62566,$1882ec,$7fef9e,$03f85d,$7ff909,$0d5f03
    .dc $7fe13e,$03230e,$7968a9,$c6461c,$188ae4,$7feee4,$03f818,$7ff8ba
    .dc $0d56cd,$7fdfe1,$0333bb,$7943cf,$c66775,$189307,$7fee22,$03f7d1
    .dc $7ff867,$0d4e68,$7fde75,$0344bb,$791e27,$c68976,$189b57,$7fed57
    .dc $03f789,$7ff811,$0d45d3,$7fdcf9,$035610,$78f7ae,$c6ac20,$18a3d5
    .dc $7fec84,$03f73f,$7ff7b7,$0d3d0c,$7fdb6c,$0367bc,$78d05e,$c6cf77
    .dc $18ac82,$7feba7,$03f6f3,$7ff75a,$0d3414,$7fd9ce,$0379bf,$78a834
    .dc $c6f37e,$18b55f,$7feac1,$03f6a6,$7ff6f8,$0d2ae9,$7fd81d,$038c1c
    .dc $787f2a,$c71837,$18be6c,$7fe9d0,$03f656,$7ff691,$0d2189,$7fd659
    .dc $039ed3,$78553c,$c73da6,$18c7aa,$7fe8d4,$03f605,$7ff626,$0d17f3
    .dc $7fd481,$03b1e7,$782a65,$c763cd,$18d11c,$7fe7ce,$03f5b3,$7ff5b7
    .dc $0d0e27,$7fd294,$03c558,$77fea0,$c78ab0,$18dac1,$7fe6bc,$03f55e
    .dc $7ff542,$0d0422,$7fd091,$03d928,$77d1e7,$c7b251,$18e49b,$7fe59d
    .dc $03f507,$7ff4c8,$0cf9e5,$7fce78,$03ed5a,$77a436,$c7dab3,$18eeac
    .dc $7fe472,$03f4ae,$7ff449,$0cef6c,$7fcc47,$0401ed,$777587,$c803da
    .dc $18f8f3,$7fe33a,$03f454,$7ff3c4,$0ce4b8,$7fc9fd,$0416e4,$7745d5
    .dc $c82dc9,$190372,$7fe1f4,$03f3f7,$7ff33a,$0cd9c7,$7fc799,$042c41
    .dc $77151b,$c85882,$190e2b,$7fe09f,$03f398,$7ff2a9,$0cce96,$7fc519
    .dc $044205,$76e351,$c88409,$19191f,$7fdf3c,$03f337,$7ff212,$0cc326
    .dc $7fc27e,$045830,$76b074,$c8b061,$19244e,$7fddc8,$03f2d3,$7ff174
    .dc $0cb774,$7fbfc5,$046ec6,$767c7d,$c8dd8d,$192fbb,$7fdc45,$03f26e
    .dc $7ff0cf,$0cab7f,$7fbced,$0485c8,$764766,$c90b90,$193b66,$7fdab0
    .dc $03f206,$7ff023,$0c9f45,$7fb9f5,$049d36,$761128,$c93a6d,$194750
    .dc $7fd909,$03f19b,$7fef6f,$0c92c5,$7fb6dc,$04b514,$75d9bf,$c96a27
    .dc $19537b,$7fd74f,$03f12f,$7feeb3,$0c85fd,$7fb39f,$04cd61,$75a122
    .dc $c99ac3,$195fe9,$7fd582,$03f0bf,$7fedef,$0c78eb,$7fb03e,$04e621
    .dc $75674c,$c9cc42,$196c9a,$7fd3a1,$03f04d,$7fed23,$0c6b8f,$7facb6
    .dc $04ff54,$752c37,$c9fea8,$197990,$7fd1aa,$03efd9,$7fec4d,$0c5de6
    .dc $7fa907,$0518fc,$74efdb,$ca31f8,$1986cd,$7fcf9d,$03ef62,$7feb6e
    .dc $0c4fee,$7fa52d,$05331b,$74b231,$ca6636,$199452,$7fcd79,$03eee8
    .dc $7fea84,$0c41a5,$7fa129,$054db2,$747333,$ca9b64,$19a21f,$7fcb3c
    .dc $03ee6b,$7fe991,$0c330b,$7f9cf6,$0568c3,$7432d9,$cad186,$19b038
    .dc $7fc8e6,$03edeb,$7fe893,$0c241c,$7f9894,$05844f,$73f11c,$cb089f
    .dc $19be9d,$7fc676,$03ed68,$7fe789,$0c14d7,$7f9401,$05a059,$73adf5
    .dc $cb40b1,$19cd50,$7fc3ea,$03ece2,$7fe674,$0c053a,$7f8f39,$05bce0
    .dc $73695b,$cb79c1,$19dc52,$7fc141,$03ec5a,$7fe552,$0bf543,$7f8a3c
    .dc $05d9e8,$732348,$cbb3d0,$19eba6,$7fbe7a,$03ebce,$7fe424,$0be4f0
    .dc $7f8506,$05f772,$72dbb3,$cbeee4,$19fb4c,$7fbb94,$03eb3e,$7fe2e8
    .dc $0bd43e,$7f7f95,$06157e,$729295,$cc2afd,$1a0b46,$7fb88d,$03eaac
    .dc $7fe19f,$0bc32c,$7f79e6,$063410,$7247e4,$cc681f,$1a1b96,$7fb563
    .dc $03ea15,$7fe046,$0bb1b7,$7f73f8,$065327,$71fb9a,$cca64e,$1a2c3f
    .dc $7fb216,$03e97c,$7fdedf,$0b9fde,$7f6dc6,$0672c6,$71adac,$cce58c
    .dc $1a3d40,$7faea3,$03e8de,$7fdd67,$0b8d9d,$7f674e,$0692ee,$715e13
    .dc $cd25dd,$1a4e9d,$7fab09,$03e83d,$7fdbdf,$0b7af2,$7f608c,$06b3a1
    .dc $710cc6,$cd6742,$1a6057,$7fa747,$03e799,$7fda46,$0b67db,$7f597f
    .dc $06d4df,$70b9bb,$cda9bf,$1a7270,$7fa35a,$03e6f0,$7fd89b,$0b5456
    .dc $7f5221,$06f6ab,$7064eb,$cded56,$1a84ea,$7f9f40,$03e643,$7fd6dc
    .dc $0b4060,$7f4a70,$071906,$700e4a,$ce320b,$1a97c7,$7f9af8,$03e593
    .dc $7fd50a,$0b2bf5,$7f4268,$073bf0,$6fb5d0,$ce77e0,$1aab08,$7f9680
    .dc $03e4de,$7fd323,$0b1715,$7f3a06,$075f6b,$6f5b73,$cebed7,$1ac8aa
    .dc $7f8f6b,$03e3c6,$7fd020,$0af6df,$7f2cbf,$0795b7,$6ed048,$cf2b6f
    .dc $1ad2c0,$7f8cf5,$03e367,$7fcf14,$0aebe5,$7f2820,$07a81b,$6ea0e8
    .dc $cf5035,$1ae73b,$7f87de,$03e2a5,$7fccea,$0ad590,$7f1e94,$07cd51
    .dc $6e40a7,$cf9aa2,$1afc22,$7f828d,$03e1de,$7fcaa7,$0abeb9,$7f149c
    .dc $07f31d,$6dde59,$cfe63a,$1b1178,$7f7d00,$03e113,$7fc84a,$0aa75e
    .dc $7f0a33,$081980,$6d79f6,$d032ff,$1b2740,$7f7734,$03e042,$7fc5d3
    .dc $0a8f7a,$7eff55,$08407b,$6d1372,$d080f5,$1b3d7a,$7f7127,$03df6d
    .dc $7fc340,$0a770c,$7ef3fc,$08680e,$6caac2,$d0d01c,$1b5429,$7f6ad5
    .dc $03de92,$7fc08f,$0a5e0f,$7ee822,$08903c,$6c3fdb,$d12077,$1b6b50
    .dc $7f643c,$03ddb3,$7fbdc1,$0a4481,$7edbc3,$08b903,$6bd2b2,$d17207
    .dc $1b82f1,$7f5d58,$03dcce,$7fbad2,$0a2a5d,$7eced8,$08e266,$6b633b
    .dc $d1c4cd,$1b9b0d,$7f5626,$03dbe3,$7fb7c2,$0a0fa2,$7ec15b,$090c65
    .dc $6af16a,$d218cb,$1bb3a8,$7f4ea2,$03daf3,$7fb490,$09f44a,$7eb346
    .dc $093701,$6a7d34,$d26e02,$1bccc3,$7f46ca,$03d9fd,$7fb139,$09d853
    .dc $7ea491,$096239,$6a068d,$d2c473,$1be662,$7f3e99,$03d901,$7fadbd
    .dc $09bbb8,$7e9537,$098e0f,$698d67,$d31c1f,$1c0085,$7f360b,$03d7fe
    .dc $7faa19,$099e77,$7e852f,$09ba83,$6911b8,$d37506,$1c1b31,$7f2d1c
    .dc $03d6f6,$7fa64b,$09808a,$7e7472,$09e795,$689370,$d3cf2a,$1c4436
    .dc $7f1ef8,$03d55d,$7fa046,$09525e,$7e59f2,$0a2c58,$67d10e,$d458b1
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
