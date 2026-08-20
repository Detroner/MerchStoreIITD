import assert from 'node:assert/strict';

const origin=process.env.PREVIEW_ORIGIN||'http://127.0.0.1:4173';
let cookie='';
let proof='';

async function request(path,{method='GET',body,admin=false}={}){
  const response=await fetch(`${origin}${path}`,{method,headers:{...(body?{'Content-Type':'application/json'}:{}),...(cookie?{Cookie:cookie}:{}),...(admin?{'X-Admin-Proof':proof}:{})},body:body?JSON.stringify(body):undefined});
  const text=await response.text();
  let payload={};try{payload=text?JSON.parse(text):{}}catch{payload={text}}
  if(!response.ok)throw new Error(`${method} ${path} failed (${response.status}): ${text}`);
  return {response,payload};
}

const login=await request('/api/admin/login',{method:'POST',body:{email:'admin@iitdmerch.local',password:'IITD@2026!'}});
cookie=login.response.headers.get('set-cookie').split(';')[0];
proof=login.payload.proof;
assert.ok(cookie&&proof);

const catalogue=(await request('/api/catalog?limit=24')).payload.items;
assert.ok(catalogue.length>12);
assert.ok(catalogue.every(item=>item.catalogItemId&&item.colorwayName));
assert.ok(catalogue.filter(item=>item.id==='tee').length>=2);

const data=(await request('/api/admin/data',{admin:true})).payload;
assert.ok(data.products[0].colorways.length);
assert.ok(data.products.some(product=>product.customization));

const orders=(await request('/api/admin/orders',{admin:true})).payload.items;
const summary=(await request('/api/admin/orders/summary',{admin:true})).payload.summary;
const matrix=(await request('/api/admin/orders/matrix',{admin:true})).payload.rows;
assert.equal(summary.orders,orders.length);
assert.ok(matrix.every(row=>row.color&&row.size&&row.sku));

const preview=(await request('/api/admin/vendor-batches/preview',{method:'POST',admin:true,body:{filters:{}}})).payload;
assert.ok(preview.eligible.length);
const created=(await request('/api/admin/vendor-batches',{method:'POST',admin:true,body:{filters:{},orderItemIds:preview.eligible.map(item=>item.order_item_id),idempotencyKey:crypto.randomUUID()}})).payload.batch;
const detail=(await request(`/api/admin/vendor-batches/${created.id}`,{admin:true})).payload;
assert.match(detail.message,/PRODUCTION UPDATE/);
assert.match(detail.message,/CUSTOMIZED:/);
const sent=(await request(`/api/admin/vendor-batches/${created.id}/mark-sent`,{method:'POST',admin:true,body:{}})).payload.batch;
assert.equal(sent.status,'sent');

console.log(JSON.stringify({ok:true,catalogueCards:catalogue.length,orders:orders.length,matrixRows:matrix.length,batch:created.batch_no,status:sent.status}));
