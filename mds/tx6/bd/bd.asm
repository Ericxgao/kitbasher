; TX6 BD - Simple606-inspired MDS voice for X.20, version 2.0.
; XL: 0 = normal body decay; 127 = former XL-on decay. Captured on trigger.
; Intermediate XL values blend the envelope poles; render is unchanged.
; CLIK: 0 = remove this layer; 127 = original layer level. Captured on trigger.
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
; 00: amp
; 01: freq
; 02: pitch
; 03: click
; 04: clickpole
; 05: clickgain
; 06: decaynormal
; 07: decayxl
; 08: tune
; 09: heat
; 0a: norm
; 0b: rng
; 0c: remaining
; 0d: amppole
; 0e: target
; 0f: u
; 10: v
; 11: bodylp
; 12: clicklp
; 13: dcin
; 14: dcout
; 15: previous
; 16: bodygain
; 17: noisegain

; Local instruction compaction; verify against retained native audio.
init:
    move #>$ffffff,m6
    move #>$ffffff,m0
    clr a r6,r0
    do #24,init_end
    move a1,x:(r0)+
init_end:
    move #>$606606,x0
    move x0,x:(r6+$b)
    rts
trigger:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move #>$ffffff,m1
    clr a
    move a1,x:(r6+$11)
    move a1,x:(r6+$12)
    move a1,x:(r6+$13)
    move a1,x:(r6+$14)
    move a1,x:(r6+$15)
    move y:(r6+$3),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add x0,a
    asl a
    add #>control_1,a
    move a1,r0
    move r6,a
    move a1,r1
    do #6,control_1_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_1_end:
    move y:(r6+$2),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add #>control_2,a
    move a1,r0
    move r6,a
    add #>6,a
    move a1,r1
    do #2,control_2_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_2_end:
    move y:(r6+$1),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    add #>control_3,a
    move a1,r0
    move r6,a
    add #>8,a
    move a1,r1
    do #1,control_3_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_3_end:
    move y:(r6+$4),a
    asr #8,a,a
    and #>$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add #>control_4,a
    move a1,r0
    move r6,a
    add #>9,a
    move a1,r1
    do #2,control_4_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_4_end:
    move x:(r6+$1),x0
    move x:(r6+$8),y0
    mpy y0,x0,a
    asl #2,a,a
    move a1,x:(r6+$1)
    move #>$01de71,x0
    mpy y0,x0,a
    asl #2,a,a
    move a1,x:(r6+$e)
    ; XL interpolates the body envelope pole once per trigger.
    ; 128 uniformly spaced weights; both installed endpoints remain exact.
    move y:(r6+$5),a
    asr #7,a,a
    add #>xl_weights,a
    move a1,r0
    move p:(r0),y0
    move x:(r6+$6),x0
    move x:(r6+$7),a
    sub x0,a
    move a1,x1
    mpyr x1,y0,a
    add x0,a
    move a1,x:(r6+$d)
    move #>$209422,x0
    move x0,x:(r6+$f)
    move #>$c8e99a,x0
    move x0,x:(r6+$10)
    move #>16384,x0
    move x0,x:(r6+$c)
    move y:(r6+$6),a
    asr #7,a,a
    cmp #>127,a
    jeq layer_done
    asl #16,a,a
    move a1,y0
    move x:(r6+$5),x0
    mpyr y0,x0,a
    move a1,x:(r6+$5)
layer_done:
    rts
render:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move x:(r6+$c),a
    tst a
    jeq silent
    sub #>1,a
    move a1,x:(r6+$c)
    move x:(r6+$1),x0
    move x:(r6+$e),b
    move x0,a
    sub b,a
    move a1,x1
    move x:(r6+$2),y0
    mpy x1,y0,a
    add b,a
    move a1,x:(r6+$1)
    add x0,a
    asr a
    move a1,n0
    move x:(r6+$0),x0
    move x:(r6+$d),y0
    mpyr y0,x0,a
    move a1,x:(r6+$0)
    add x0,a
    asr a
    move a1,x:(r6+$16)
    move x:(r6+$3),x0
    move x:(r6+$4),y0
    mpyr y0,x0,a
    move a1,x:(r6+$3)
    add x0,a
    asr a
    move a1,x:(r6+$17)
    move x:(r6+$17),x0
    move x:(r6+$5),y0
    mpyr y0,x0,a
    move a1,x:(r6+$17)
    move x:(r6+$f),x0
    move x:(r6+$10),x1
    move n0,y0
    move x:(r6+$16),y1
    move #>mds_scratch_x,r4
    do #16,body_end
    move x0,a
    mac -x1,y0,a
    move a1,x0
    move x1,a
    mac y0,x0,a
    move a1,x1
    mpy y1,x1,a
    move a1,x:(r4)+
