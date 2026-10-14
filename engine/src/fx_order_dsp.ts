// GLOBAL > ROUTING > FX ORDER. The native AM/EQ stay first; only the three
// following stages move. Mode bit 0 = DIST pre-filter, bit 1 = SRR pre-filter.
import { memory } from './clean_recovery.js';

export const FX_ORDER_PROGRAM = 0x146800;
export const FX_ORDER_WORD = 0x23f; // spare last word of track 0's Y parameter block
export type FxRecord = { space: number; addr: number; words: number[] };

const SRR = [0x040ec5,0x22b700,0x021efe,0x0140c0,0x004000,0x5fdd00,
  0x11dd00,0x44f480,0x000010,0x016084,0x0c1d04,0x340240,0x21c571,
  0x062080,0x000231,0x46e448,0x5e5c6d,0x202151,0x20216c,0x5e5c00,0x5f5f00];

/** Build around the native filter and DIST, including any linked custom drive.
 * Each stage executes once. DIST's old scheduler return becomes a balanced RTS;
 * the routing dispatcher owns the final scheduler jump. No DSP2 code changes.
 */
export function fxOrderDsp(upload: number[], at = FX_ORDER_PROGRAM) {
  const native = memory(upload);
  for (const [site, expected] of [
    [0x135,[0x0b76d2,0x26]], [0x21f,SRR],
    [0x234,[0x60f400,0x143777,0x0226bf,0x0c1c8d,0x340300,0x21f800,0x5e5f00]],
    [0x26f,[0x0c006f]],
  ] as const) {
    if(expected.some((w,i)=>native.get(site+i)!==w))
      throw new Error(`FX order: unfamiliar DSP1 stage at $${site.toString(16)}`);
  }
  const words:number[]=[], labels:Record<string,number>={}, fixes:[number,string][]=[];
  const label=(name:string)=>{labels[name]=at+words.length;};
  const jump=(op:number,name:string)=>{words.push(op,0);fixes.push([words.length-1,name]);};
  const call=(name:string)=>jump(0x0bf080,name);
  label('entry');
  words.push(0x5ef000,FX_ORDER_WORD,0x200003); // move y:mode,a; tst a
  jump(0x0af0aa,'post_post');
  words.push(0x014184); jump(0x0af0aa,'dist_pre'); // sub #1,a
  words.push(0x014184); jump(0x0af0aa,'srr_pre');
  words.push(0x014184); jump(0x0af0aa,'both_pre');
  // Unknown values retain the native order.
  label('post_post'); call('filter'); call('srr'); call('dist'); words.push(0x0c006f);
  label('dist_pre');
  call('eq_dist'); call('dist'); call('dist_filter'); call('filter');
  call('srr'); call('srr_output'); words.push(0x0c006f);
  label('srr_pre');
  call('eq_srr'); call('srr'); call('srr_filter'); call('filter');
  call('filter_dist'); call('dist'); words.push(0x0c006f);
  label('both_pre');
  call('eq_srr'); call('srr'); call('dist'); call('dist_filter');
  call('filter'); call('filter_output'); words.push(0x0c006f);
  label('filter'); words.push(0x0b76d2,0x26,0x0c0137);
  label('srr');
  const srr = SRR.slice();
  srr[14] = labels.srr + (0x231-0x21f); // relocate the DO end, not its count
  words.push(...srr,0x5e5f00,0x00000c); // save the held sample (formerly $23a); RTS
  label('dist');
  // SRR and DIST originally share R5/R7 setup. Establish DIST's own state
  // pointers so it also works before SRR; its input is always Y:$3..$22.
  words.push(0x040ec5,0x205d00,0x205d00,0x22b700,0x60f400,0x143777,0x0226bf,0x0c1c8d,
    0x340300,0x21f800,0x0c023b);
  const copy=(name:string,src:number|'output',spaceIn:'X'|'Y',dst:number|'output',spaceOut:'X'|'Y')=>{
    label(name);
    words.push(src==='output'?0x60f000:0x60f400,src==='output'?0xff:src,
      dst==='output'?0x61f000:0x61f400,dst==='output'?0xff:dst);
    words.push(0x062080,at+words.length+3,
      spaceIn==='X'?0x56d800:0x5ed800,spaceOut==='X'?0x565900:0x5e5900,0x00000c);
  };
  // EQ's first store is pipeline history at X:$9. Its 32 current samples are
  // X:$a..$29. Filter output is X:$2..$21; SRR output is Y:$3..$22.
  copy('eq_dist',10,'X',3,'Y'); copy('eq_srr',10,'X',2,'X');
  copy('dist_filter','output','X',10,'X'); copy('srr_filter',3,'Y',10,'X');
  copy('filter_dist',2,'X',3,'Y'); copy('srr_output',3,'Y','output','X');
  copy('filter_output',2,'X','output','X');
  for(const [index,name] of fixes)words[index]=labels[name];
  // External P/X/Y alias. Reject loaded data as well as code at this allocation.
  for(const space of [0,1,2]) {
    const m=memory(upload,space);
    if(words.some((_,i)=>m.has(at+i)))throw new Error('FX order: DSP1 helper allocation is occupied');
  }
  const recs:FxRecord[]=[
    {space:0,addr:at,words},
    {space:0,addr:0x135,words:[0x0af080,labels.entry]},
    {space:0,addr:0x21f,words:[0x00000c]},
    {space:0,addr:0x26f,words:[0x00000c]},
    {space:2,addr:FX_ORDER_WORD,words:[0]},
  ];
  return {records:recs,labels,words};
}
