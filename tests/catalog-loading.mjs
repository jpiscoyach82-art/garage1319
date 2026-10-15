import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('../assets/js/app.js',import.meta.url),'utf8').replace('document.readyState==="loading"?document.addEventListener("DOMContentLoaded",init):init();','window.testApi={state,renderCatalog,loadData,safeImage,optionalImage,addToCart};');
function setup(responses,{backup=true}={}){
  const nodes=new Map();
  const node=id=>{if(!nodes.has(id))nodes.set(id,{hidden:true,textContent:'',innerHTML:'',classList:{add(){},remove(){}},setAttribute(k,v){this[k]=v}});return nodes.get(id)};
  let calls=0;
  const client={from(table){const q={select(){return q},eq(){return q},order(){return q},insert(){return Promise.resolve({})},abortSignal(){return table==='productos'?Promise.resolve(responses[Math.min(calls++,responses.length-1)]):Promise.resolve({data:[]})}};return q}};
  const context={window:{GARAGE_CONFIG:{},GARAGE_IMAGE_MAP:{'https://example.com/front.jpg':'assets/images/catalog/test.jpg'},GARAGE_FALLBACK_PRODUCTS:backup?[{id:'old',code:'TEST',name:'Respaldo',stock:1,image:'assets/test.jpg'}]:[],crypto:{randomUUID:()=> 'test'}},document:{getElementById:node},localStorage:{getItem:()=>null,setItem(){}},console:{warn(){}},URLSearchParams,location:{search:'',pathname:'/'},setTimeout:(fn,ms)=>setTimeout(fn,ms===700?0:ms),clearTimeout,AbortController,URL};
  vm.runInNewContext(source,context);context.window.testApi.state.client=client;
  return {api:context.window.testApi,node,calls:()=>calls};
}
let s=setup([{data:[]}]);s.api.renderCatalog();assert.equal(s.node('resultCount').textContent,'Cargando catálogo…');assert.equal(s.node('emptyState').hidden,true);assert.equal(s.node('catalogGrid')['aria-busy'],'true');
await s.api.loadData();assert.equal(s.api.state.products.length,0,'empty cloud result must not resurrect fallback');assert.equal(s.node('emptyState').hidden,false);assert.equal(s.node('catalogGrid')['aria-busy'],'false');
assert.equal(s.api.safeImage('https://example.com/front.jpg'),'assets/images/catalog/test.jpg');assert.equal(s.api.optionalImage('https://example.com/front.jpg'),'assets/images/catalog/test.jpg');
s=setup([{error:{message:'Temporary failure'}},{data:[{id:1,codigo:'OK',nombre:'Modelo',stock:2,precio:20,imagen:'https://example.com/front.jpg'}]}]);await s.api.loadData();assert.equal(s.calls(),2);assert.equal(s.node('catalogNotice').hidden,true);assert.equal(s.api.state.products.length,1);s.api.addToCart('1');assert.equal(s.node('cartCount').textContent,1);assert.equal(s.node('cartTotal').textContent,'S/ 20');
s=setup([{error:{message:'Offline'}}]);await s.api.loadData();assert.equal(s.calls(),2);assert.equal(s.node('catalogNotice').hidden,false);assert.match(s.node('catalogNoticeText').textContent,/respaldo/);assert.equal(s.node('emptyState').hidden,true);
s=setup([{error:{message:'Offline'}}],{backup:false});await s.api.loadData();assert.equal(s.node('resultCount').textContent,'Inventario no disponible');assert.equal(s.node('emptyState').hidden,true);assert.equal(s.node('catalogNotice').hidden,false);
console.log('Carga: skeleton, éxito vacío, reintento, error, respaldo, fotos locales y carrito correctos.');
