// Add the shared settings feature to an already-built private image. Existing
// RAM-copy sources and patch entries stay intact; append code and a new table.
import { codeImages, type Base } from './bases.js';
import { readFirmware, type Firmware, OS_LIMIT } from './container.js';
import { readBootRamWrites } from './boot_safety.js';
import { be32, equal, u32 } from './bytes.js';
import { encoderSettingsCode, encoderSettingsPatches, findEncoderSettings } from './encoder_speed.js';
import { encodeSyx } from './syx.js';

export function installEncoderSettings(stock:Firmware, base:Base, input:Uint8Array) {
  const fw=readFirmware(input), image=fw.flash.slice(), images=codeImages(stock,base);
  const settings=findEncoderSettings(images), routine=u32(image,base.boot.jumpOperand);
  let loop=routine;
  for(let copies=0;copies<2&&u32(image,loop)>>>16===0x41f9&&u32(image,loop+6)>>>16===0x43f9;copies++)loop+=24;
  // Private loader images chain to an additional low-flash startup routine.
  // Validate the standard copy/write loop independently, retaining that exact
  // successor. This installer neither executes nor changes its boot logic.
  const successor=u32(image,loop+22);
  const readWrites=(bytes:Uint8Array)=>{
    const view=bytes.slice();
    if(successor>=0x4000&&successor<OS_LIMIT)view.set(be32(base.os.osMain),loop+22);
    return readBootRamWrites(view,routine,base.boot.sram);
  };
  const prior=readWrites(image), oldTable=u32(image,loop+2);
  const extendTable=oldTable+prior.length*8===fw.osEnd;
  const hookCount=encoderSettingsPatches(images,settings,encoderSettingsCode(settings,0x10000000).labels).patches.length;
  const at=((fw.osEnd+(extendTable?hookCount*8:0))+3)&~3, code=encoderSettingsCode(settings,0x10000000+at);
  const hooks=encoderSettingsPatches(images,settings,code.labels);
  if(prior.some(([a])=>hooks.patches.some(([b])=>a<b+4&&b<a+4))) throw new Error('Encoder hooks already modified in this image');
  // The decompressed host code must still contain the same instructions at all
  // hooks. A private image with a different host recipe needs requalification.
  const candidate=codeImages(fw,base);
  for(const [site,word] of hooks.checks){
    const im=candidate.find(i=>site>=i.ram&&site+4<=i.ram+i.bytes.length);
    if(!im||u32(im.bytes,site-im.ram)!==word) throw new Error('Private image changed an encoder hook');
  }
  const table=extendTable?oldTable:at+code.bytes.length, patches=[...prior,...hooks.patches];
  const end=Math.max(at+code.bytes.length,table+8*patches.length);
  if(end>OS_LIMIT) throw new Error(`Reverse Encoder Speed needs ${end-OS_LIMIT} more bytes of OS flash`);
  image.set(code.bytes,at);
  patches.forEach(([a,v],i)=>{image.set(be32(a),table+8*i);image.set(be32(v),table+8*i+4);});
  image.set(be32(table),loop+2);image.set(be32(patches.length),loop+8);
  const got=readWrites(image);
  if(JSON.stringify(got)!==JSON.stringify(patches)||!equal(image.subarray(at,at+code.bytes.length),code.bytes)||u32(image,loop+22)!==successor) throw new Error('Encoder settings readback failed');
  for(let k=0;k<fw.osEnd;k++)if(image[k]!==fw.flash[k]&&!(k>=loop+2&&k<loop+6)&&!(k>=loop+8&&k<loop+12)) throw new Error('Encoder settings changed existing payload');
  const output=fw.kind==='syx'?encodeSyx(image.subarray(0x4000,end)):image;
  return {output,image,report:{at,end,bytes:code.bytes.length,table,priorPatches:prior.length,patches:hooks.patches,ranges:hooks.ranges,settings,hardware:false}};
}
