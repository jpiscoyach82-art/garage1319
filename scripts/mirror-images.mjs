import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const run=promisify(execFile);
const root=path.resolve(import.meta.dirname,'..');
const products=JSON.parse(await fs.readFile(path.join(root,'scripts/catalog-images-source.json'),'utf8'));
const urls=[...new Set(products.flatMap(p=>[p.imagen,p.imagen_posterior]).filter(u=>/^https:\/\//.test(u)))];
const target=path.join(root,'assets/images/catalog');
await fs.mkdir(target,{recursive:true});
const manifest={};const failures=[];
let cursor=0;
async function worker(){while(cursor<urls.length){const url=urls[cursor++],hash=crypto.createHash('sha256').update(url).digest('hex').slice(0,20),temp=path.join(target,hash+'.download');try{
  await run('curl',['--fail','--silent','--show-error','--location','--max-time','30','--retry','1','--max-filesize','12000000','--output',temp,url],{timeout:70000});
  const b=await fs.readFile(temp);let ext='';
  if(b[0]===255&&b[1]===216&&b[2]===255)ext='jpg';
  else if(b.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))ext='png';
  else if(b.toString('ascii',0,4)==='RIFF'&&b.toString('ascii',8,12)==='WEBP')ext='webp';
  else if(b.toString('ascii',0,3)==='GIF')ext='gif';
  else if(b.toString('ascii',4,8)==='ftyp'&&/avif|avis/.test(b.toString('ascii',8,24)))ext='avif';
  if(!ext)throw new Error('Response is not a supported image');
  const file=`assets/images/catalog/${hash}.${ext}`;await fs.rename(temp,path.join(root,file));manifest[url]=file;
}catch(e){failures.push({url,error:String(e.message).slice(0,180)});await fs.rm(temp,{force:true});}
if((Object.keys(manifest).length+failures.length)%25===0)console.log(`${Object.keys(manifest).length} verified, ${failures.length} failed`);
}}
await Promise.all(Array.from({length:8},worker));
await fs.writeFile(path.join(root,'assets/js/image-map.js'),'// Verified local mirrors; original URLs remain unchanged in the inventory.\nwindow.GARAGE_IMAGE_MAP=Object.freeze('+JSON.stringify(manifest,null,2)+');\n');
await fs.writeFile(path.join(root,'scripts/image-mirror-failures.json'),JSON.stringify(failures,null,2)+'\n');
console.log(JSON.stringify({total:urls.length,mirrored:Object.keys(manifest).length,failures:failures.length}));
