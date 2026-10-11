// The browsing catalog lives in the engine so the default machine-select menus follow it.
export { catalog, categories, describe, describeModel } from '../../engine/src/sound_catalog.js';

const shortLabels: Record<string, string> = {
  VADBD: 'Analog-style bass drums', VADSD: 'Analog-style snares', VADRC: 'Rimshots and clap',
  VADPC: 'Toms and hand percussion', VADHH: 'Analog-style hi-hats', VADCY: 'Cymbals and cowbells',
  VADSY: 'Analog-style synth', OSCAC: 'Acid bass', FMS4O: 'Four-operator FM synth',
  FMS2O: 'Two-operator FM synth', FMS3O: 'Three-operator FM synth', FMSSW: 'FM synth',
  OSCSP: 'Saw and pulse synth', OSCSW: 'Unison saw synth', OSCPW: 'Pulse synth',
  OSC8B: 'SID-style synth', OSCCH: 'Chord synth', WAVTB: 'Wavetable synth',
  WAVMR: 'Dual wavetable synth', WAVCH: 'Wavetable chords', WAVSP: 'Spectral wavetable synth',
  VOXFR: 'Formant synth', VOXVO: 'Vowel synth', PHYKS: 'Plucked and hammered strings',
  NFX4P: 'Filter for the previous track', NZEPL: 'Noise and drone synth',
};
export const shortSoundLabel = (name: string, fallback: string): string => shortLabels[name.trim()] ?? fallback;
