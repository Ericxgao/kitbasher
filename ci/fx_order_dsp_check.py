"""Run the emitted routing code in the DSP56300 interpreter.

Input: dsp-test.json from fx-order-build.mjs (local firmware, never committed).
python ci/fx_order_dsp_check.py <dsp-test.json> <dsphost-plain.exe> <output-dir>
"""
import json
from pathlib import Path
import random
import subprocess
import sys

source,host,out=map(lambda s:Path(s).resolve(),sys.argv[1:])
out.mkdir(parents=True,exist_ok=True);data=json.loads(source.read_text())
def binary(name,words):
    p=out/name;p.write_bytes(b''.join(int(w).to_bytes(3,'big') for w in words));return p
def loads(records,prefix):
    return [f"load {'PXY'[r['space']]} {r['addr']:x} {binary(f'{prefix}{k}.bin',r['words'])}" for k,r in enumerate(records)]
native=loads(data['base'],'base');patch=loads(data['patch']['records'],'patch')
# EQ entry needs its coefficient pointer; the native EQ input is X:$b..$2a.
# Return from the scheduler rather than continuing into the mixer. The test
# caller makes R7 linear, as the native track renderer does before entering EQ.
setup=binary('setup.bin',[0x355000,0x05f427,0xffffff,0x0bf080,0xd2,0x00000c])
def render(mode,dist,srr,drive=None):
    lines=native[:]+(loads(drive['records'],drive['name']) if drive else [])+(patch if mode>=0 else [])
    lines += [f'load P 146a00 {setup}','set P 26f c','set P 6f c','voice 200','set X ff 3000',f'set Y 23f {max(mode,0):x}']
    if drive: lines.append(f"set Y 209 {drive['selector'][drive['name']]:x}")
    for off,v in [(2,64<<7),(3,64<<7),(4,40<<7),(5,70<<7),(6,0),(7,srr<<7),(8,dist<<7),
                  (0x22,40<<4),(0x23,0),(0x24,110<<4),(0x26,0)]:
        lines.append(f'set Y {0x200+off:x} {v:x}')
    rng=random.Random(321)
    for block in range(24):
        for n in range(32):lines.append(f'set X {11+n:x} {rng.randint(-1000000,1000000)&0xffffff:x}')
        lines+=['call 146a00','cycles','dump X 3000 20','dump Y 200 3f','regs']
    name=f'{drive["name"] if drive else "native"}-{mode}-{dist}-{srr}';p=out/(name+'.txt');p.write_text('\n'.join(lines)+'\n')
    r=subprocess.run([str(host),str(p),str(out/(name+'.raw'))],capture_output=True,text=True,check=True)
    (out/(name+'.log')).write_text(r.stdout+r.stderr)
    assert all(' sp 0 sc 0 ' in s for s in r.stdout.splitlines() if s.startswith('regs ')), 'unbalanced DSP stack'
    dumps=[s for s in r.stdout.splitlines() if s.startswith('dump ')]
    return dumps
cases=0
for dist in [0,32,80,127]:
    for srr in [0,50,127]:
        original=render(-1,dist,srr);default=render(0,dist,srr)
        assert original==default,('default differs from native audio/state',dist,srr)
        cases+=1
outputs=[]
for mode in range(4):
    dumps=render(mode,40,50);audio=dumps[0::2]
    assert any(int(w,16)!=0 for row in audio for w in row.split()[1:]),('silent',mode)
    outputs.append(audio)
assert len({tuple(x) for x in outputs})==4,'routing modes produce identical output'
for drive in data.get('drives',[]):
    assert render(-1,40,50,drive)==render(0,40,50,drive),(drive['name'],'default changed')
    for mode in [1,2,3]:render(mode,40,50,drive)
print(f'PASS: {cases} parameter pairs x 24 blocks bit-identical native/default audio and state; all four orders audible/distinct; DSP stack balanced')
print(f"PASS: {len(data.get('drives',[]))} custom drive laws, identical default and balanced calls in all orders")