body_end:
    move x0,x:(r6+$f)
    move x1,x:(r6+$10)
    move x:(r6+$b),x0
    move #>$200000,y1
    move #>$19660d,y0
    move #>mds_scratch_y,r5
    do #16,white_end
    mpy y0,x0,a
    asr a
    move a0,a
    add #>$6ef35f,a
    move a1,x0
    mpy x0,y1,a
    move a1,y:(r5)+
white_end:
    move x0,x:(r6+$b)
    move #>mds_scratch_y,r5
    move x:(r6+$12),x0
    move #>$498e4d,y0
    move x:(r6+$17),y1
    do #16,click_end
    move y:(r5),a
    sub x0,a
    move a1,x1
    mpy x1,y0,a
    add x0,a
    move a1,x0
    mpy x0,y1,a
    move a1,y:(r5)+
click_end:
    move x0,x:(r6+$12)
    move x:(r6+$11),n1
    move x:(r6+$13),n2
    move x:(r6+$14),n3
    move x:(r6+$15),n4
    move x:(r6+$9),n5
    move x:(r6+$a),n6
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #16,mix_end
    move x:(r3)+,a
    move y:(r5)+,x0
    add x0,a
    move a1,x0
    move n5,y0
    mpy y0,x0,a
    asl #4,a,a
    move #>$7fffff,x0
    cmp x0,a
    tgt x0,a
    move #>$800001,x0
    cmp x0,a
    tlt x0,a
    abs a a1,x0
    move a1,y0
    mpy y0,x0,b
    asr b x0,a
    sub b,a
    move a1,x0
    move n6,y0
    mpy y0,x0,a
    asl a n2,x0
    sub x0,a a1,n2
    move n3,x0
    move #>$7eb924,y0
    macr y0,x0,a
    move a1,n3
    move a1,x0
    move n4,a
    add x0,a x0,n4
    asr a
    move a,y:(r7)+
    move x0,y:(r7)+
mix_end:
    move n1,x:(r6+$11)
    move n2,x:(r6+$13)
    move n3,x:(r6+$14)
    move n4,x:(r6+$15)
    rts
silent:
    clr a
    do #32,zero_end
    move a,y:(r7)+
zero_end:
    rts
