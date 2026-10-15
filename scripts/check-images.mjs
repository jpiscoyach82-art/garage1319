import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const root=path.resolve(import.meta.dirname,'..'),context={window:{}};
vm.runInNewContext(await fs.readFile(path.join(root,'assets/js/image-map.js'),'utf8'),context);
const map=context.window.GARAGE_IMAGE_MAP;const errors=[];
for(const [url,file] of Object.entries(map)){
  if(!file.startsWith('assets/images/catalog/')||file.includes('..')){errors.push(`Ruta inválida: ${file}`);continue}
  try{const data=await fs.readFile(path.join(root,file));if(data.length<32)errors.push(`Imagen vacía: ${file}`);else if(file.endsWith('.webp')&&(data.toString('ascii',0,4)!=='RIFF'||data.toString('ascii',8,12)!=='WEBP'||data.readUInt32LE(4)+8!==data.length))errors.push(`WebP incompleto: ${file}`)}catch{errors.push(`Imagen local ausente: ${file}`)}
}
let products=JSON.parse(await fs.readFile(path.join(root,'scripts/catalog-images-source.json'),'utf8'));
if(process.argv.includes('--live')){
  vm.runInNewContext(await fs.readFile(path.join(root,'assets/js/config.js'),'utf8'),context);
  const cfg=context.window.GARAGE_CONFIG;
  const {stdout}=await promisify(execFile)('curl',['--fail','--silent','--show-error','--max-time','30','-H',`apikey: ${cfg.supabasePublicKey}`,`${cfg.supabaseUrl}/rest/v1/productos?select=codigo,imagen,imagen_posterior&visible=eq.true`]);
  products=JSON.parse(stdout);if(!Array.isArray(products))throw new Error('Respuesta de inventario inválida');
}
for(const p of products)for(const field of ['imagen','imagen_posterior']){
  const url=p[field];if(!url){errors.push(`${p.codigo}: falta ${field}`);continue}
  if(/^https:\/\//.test(url)&&!map[url])errors.push(`${p.codigo}: ${field} todavía depende de ${new URL(url).hostname}`);
}
console.log(`${products.length} productos; ${Object.keys(map).length} fotos locales verificadas.`);
if(errors.length){console.error(errors.join('\n'));process.exitCode=1}
