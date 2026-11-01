// Lossless APNG container assembly of unmodified Godot viewport PNG frames.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const root = resolve(import.meta.dirname, '..');
const signature = Buffer.from([137,80,78,71,13,10,26,10]);
const table = new Uint32Array(256);
for (let n=0;n<256;n++) { let c=n; for(let k=0;k<8;k++) c=(c&1)?0xedb88320^(c>>>1):c>>>1; table[n]=c>>>0; }
function chunk(type,data) {
  const name=Buffer.from(type), payload=Buffer.concat([name,data]);
  let crc=0xffffffff; for (const byte of payload) crc=table[(crc^byte)&255]^(crc>>>8);
  const result=Buffer.alloc(12+data.length); result.writeUInt32BE(data.length); name.copy(result,4); data.copy(result,8); result.writeUInt32BE((crc^0xffffffff)>>>0,8+data.length); return result;
}
function parse(bytes) {
  if(!bytes.subarray(0,8).equals(signature)) throw new Error('Not a PNG frame');
  const result=[]; for(let offset=8;offset<bytes.length;) { const length=bytes.readUInt32BE(offset); const type=bytes.toString('ascii',offset+4,offset+8); result.push({type,data:bytes.subarray(offset+8,offset+8+length)}); offset+=12+length; } return result;
}
const folder=process.argv[2] || 'artifacts/walk-preview';
const target=resolve(root,process.argv[3] || 'artifacts/walk-cycle-preview.png');
const delay=Number(process.argv[4] || 75);
const frameCount=Number(process.argv[5] || 16);
if(!Number.isInteger(frameCount) || frameCount<1 || frameCount>600) throw new Error('Invalid frame count');
const frames=Array.from({length:frameCount},(_,i)=>parse(readFileSync(resolve(root,`${folder}/frame-${String(i).padStart(2,'0')}.png`))));
const header=frames[0].find(c=>c.type==='IHDR').data;
const output=[signature,chunk('IHDR',header)];
const animation=Buffer.alloc(8); animation.writeUInt32BE(frames.length); animation.writeUInt32BE(0,4); output.push(chunk('acTL',animation));
let sequence=0;
frames.forEach((frame,index)=>{
  if(!frame.find(c=>c.type==='IHDR').data.equals(header)) throw new Error('Frame dimensions or format differ');
  const control=Buffer.alloc(26); control.writeUInt32BE(sequence++,0); header.copy(control,4,0,8); control.writeUInt16BE(delay,20); control.writeUInt16BE(1000,22); output.push(chunk('fcTL',control));
  for(const item of frame.filter(c=>c.type==='IDAT')) {
    if(index===0) output.push(chunk('IDAT',item.data));
    else { const prefix=Buffer.alloc(4); prefix.writeUInt32BE(sequence++); output.push(chunk('fdAT',Buffer.concat([prefix,item.data]))); }
  }
});
output.push(chunk('IEND',Buffer.alloc(0)));
writeFileSync(target,Buffer.concat(output));
process.stdout.write(`WALK_PREVIEW_APNG ${target}\n`);
