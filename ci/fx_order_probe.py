"""Headless native-menu/audio check; never opens a MIDI port or hardware device.

Requires the owner's mdEncoderPress emulator, factory NVRAM and stock ROM.
python ci/fx_order_probe.py --probe ... --stock ... --factory ... --rom ... --out ...
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess

p=argparse.ArgumentParser()
for name in ['probe','stock','factory','rom','out']:
    p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args()
for name in vars(a): setattr(a,name,getattr(a,name).resolve())
a.out.mkdir(parents=True,exist_ok=True)
home=a.out/'home';(home/'nvram').mkdir(parents=True,exist_ok=True)
shutil.copy2(a.factory,home/'nvram'/a.factory.name)
lines=[f'rom {a.rom}','boot 12','assign 0 16',
       'midi b0 1c 28','midi b0 1d 46','midi b0 1e 00','midi b0 1f 32','midi b0 20 28',
       'chord patternsong','tap enter','tap down','tap right','tap down','tap down','tap down',
       'lcd routing','tap enter','lcd initial','mem page 281a46 4']
def capture(name):
    lines.extend(['run 0.1',f'lcd {name}',f'mem {name} 71216d 1',
                  f'dspdump {a.out/(name+".bin")} 1 Y 0x23f 1',
                  f'ramcapture {a.out/(name+".raw")}', 'midinow 90 24 7f','run 0.8','ramcapture off'])
capture('post-post')
lines+=['tap left'];capture('dist-pre')
lines+=['tap down','tap left'];capture('both-pre')
lines+=['tap up','tap right'];capture('srr-pre')
lines+=['tap down','tap right'];capture('restored')
lines+=['tap up','tap left','tap down','tap left','tap exit','lcd exited','mem exit-page 281a46 4',
        'tap exit','lcd slots','tap right','tap enter','tap enter','lcd global2','mem slot2 7120ca 1',
        f'dspdump {a.out/"global2.bin"} 1 Y 0x23f 1',
        'tap exit','tap left','tap enter','tap enter','lcd global1','mem slot1 7120ca 1',
        f'dspdump {a.out/"global1.bin"} 1 Y 0x23f 1','run 1','regs']
global_dump=a.out/'global.syx'
lines += [f'req 51 0 {global_dump}','poke 71216d 00',
          'tap exit','tap right','tap enter','tap left','tap enter','tap enter',
          f'dspdump {a.out/"before-import.bin"} 1 Y 0x23f 1',
          f'send {global_dump}','run 0.1','mem imported 71216d 1',
          f'dspdump {a.out/"after-import.bin"} 1 Y 0x23f 1','tap exit','tap exit']
# All sixteen tracks exercise the linked custom-drive path, including silent
# samples, on the built image's VADBD (ID 6). Re-read every helper word afterward.
lines += [f'assign {track} 6' for track in range(16)]
lines += ['tap play','run 3','tap stop','run 0.1',
          f'dspdump {a.out/"helper.bin"} 1 P 0x146800 160','hoststate 1','regs']
script=a.out/'script.txt';script.write_text('\n'.join(lines)+'\n')
env=dict(os.environ,GEARMULATOR_MD_HOME=str(home)+os.sep,
         GEARMULATOR_MD_DEV_ROM=str(a.rom),GEARMULATOR_MD_STOCK_ROM=str(a.stock))
# Caller supplies DLL search paths if the executable's directory is not enough.
with (a.out/'probe.log').open('w') as log:
    subprocess.run([str(a.probe),str(script)],env=env,cwd=a.out,stdout=log,stderr=subprocess.STDOUT,
                   creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),timeout=600,check=True)
log=(a.out/'probe.log').read_text()
assert 'mem page 0x281a46: 00 00 00 3f' in log
assert 'mem exit-page 0x281a46: 00 00 00 0b' in log
assert 'mem slot2 0x7120ca: 01' in log and 'mem slot1 0x7120ca: 00' in log
assert 'mem imported 0x71216d: 30' in log,'global SysEx did not retain both placement bits'
reference=json.loads((a.rom.parent/'dsp-test.json').read_text())['patch']['words']
assert (a.out/'helper.bin').read_bytes()==b''.join(w.to_bytes(3,'big') for w in reference),'DSP helper overwritten during playback'
for name,want in [('post-post',0),('dist-pre',1),('both-pre',3),('srr-pre',2),('restored',0),('global2',0),('global1',3),('before-import',0),('after-import',3)]:
    got=int.from_bytes((a.out/(name+'.bin')).read_bytes(),'big')
    assert got==want,(name,got,want)
    print(name,got)
for name in ['post-post','dist-pre','both-pre','srr-pre','restored']:
    b=(a.out/(name+'.raw')).read_bytes();x=struct.unpack('<'+'f'*(len(b)//4),b)
    assert x and all(-1.001<=v<=1.001 for v in x),name
    assert max(map(abs,x))>0.00001,(name,'silent')
    print(name,'peak',max(map(abs,x)))
try:
    from PIL import Image
    for name,rows in re.findall(r'--- LCD (\S+) ---\n(.*?)--- end \1 ---',log,re.S):
        im=Image.new('L',(128,64));im.putdata([0 if c=='#' else 255 for line in rows.splitlines()[:64] for c in line])
        im.resize((768,384),Image.Resampling.NEAREST).save(a.out/(name+'.png'))
except ImportError:
    pass
print('PASS: native menu, all four DSP modes, global-slot changes, global SysEx, non-silent audio; helper intact with 16 custom-drive tracks')
