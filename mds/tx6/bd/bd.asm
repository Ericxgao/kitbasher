; TX6 BD - Simple606-inspired MDS voice for X.20, version 2.1.
; 44.1 kHz kick: swept fundamental and HEAT-controlled third harmonic, smooth gain, a sharp CLIK-controlled impulse and full-rate low-pass noise click. DEC and continuous XL retain their decay curves.
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
; 18: harmonic
; 19: harmonic_previous

init:
    move #>$ffffff,m6
    move #>$ffffff,m0
    clr a r6,r0
    do #26,init_end
    move a1,x:(r0)+
init_end:
    move #>$606606,x0
    move x0,x:(r6+$b)
    rts
trigger:
    move #>$ffffff,m6
    move #>$ffffff,m0
    move #>$ffffff,m1
    ; A short click impulse; the existing filter drains it immediately.
    move #>$880000,a
    move a1,x:(r6+$12)
    move y:(r6+$3),a
    asr #8,a,a
    and #$3f,a
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
    and #$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add #>control_2,a
    move a1,r0
    move r6,a
    add #6,a
    move a1,r1
    do #2,control_2_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_2_end:
    move y:(r6+$1),a
    asr #8,a,a
    and #$3f,a
    clr a a1,x0
    add x0,a
    add #>control_3,a
    move a1,r0
    move r6,a
    add #8,a
    move a1,r1
    do #1,control_3_end
    move p:(r0)+,x0
    move x0,x:(r1)+
control_3_end:
    move y:(r6+$4),a
    asr #8,a,a
    and #$3f,a
    clr a a1,x0
    add x0,a
    asl a
    add #>control_4,a
    move a1,r0
    move r6,a
    add #9,a
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
    clr a
    move a1,x:(r6+$f)
    move a1,x:(r6+$18)
    move x:(r6+$1),a
    asr #2,a,a
    neg a
    move a1,x:(r6+$10)
    asl a a1,x0
    add x0,a
    move a1,x0
    move x:(r6+$9),y0
    mpyr y0,x0,a
    move a1,x:(r6+$19)
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
    ; M0..M5 are linear on entry (X.20 dispatcher P:$ac..$b2).
    move #>$ffffff,m6
    move x:(r6+$c),a
    tst a
    jeq silent
    sub #1,a
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
    asr a
    move a1,n0
    move x:(r6+$0),x0
    move x:(r6+$d),y0
    mpyr y0,x0,a
    move a1,x:(r6+$0)
    move x0,x:(r6+$16)
    move x:(r6+$3),x0
    move x:(r6+$5),y0
    mpyr y0,x0,a
    move a1,r0
    move x:(r6+$4),y0
    mpyr y0,x0,a
    move a1,x:(r6+$3)
    move a1,x0
    move x:(r6+$5),y0
    mpyr y0,x0,a
    move r0,x0
    sub x0,a
    asr #5,a,a
    move a1,n2
    move n0,a
    move a1,x0
    mpy x0,x0,a
    asr a
    move a1,n1
    neg a
    add #>$7fffff,a
    move a1,x0
    move #>$400000,x1
    move #>mds_scratch_x,r4
    move x:(r6+$f),y0
    move x:(r6+$10),y1
    do #32,tone0_end
    mpy x0,y0,a
    mac -x1,y1,a y0,y1
    asl a
    move a1,y0
    move a1,x:(r4)+
tone0_end:
    move y0,x:(r6+$f)
    move y1,x:(r6+$10)
    move n1,a
    move a1,x0
    asl #3,a,a
    add x0,a
    neg a
    add #>$7fffff,a
    move a1,y0
    move #>$400000,y1
    move #>mds_scratch_x,r4
    move x:(r6+$18),x0
    move x:(r6+$19),x1
    do #32,tone1_end
    mpy y0,x0,a
    mac -y1,x1,a x0,x1
    asl a
    rnd a x:(r4),b
    add b,a a1,x0
    move a1,x:(r4)+
tone1_end:
    move x0,x:(r6+$18)
    move x1,x:(r6+$19)
    move x:(r6+$b),x0
    move #>$080000,y1
    move #>$19660d,y0
    move #>mds_scratch_y,r5
    do #32,white_end
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
    move #>$2c8537,y0
    move n2,n0
    move r0,y1
    do #32,click_end
    move y:(r5),a
    sub x0,a
    move a1,x1
    mpy x1,y0,a
    add x0,a  r0,y1
    move a1,x0
    mpy x0,y1,a  (r0)+n0
    move a1,y:(r5)+
