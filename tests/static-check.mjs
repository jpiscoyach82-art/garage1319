import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root=path.resolve(import.meta.dirname,"..");
const htmlFiles=["index.html","privacidad.html","admin/index.html"];
const jsFiles=["assets/js/config.js","assets/js/data.js","assets/js/app.js","assets/js/admin.js","sw.js"];
const errors=[];

for(const relative of htmlFiles){
  const file=path.join(root,relative),html=fs.readFileSync(file,"utf8");
  const ids=[...html.matchAll(/\sid="([^"]+)"/g)].map(match=>match[1]);
  const duplicates=[...new Set(ids.filter((id,index)=>ids.indexOf(id)!==index))];
  if(duplicates.length)errors.push(`${relative}: IDs duplicados: ${duplicates.join(", ")}`);
  if(/\son(?:click|input|change|submit)=/i.test(html))errors.push(`${relative}: contiene eventos JavaScript inline`);
  if(/data:image\//i.test(html))errors.push(`${relative}: contiene imágenes base64`);
  for(const match of html.matchAll(/(?:src|href)="([^"#?]+)"/g)){
    const reference=match[1];
    if(/^(?:https?:|mailto:|tel:)/i.test(reference))continue;
    if(!fs.existsSync(path.resolve(path.dirname(file),reference)))errors.push(`${relative}: falta ${reference}`);
  }
}

if(fs.statSync(path.join(root,"index.html")).size>50_000)errors.push("index.html supera 50 KB");
for(const relative of jsFiles){
  try{new vm.Script(fs.readFileSync(path.join(root,relative),"utf8"),{filename:relative})}
  catch(error){errors.push(`${relative}: ${error.message}`)}
}

const storefront=fs.readFileSync(path.join(root,"index.html"),"utf8");
for(const id of ["sales-banner","productDetailModal","detailImage","detailScale","detailCondition","detailEdition","detailStock","detailDelivery","detailWhatsapp","detailAdd","floatingWhatsapp"]){
  if(!storefront.includes(`id="${id}"`))errors.push(`index.html: falta el componente de detalle ${id}`);
}
const admin=fs.readFileSync(path.join(root,"admin/index.html"),"utf8");
for(const id of ["productPromoPrice","productScale","productCondition","productEdition","productBackImage","productDelivery","productFeatures"]){
  if(!admin.includes(`id="${id}"`))errors.push(`admin/index.html: falta el campo ${id}`);
}
const collectorMigration=path.join(root,"supabase/migrations/20260916_collector_product_details.sql");
if(!fs.existsSync(collectorMigration))errors.push("falta la migración de fichas de coleccionista");
else{
  const sql=fs.readFileSync(collectorMigration,"utf8");
  for(const column of ["precio_promocional","imagen_posterior","escala","condicion_empaque","tipo_edicion","entrega","caracteristicas"]){
    if(!sql.includes(column))errors.push(`migración de coleccionista: falta ${column}`);
  }
}

if(errors.length){console.error(errors.join("\n"));process.exit(1)}
console.log("Garage 1319 V2: validación estática correcta.");
