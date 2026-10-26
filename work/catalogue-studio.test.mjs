import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
import test from 'node:test';
import {CouponError} from '../lib/coupons.mjs';

const server=fs.readFileSync(new URL('../server.mjs',import.meta.url),'utf8');
const client=fs.readFileSync(new URL('../src/main.jsx',import.meta.url),'utf8');
const migration=fs.readFileSync(new URL('../migrations/030_unified_catalogue_fonts_pricing.sql',import.meta.url),'utf8');
const line=prefix=>server.split('\n').find(value=>value.startsWith(prefix));
const fonts=['Allison','Story Script','Erica One','Kavoon','Jim Nightshade'];
const variant={id:'variant',product_id:'sweatshirt',slug:'winter-sweatshirt',name:'Sweatshirt',sku:'SWEAT-M',size:'M',color:'Black',base_price:99900,stock_on_hand:10,reserved_stock:0,customizable:true,enabled:true,min_characters:1,max_characters:50,allowed_pattern:'^[A-Za-z0-9 ._-]{1,16}(?:\\n[A-Za-z0-9 ._-]{1,16}){0,2}$',placements:['Back'],styles:fonts,text_colors:['White'],surcharge:0};

test('all five fonts retain their exact name and three lines through quote and order snapshot creation',async()=>{
  for(const style of fonts){
    const requested={text:'Tanish\nIIT Delhi\n2026',placement:'Back',style,color:'White'};
    const quote=await vm.runInNewContext(line('async function calculateQuote(')+';calculateQuote(items)',{items:[{variantId:'variant',qty:1,customization:requested}],query:async()=>({rows:[variant]}),CouponError,paymentStatus:()=>({})});
    assert.deepEqual(JSON.parse(JSON.stringify(quote.items[0].customization)),requested);
    let saved;
    const persist=vm.runInNewContext(line('function addressSnapshot(')+'\n'+line('async function createPendingRazorpayOrder(')+';createPendingRazorpayOrder',{crypto,randomToken:()=> 'test'});
    await persist({query:async(sql,values)=>{if(sql.startsWith('INSERT INTO order_item_customizations'))saved=values;return {rows:[{id:'item'}]}}},{user_id:'user'},quote,{recipient_name:'Test'});
    assert.equal(saved[1],requested.text);assert.equal(saved[3],style);assert.equal(JSON.parse(saved[5]).style,style);
  }
});

test('selected font survives a product reload, and invalid or retired fonts fall back safely',()=>{
  const source=client.split('\n').find(value=>value.startsWith('function savedCustomizationFont('));
  const read=(saved,search)=>vm.runInNewContext(source+';savedCustomizationFont("winter-sweatshirt",fonts)',{fonts,sessionStorage:{getItem:()=>saved},location:{search},URLSearchParams});
  assert.equal(read('Kavoon',''),'Kavoon');assert.equal(read('Allison','?font=Jim+Nightshade'),'Jim Nightshade');
  assert.equal(read('Not installed',''),'Allison');assert.equal(read('Kavoon','?font=Invalid'),'Allison');
});

test('Dogra checkout uses the unified base price after variant overrides are cleared',async()=>{
  assert.match(migration,/UPDATE products SET base_price=69900.*WHERE slug='dogra-drip'/);
  assert.match(migration,/UPDATE product_variants v SET price_override=NULL.*p.id=v.product_id AND p.slug='dogra-drip'/);
  assert.doesNotMatch(migration,/UPDATE order/);
  const quote=await vm.runInNewContext(line('async function calculateQuote(')+';calculateQuote(items)',{items:[{variantId:'dogra',qty:2}],query:async()=>({rows:[{...variant,slug:'dogra-drip',name:'Dogra Drip',customizable:false,base_price:69900,price_override:null}]}),CouponError,paymentStatus:()=>({})});
  assert.equal(quote.total,139800);assert.equal(quote.items[0].unitPrice,69900);
});

test('overview counts come from full database aggregates and stay numeric above 100',async()=>{
  let handler,result;const guard=()=>{};
  vm.runInNewContext(line("app.get('/api/admin/overview'"),{app:{get(path,auth,fn){assert.equal(auth,guard);handler=fn}},requireAdmin:guard,PAID_STATUSES:['paid','captured','demo_paid'],query:async(sql,values)=>{
    assert.doesNotMatch(sql,/LIMIT|JOIN order_items/);assert.match(sql,/count\(\*\)::int FROM users/);assert.match(sql,/o.order_status<>'cancelled' AND o.payment_status=ANY\(\$1\)/);assert.equal(values[0][0],'paid');return {rows:[{customers:'213',orders:'148',pending_reviews:'17'}]};
  }});
  await handler({}, {json:value=>{result=value}},error=>{throw error});assert.equal(result.customers,213);assert.equal(result.orders,148);assert.equal(result.pendingReviews,17);assert.ok(Date.parse(result.updatedAt));
});

test('Studio saves the exact scrolling-banner text using the authenticated settings route',async()=>{
  let handler,response,stored;const guard=()=>{},text='GOOD THREADS ✦ CAMPUS CULTURE ✦ CAMPUS ANNOUNCEMENT';
  vm.runInNewContext(line("app.patch('/api/admin/settings'"),{app:{patch(path,auth,fn){assert.equal(auth,guard);handler=fn}},requireAdmin:guard,process:{env:{}},settings:async()=>({marqueeText:stored}),query:async(sql,values)=>{if(sql.startsWith('INSERT INTO settings')){assert.equal(values[0],'marqueeText');stored=values[1]}return {rows:[]}}});
  await handler({body:{marqueeText:text}},{json:value=>{response=value}},error=>{throw error});assert.equal(response.settings.marqueeText,text);
});

test('all offered font binaries are bundled, and catalogue no longer divides products into drops',()=>{
  for(const name of ['Allison','StoryScript','EricaOne','Kavoon','JimNightshade']){
    const binary=fs.readFileSync(new URL('../public/assets/fonts/'+name+'-Regular.ttf',import.meta.url));assert.equal(binary.readUInt32BE(0),0x00010000);assert.ok(binary.length>20000);
  }
  const catalog=client.slice(client.indexOf('function Catalog('),client.indexOf('function Storefront('));
  assert.doesNotMatch(catalog,/filter\(.*isWinterProduct/);assert.match(catalog,/items.map\(\(product,index\)=>/);
  assert.doesNotMatch(client,/DROP 0[12]|Drop 0[12]|<WinterCollection/);
  assert.match(client,/href="\/#catalog"/);assert.match(client,/id="winter-collection"/);
});