control_1:
    .dc $40240b,$0442a7,$7bd226,$0978d5,$633a80,$0d9392,$4035d9,$044428
    .dc $7bcecf,$0a7079,$64cfcc,$0f6317,$404408,$04455b,$7bcc23,$0b194f
    .dc $65cb9a,$109f1d,$4051d3,$044686,$7bc986,$0bad54,$6699e5,$11b42a
    .dc $405f9d,$0447b0,$7bc6e5,$0c3543,$674c85,$12b29a,$406d89,$0448dd
    .dc $7bc43b,$0cb4dd,$67eb88,$13a170,$407ba6,$044a0e,$7bc184,$0d2e32
    .dc $687b83,$14848b,$4089fc,$044b44,$7bbebf,$0da28d,$68ff6d,$155e55
    .dc $409890,$044c7f,$7bbbea,$0e12cf,$69795a,$163073,$40a763,$044dc0
    .dc $7bb905,$0e7f9a,$69eace,$16fc16,$40b678,$044f06,$7bb60f,$0ee968
    .dc $6a54f5,$17c221,$40c5cd,$045052,$7bb308,$0f5099,$6ab8b9,$188346
    .dc $40d562,$0451a3,$7bafef,$0fb576,$6b16d9,$194012,$40e538,$0452f9
    .dc $7bacc6,$10183f,$6b6fef,$19f8f8,$40f54e,$045455,$7ba98b,$107926
    .dc $6bc47f,$1aae58,$4105a2,$0455b7,$7ba63f,$10d855,$6c14f6,$1b6082
    .dc $411635,$04571d,$7ba2e0,$1135f1,$6c61b4,$1c0fb8,$412705,$045889
    .dc $7b9f70,$119219,$6cab09,$1cbc37,$413812,$0459f9,$7b9bee,$11ece9
    .dc $6cf13c,$1d6631,$41495b,$045b6f,$7b985a,$124678,$6d348c,$1e0dd2
    .dc $415adf,$045cea,$7b94b4,$129edb,$6d752f,$1eb342,$416c9d,$045e6a
    .dc $7b90fb,$12f624,$6db358,$1f56a4,$417e94,$045fee,$7b8d30,$134c66
    .dc $6def30,$1ff817,$4190c4,$046178,$7b8953,$13a1ad,$6e28e0,$2097b6
    .dc $41a32d,$046306,$7b8562,$13f609,$6e608b,$21359b,$41bf31,$046564
    .dc $7b7f56,$1472f2,$6eb088,$221f69,$41c8a3,$046630,$7b7d48,$149c2b
    .dc $6eca4f,$226c92,$41dbaf,$0467cc,$7b791e,$14ee08,$6efca0,$2305cb
    .dc $41eef0,$04696d,$7b74e1,$153f23,$6f2d5c,$239d9b,$420267,$046b12
    .dc $7b7090,$158f85,$6f5c98,$243411,$421611,$046cbb,$7b6c2b,$15df37
    .dc $6f8a6b,$24c93c,$4229ef,$046e69,$7b67b2,$162e40,$6fb6e5,$255d2b
    .dc $423dff,$04701b,$7b6325,$167ca6,$6fe21a,$25efe9,$425242,$0471d1
    .dc $7b5e83,$16ca70,$700c18,$268182,$4266b7,$04738b,$7b59cc,$1717a3
    .dc $7034f0,$271203,$427b5d,$04754a,$7b5500,$176446,$705cae,$27a174
    .dc $429034,$04770c,$7b501f,$17b05d,$708360,$282fe0,$42afd0,$0479b8
    .dc $7b48a4,$182184,$70bb8f,$2903ac,$42ba72,$047a9e,$7b461b,$1846fb
    .dc $70cdd0,$2949cb,$42cfd8,$047c6d,$7b40f7,$18918b,$70f1a4,$29d55b
    .dc $42e56d,$047e40,$7b3bbd,$18dba1,$711497,$2a6007,$42fb31,$048016
    .dc $7b366c,$192541,$7136b3,$2ae9d5,$431122,$0481f1,$7b3104,$196e6e
    .dc $715802,$2b72cd,$432741,$0483d0,$7b2b84,$19b72c,$71788a,$2bfaf5
    .dc $433d8d,$0485b2,$7b25ec,$19ff7e,$719855,$2c8252,$435406,$048798
    .dc $7b203c,$1a4767,$71b768,$2d08ec,$436aab,$048982,$7b1a73,$1a8eea
    .dc $71d5cc,$2d8ec6,$438cf6,$048c67,$7b1196,$1af975,$720227,$2e5633
    .dc $43987a,$048d60,$7b0e95,$1b1cc9,$72109e,$2e9853,$43afa2,$048f55
    .dc $7b087f,$1b632a,$722d19,$2f1c0e,$43c6f5,$04914e,$7b024f,$1ba930
    .dc $7248fc,$2f9f1e,$43de72,$04934a,$7afc03,$1beedc,$72644d,$302187
    .dc $43f61a,$049549,$7af59c,$1c3431,$727f10,$30a34d,$440dec,$04974d
    .dc $7aef1a,$1c7930,$72994b,$312473,$4425e8,$049953,$7ae87b,$1cbddd
    .dc $72b302,$31a4fd,$443e0c,$049b5d,$7ae1be,$1d0238,$72cc39,$3224f0
    .dc $44565a,$049d6b,$7adae5,$1d4644,$72e4f5,$32a44e,$446ed0,$049f7c
    .dc $7ad3ed,$1d8a03,$72fd3a,$33231a,$44876f,$04a191,$7accd7,$1dcd75
    .dc $73150a,$33a159,$44a036,$04a3a9,$7ac5a1,$1e109e,$732c6b,$341f0d
    .dc $44b924,$04a5c4,$7abe4b,$1e537d,$73435f,$349c38,$44d23a,$04a7e2
    .dc $7ab6d5,$1e9615,$7359e9,$3518de,$44eb78,$04aa04,$7aaf3e,$1ed868
    .dc $73700d,$359502,$45119d,$04ad3d,$7aa39c,$1f3b64,$73908a,$364e49