click_end:
    move x0,x:(r6+$12)
    move x:(r6+$16),x0
    move x:(r6+$a),y0
    mpyr y0,x0,a
    move a1,y1
    move a,b
    move x:(r6+$0),x0
    mpyr y0,x0,a
    sub b,a
    asr #5,a,a
    move a1,x0
    move #>mds_scratch_x,r3
    move #>mds_scratch_y,r5
    do #32,mix_end
    add x0,b  x:(r3)+,x1  y:(r5)+,y0
    mpy y1,x1,a  b,y1
    add y0,a
    asl a
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
    .dc $40240b,$0442a7,$7bd226,$0404c5,$633a80,$7fffff,$4035d9,$044428
    .dc $7bcecf,$05050c,$64cfcc,$7fffff,$404408,$04455b,$7bcc23,$05c3d7
    .dc $65cb9a,$7fffff,$4051d3,$044686,$7bc986,$0675d3,$6699e5,$7fffff
    .dc $405f9d,$0447b0,$7bc6e5,$072219,$674c85,$7fffff,$406d89,$0448dd
    .dc $7bc43b,$07cb7e,$67eb88,$7fffff,$407ba6,$044a0e,$7bc184,$087377
    .dc $687b83,$7fffff,$4089fc,$044b44,$7bbebf,$091ade,$68ff6d,$7fffff
    .dc $409890,$044c7f,$7bbbea,$09c23d,$69795a,$7fffff,$40a763,$044dc0
    .dc $7bb905,$0a69f1,$69eace,$7fffff,$40b678,$044f06,$7bb60f,$0b1239
    .dc $6a54f5,$7fffff,$40c5cd,$045052,$7bb308,$0bbb46,$6ab8b9,$7fffff
    .dc $40d562,$0451a3,$7bafef,$0c6538,$6b16d9,$7fffff,$40e538,$0452f9
    .dc $7bacc6,$0d102a,$6b6fef,$7fffff,$40f54e,$045455,$7ba98b,$0dbc2f
    .dc $6bc47f,$7fffff,$4105a2,$0455b7,$7ba63f,$0e6955,$6c14f6,$7fffff
    .dc $411635,$04571d,$7ba2e0,$0f17a7,$6c61b4,$7fffff,$412705,$045889
    .dc $7b9f70,$0fc72e,$6cab09,$7fffff,$413812,$0459f9,$7b9bee,$1077f2
    .dc $6cf13c,$7fffff,$41495b,$045b6f,$7b985a,$1129f5,$6d348c,$7fffff
    .dc $415adf,$045cea,$7b94b4,$11dd3c,$6d752f,$7fffff,$416c9d,$045e6a
    .dc $7b90fb,$1291ca,$6db358,$7fffff,$417e94,$045fee,$7b8d30,$1347a1
    .dc $6def30,$7fffff,$4190c4,$046178,$7b8953,$13fec0,$6e28e0,$7fffff
    .dc $41a32d,$046306,$7b8562,$14b729,$6e608b,$7fffff,$41bf31,$046564
    .dc $7b7f56,$15ce34,$6eb088,$7fffff,$41c8a3,$046630,$7b7d48,$162bdb
    .dc $6eca4f,$7fffff,$41dbaf,$0467cc,$7b791e,$16e823,$6efca0,$7fffff
    .dc $41eef0,$04696d,$7b74e1,$17a5b3,$6f2d5c,$7fffff,$420267,$046b12
    .dc $7b7090,$18648a,$6f5c98,$7fffff,$421611,$046cbb,$7b6c2b,$1924a9
    .dc $6f8a6b,$7fffff,$4229ef,$046e69,$7b67b2,$19e60e,$6fb6e5,$7fffff
    .dc $423dff,$04701b,$7b6325,$1aa8b7,$6fe21a,$7fffff,$425242,$0471d1
    .dc $7b5e83,$1b6ca2,$700c18,$7fffff,$4266b7,$04738b,$7b59cc,$1c31ce
    .dc $7034f0,$7fffff,$427b5d,$04754a,$7b5500,$1cf83b,$705cae,$7fffff
    .dc $429034,$04770c,$7b501f,$1dbfe5,$708360,$7fffff,$42afd0,$0479b8
    .dc $7b48a4,$1eedb6,$70bb8f,$7fffff,$42ba72,$047a9e,$7b461b,$1f52ee
    .dc $70cdd0,$7fffff,$42cfd8,$047c6d,$7b40f7,$201e49,$70f1a4,$7fffff
    .dc $42e56d,$047e40,$7b3bbd,$20eadc,$711497,$7fffff,$42fb31,$048016
    .dc $7b366c,$21b8a4,$7136b3,$7fffff,$431122,$0481f1,$7b3104,$2287a0
    .dc $715802,$7fffff,$432741,$0483d0,$7b2b84,$2357cf,$71788a,$7fffff
    .dc $433d8d,$0485b2,$7b25ec,$24292e,$719855,$7fffff,$435406,$048798
    .dc $7b203c,$24fbbd,$71b768,$7fffff,$436aab,$048982,$7b1a73,$25cf78
    .dc $71d5cc,$7fffff,$438cf6,$048c67,$7b1196,$270f42,$720227,$7fffff
    .dc $43987a,$048d60,$7b0e95,$277a70,$72109e,$7fffff,$43afa2,$048f55
    .dc $7b087f,$2851a8,$722d19,$7fffff,$43c6f5,$04914e,$7b024f,$292a09
    .dc $7248fc,$7fffff,$43de72,$04934a,$7afc03,$2a038e,$72644d,$7fffff
    .dc $43f61a,$049549,$7af59c,$2ade37,$727f10,$7fffff,$440dec,$04974d
    .dc $7aef1a,$2bba00,$72994b,$7fffff,$4425e8,$049953,$7ae87b,$2c96eb
    .dc $72b302,$7fffff,$443e0c,$049b5d,$7ae1be,$2d74f4,$72cc39,$7fffff
    .dc $44565a,$049d6b,$7adae5,$2e541a,$72e4f5,$7fffff,$446ed0,$049f7c
    .dc $7ad3ed,$2f345c,$72fd3a,$7fffff,$44876f,$04a191,$7accd7,$3015b7
    .dc $73150a,$7fffff,$44a036,$04a3a9,$7ac5a1,$30f82d,$732c6b,$7fffff
    .dc $44b924,$04a5c4,$7abe4b,$31dbb7,$73435f,$7fffff,$44d23a,$04a7e2
    .dc $7ab6d5,$32c058,$7359e9,$7fffff,$44eb78,$04aa04,$7aaf3e,$33a60e
    .dc $73700d,$7fffff,$45119d,$04ad3d,$7aa39c,$3500a1,$73908a,$7fffff
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
    .dc $000000,$68f5c3,$00a521,$6938d8,$014a43,$697bee,$01ef64,$69bf03
    .dc $029485,$6a0219,$0339a7,$6a452e,$03dec8,$6a8844,$0483e9,$6acb59
    .dc $05290a,$6b0e6f,$05ce2c,$6b5184,$06734d,$6b949a,$07186e,$6bd7af
    .dc $07bd90,$6c1ac5,$0862b1,$6c5dda,$0907d2,$6ca0f0,$09acf4,$6ce405
    .dc $0a5215,$6d271b,$0af736,$6d6a31,$0b9c57,$6dad46,$0c4179,$6df05c
    .dc $0ce69a,$6e3371,$0d8bbb,$6e7687,$0e30dd,$6eb99c,$0ed5fe,$6efcb2
    .dc $0f7b1f,$6f3fc7,$102041,$6f82dd,$10c562,$6fc5f2,$116a83,$700908
    .dc $120fa4,$704c1d,$12b4c6,$708f33,$1359e7,$70d248,$13ff08,$71155e
    .dc $14a42a,$715873,$15494b,$719b89,$15ee6c,$71de9f,$16938e,$7221b4
    .dc $1738af,$7264ca,$17ddd0,$72a7df,$1882f1,$72eaf5,$192813,$732e0a
    .dc $19cd34,$737120,$1a7255,$73b435,$1b1777,$73f74b,$1bbc98,$743a60
    .dc $1c61b9,$747d76,$1d06db,$74c08b,$1dabfc,$7503a1,$1ea3ae,$756841
    .dc $1ef63e,$7589cc,$1f9b60,$75cce1,$204081,$760ff7,$20e5a2,$76530c
    .dc $218ac4,$769622,$222fe5,$76d938,$22d506,$771c4d,$237a28,$775f63
    .dc $241f49,$77a278,$24c46a,$77e58e,$25698b,$7828a3,$260ead,$786bb9
    .dc $26b3ce,$78aece,$2758ef,$78f1e4,$27fe11,$7934f9,$28f5c3,$79999a
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
