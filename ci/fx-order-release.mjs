// Verify a combined FX ORDER / SWAP SPEEDS update and derive its emulator image.
// node ci/fx-order-release.mjs <stock-x14.bin> <update.syx>
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFirmware} from '../engine/dist/src/container.js';
import {identify,codeImages} from '../engine/dist/src/bases.js';
import {loadBases} from '../engine/dist/src/node.js';
import {decodeSyx} from '../engine/dist/src/syx.js';
import {firmwarePackets} from '../engine/dist/src/firmware_transfer.js';
import {readBootRamWrites} from '../engine/dist/src/boot_safety.js';
import {fxOrderCode} from '../engine/dist/src/fx_order.js';
import {fxOrderDsp} from '../engine/dist/src/fx_order_dsp.js';
import {findEncoderSettings,encoderSettingsCode,encoderSettingsPatches} from '../engine/dist/src/encoder_speed.js';
import {isaGate} from '../engine/dist/src/isa_gate.js';
import {wordsLE,u32} from '../engine/dist/src/bytes.js';
import {memory} from '../engine/dist/src/clean_recovery.js';
const [stockFile,syxFile]=process.argv.slice(2),dir=path.dirname(syxFile);
const stock=fs.readFileSync(stockFile),syx=fs.readFileSync(syxFile),packets=firmwarePackets(syx);
const fw=readFirmware(stock),{base}=await identify(fw,loadBases('bases'));
assert.equal(base.id,'x14');
const er=JSON.parse(fs.readFileSync(path.join(dir,'candidate.engine.json')));
const gr=JSON.parse(fs.readFileSync(path.join(dir,'candidate.json')));
assert(er.gates.every(g=>g.ok));
const image=Buffer.from(stock),container=decodeSyx(syx);
image.fill(255,0x4000,0x100000);image.set(container,0x4000);
const binFile=path.join(dir,'candidate.bin');
if(fs.existsSync(binFile))assert(image.equals(fs.readFileSync(binFile)),'SysEx differs from built image');
assert(image.subarray(0,0x4000).equals(stock.subarray(0,0x4000)));
assert.equal(image.readUInt16BE(0x3ffe),0x224b);
assert(image.subarray(0x100000).equals(stock.subarray(0x100000)));
const back=readFirmware(image),images=codeImages(fw,base);
const writes=readBootRamWrites(image,u32(image,base.boot.jumpOperand),base.boot.sram),w=new Map(writes);
const fxAt=parseInt(er.features.fx_order.code),sender=w.get(base.features.dsp1Drive.senderSites[0]);
// Obtain the chained sender from the emitted wrapper's last absolute jump.
const dummy=fxOrderCode(images,fxAt,base.features.dsp1Drive.sender);
const nativeJump=dummy.code.labels.global_apply-fxAt-4;
const chained=image.readUInt32BE(fxAt-0x10000000+nativeJump);
const fx=fxOrderCode(images,fxAt,chained);
assert.equal(sender,fx.code.labels.sender);
const encAt=parseInt(gr.encoder_settings.at),settings=findEncoderSettings(images);
const enc=encoderSettingsCode(settings,0x10000000+encAt),hooks=encoderSettingsPatches(images,settings,enc.labels);
for(const [at,code,patches] of [[fxAt-0x10000000,fx.code,fx.patches],[encAt,enc,hooks.patches]]) {
  assert(image.subarray(at,at+code.bytes.length).equals(Buffer.from(code.bytes)));
  for(const [a,v] of patches)assert.equal(w.get(a),v);
}
const dsp=fxOrderDsp(wordsLE(fw.slots[2].raw)),upload=wordsLE(back.slots[2].raw);
for(const r of dsp.records){const m=memory(upload,r.space);r.words.forEach((v,i)=>assert.equal(m.get(r.addr+i),v));}
const isa=isaGate(fw,base,back,hooks.ranges);assert(isa.ok,isa.detail);
const sha=b=>createHash('sha256').update(b).digest('hex');
const report={base:'X.14',sourceCommit:process.env.SOURCE_COMMIT,binSha256:sha(image),syxSha256:sha(syx),
  file:path.basename(syxFile),bytes:syx.length,packets:packets.length,buildGates:er.gates.length,
  features:['FX ORDER','SWAP SPEEDS including LEVEL'],flashChecks:'OS-only canonical packets; boot block and data outside OS unchanged; exact hooks/code/DSP readback; ISA_A',
  emulatorPassed:false,transferred:false,hardwareConfirmed:false};
fs.writeFileSync(binFile,image);
fs.writeFileSync(path.join(dir,'dsp-test.json'),JSON.stringify({patch:dsp}));
fs.writeFileSync(path.join(dir,'release.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