control_2:
    .dc $770a7e,$770a7e,$7710ce,$772955,$77238a,$778112,$774215,$780519
    .dc $776b7e,$78a520,$779e88,$79516a,$77d9c9,$79fd7d,$781bba,$7aa0f6
    .dc $7862d1,$7b3723,$78ad91,$7bbe0e,$78fa9d,$7c3587,$7948b8,$7c9e66
    .dc $7996d5,$7cfa01,$79e411,$7d49db,$7a2fb6,$7d8f72,$7a7936,$7dcc28
    .dc $7ac028,$7e013c,$7b0442,$7e2fc1,$7b4555,$7e58a6,$7b8346,$7e7cb7
    .dc $7bbe0e,$7e9ca0,$7bf5b2,$7eb8f5,$7c2a41,$7ed230,$7c5bd5,$7ee8bd
    .dc $7c8a88,$7efcf4,$7ccb79,$7f1789,$7cdfd4,$7f1f86,$7d06b2,$7f2e5a
    .dc $7d2b3a,$7f3bcd,$7d4d91,$7f4808,$7d6dd8,$7f532f,$7d8c30,$7f5d60
    .dc $7da8b9,$7f66b7,$7dc391,$7f6f49,$7ddcd4,$7f772c,$7df49e,$7f7e72
    .dc $7e0b08,$7f852a,$7e2a43,$7f8e51,$7e3415,$7f9125,$7e46e3,$7f967f
    .dc $7e58a6,$7f9b7b,$7e696f,$7fa01f,$7e794e,$7fa474,$7e8853,$7fa880
    .dc $7e968c,$7fac4a,$7ea406,$7fafd7,$7eb0cd,$7fb32c,$7ec2c2,$7fb7cc
    .dc $7ec870,$7fb93f,$7ed360,$7fbc05,$7eddc6,$7fbea3,$7ee7ab,$7fc11b
    .dc $7ef116,$7fc370,$7efa0e,$7fc5a5,$7f029b,$7fc7bb,$7f0ac3,$7fc9b6
    .dc $7f128b,$7fcb97,$7f19f9,$7fcd5f,$7f2113,$7fcf11,$7f27dc,$7fd0ad
    .dc $7f2e5a,$7fd236,$7f3491,$7fd3ab,$7f3a84,$7fd510,$7f42f9,$7fd708
control_3:
    .dc $100000,$105a68,$10b6ce,$11153f,$1175c5,$11d86c,$123d41,$12a450
    .dc $130da5,$13794d,$13e755,$1457cb,$14cabd,$154038,$15b84b,$163304
    .dc $16b073,$1730a6,$17b3ae,$18399a,$18c27b,$194e61,$19dd5e,$1a6f83
    .dc $1b04e1,$1beb23,$1c3994,$1cd90f,$1d7c0f,$1e22a8,$1eccee,$1f7af6
    .dc $202cd5,$20e2a2,$219c71,$225a5b,$231c76,$2447ae,$24ad9e,$257cdc
    .dc $2650ad,$27292b,$280670,$28e897,$29cfbc,$2abbfc,$2bad72,$2d21aa
    .dc $2da079,$2ea247,$2fa9c6,$30b715,$31ca57,$32e3ab,$340335,$352918
    .dc $365578,$378878,$38c23f,$3a02f4,$3b4abc,$3c99c0,$3df029,$400000
control_4:
    .dc $1243fe,$59999a,$1345ba,$573a73,$144775,$550917,$154930,$53000c
    .dc $164aec,$511ab5,$174ca7,$4f552d,$184e63,$4dac20,$19501e,$4c1cb1
    .dc $1a51d9,$4aa466,$1b5395,$494119,$1c5550,$47f0e8,$1d570b,$46b22c
    .dc $1e58c7,$45836f,$1f5a82,$446366,$205c3e,$4350e9,$215df9,$424af0
    .dc $225fb4,$415090,$236170,$4060f4,$24632b,$3f7b5b,$2564e6,$3e9f18
    .dc $2666a2,$3dcb8e,$27685d,$3d002c,$286a19,$3c3c70,$296bd4,$3b7fe2
    .dc $2a6d8f,$3aca15,$2bf028,$39c52f,$2c7106,$397130,$2d72c1,$38cd67
    .dc $2e747d,$382ef8,$2f7638,$37959b,$3077f4,$37010c,$3179af,$36710b
    .dc $327b6a,$35e55e,$337d26,$355dd0,$347ee1,$34da2d,$35809c,$345a45
    .dc $368258,$33dded,$3804f1,$3329bb,$3885cf,$32ef47,$39878a,$327cae
    .dc $3a8945,$320d0e,$3b8b01,$31a045,$3c8cbc,$313635,$3d8e77,$30cec3
    .dc $3e9033,$3069d2,$3f91ee,$30074a,$4093aa,$2fa711,$421643,$2f1ae2
    .dc $429720,$2eed38,$4398dc,$2e936c,$449a97,$2e3b9c,$459c52,$2de5b6
    .dc $469e0e,$2d91a7,$479fc9,$2d3f60,$48a185,$2ceed1,$49a340,$2c9fea
    .dc $4aa4fb,$2c529c,$4ba6b7,$2c06dc,$4ca872,$2bbc9a,$4daa2d,$2b73cb
    .dc $4eabe9,$2b2c64,$4fada4,$2ae657,$50af60,$2aa19c,$5231f9,$2a3ce3

xl_weights:
    .dc $000000,$010204,$020408,$03060c,$040810,$050a14,$060c18,$070e1c
    .dc $081020,$091224,$0a1428,$0b162c,$0c1830,$0d1a34,$0e1c38,$0f1e3c
    .dc $102040,$112244,$122448,$13264c,$142850,$152a54,$162c59,$172e5d
    .dc $183061,$193265,$1a3469,$1b366d,$1c3871,$1d3a75,$1e3c79,$1f3e7d
    .dc $204081,$214285,$224489,$23468d,$244891,$254a95,$264c99,$274e9d
    .dc $2850a1,$2952a5,$2a54a9,$2b56ad,$2c58b1,$2d5ab5,$2e5cb9,$2f5ebd
    .dc $3060c1,$3162c5,$3264c9,$3366cd,$3468d1,$356ad5,$366cd9,$376edd
    .dc $3870e1,$3972e5,$3a74e9,$3b76ed,$3c78f1,$3d7af5,$3e7cf9,$3f7efd
    .dc $408102,$418306,$42850a,$43870e,$448912,$458b16,$468d1a,$478f1e
    .dc $489122,$499326,$4a952a,$4b972e,$4c9932,$4d9b36,$4e9d3a,$4f9f3e
    .dc $50a142,$51a346,$52a54a,$53a74e,$54a952,$55ab56,$56ad5a,$57af5e
    .dc $58b162,$59b366,$5ab56a,$5bb76e,$5cb972,$5dbb76,$5ebd7a,$5fbf7e
    .dc $60c182,$61c386,$62c58a,$63c78e,$64c992,$65cb96,$66cd9a,$67cf9e
    .dc $68d1a2,$69d3a6,$6ad5ab,$6bd7af,$6cd9b3,$6ddbb7,$6eddbb,$6fdfbf
    .dc $70e1c3,$71e3c7,$72e5cb,$73e7cf,$74e9d3,$75ebd7,$76eddb,$77efdf
    .dc $78f1e3,$79f3e7,$7af5eb,$7bf7ef,$7cf9f3,$7dfbf7,$7efdfb,$7fffff
