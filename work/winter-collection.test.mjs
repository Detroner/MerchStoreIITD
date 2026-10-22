import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import {CouponError} from '../lib/coupons.mjs';

const source=fs.readFileSync(new URL('../server.mjs',import.meta.url),'utf8');
const quoteSource=source.split('\n').find(line=>line.startsWith('async function calculateQuote('));
const sweatshirt={id:'sweatshirt-m',product_id:'sweatshirt',slug:'winter-sweatshirt',name:'Sweatshirt',size:'M',color:'Black',sku:'IITD-WINTER-SWEAT-BLK-M',base_price:89900,stock_on_hand:2,reserved_stock:0,customizable:true,enabled:true,max_characters:16,allowed_pattern:'^[A-Za-z0-9 ._-]+$',placements:['Back'],styles:['Allison'],text_colors:['White'],surcharge:0};
const calculate=(items,variant=sweatshirt)=>vm.runInNewContext(quoteSource+';calculateQuote(items)',{items,CouponError,query:async()=>({rows:[variant]}),paymentStatus:()=>({provider:'test'})});

test('Sweatshirt quote keeps the name, Allison style, Back placement and ₹899 price',async()=>{
  const quote=await calculate([{variantId:sweatshirt.id,qty:1,customization:{text:'  Tanish  ',placement:'Back',style:'Allison',color:'White'}}]);
  assert.equal(quote.total,89900);
  assert.equal(quote.customizationTotal,0);
  assert.deepEqual(JSON.parse(JSON.stringify(quote.items[0].customization)),{text:'Tanish',placement:'Back',style:'Allison',color:'White'});
});

test('unconfirmed sweatshirt inventory cannot be purchased',async()=>{
  await assert.rejects(calculate([{variantId:sweatshirt.id,qty:1}],{...sweatshirt,stock_on_hand:0}),/unavailable/);
});

test('invalid names and non-back placements are rejected by the quote',async()=>{
  for(const customization of [{text:'A'.repeat(17),placement:'Back'},{text:'<script>',placement:'Back'},{text:'Tanish',placement:'Front'}]){
    await assert.rejects(calculate([{variantId:sweatshirt.id,qty:1,customization}]),/not valid|available customization placement/);
  }
  const quote=await calculate([{variantId:sweatshirt.id,qty:2,customization:{text:'A'.repeat(16),placement:'Back'}}]);
  assert.equal(quote.total,179800);
  assert.equal(quote.items[0].customization.style,'Allison');
});

test('three customization lines survive quoting, while four lines and long lines fail',async()=>{
  const multiline={...sweatshirt,max_characters:50,allowed_pattern:'^[A-Za-z0-9 ._-]{1,16}(?:\\n[A-Za-z0-9 ._-]{1,16}){0,2}$'};
  const text='Tanish\nIIT Delhi\nClass of 2026';
  // The persisted pattern contains a newline escape, not a literal backslash in customer text.
  multiline.allowed_pattern='^[A-Za-z0-9 ._-]{1,16}(?:\n[A-Za-z0-9 ._-]{1,16}){0,2}$';
  const quote=await calculate([{variantId:sweatshirt.id,qty:1,customization:{text,placement:'Back'}}],multiline);
  assert.equal(quote.items[0].customization.text,text);
  assert.equal(quote.total,89900);
  for(const value of ['A\nB\nC\nD','A'.repeat(17)+'\nB','A\n<script>']){
    await assert.rejects(calculate([{variantId:sweatshirt.id,qty:1,customization:{text:value,placement:'Back'}}],multiline),/not valid/);
  }
});

test('product galleries include shared hoodie photos and only the chosen sweatshirt colour',()=>{
  const client=fs.readFileSync(new URL('../src/main.jsx',import.meta.url),'utf8');
  const start=client.indexOf('function productGallery('),end=client.indexOf('function SweatshirtPreview',start);
  const gallery=vm.runInNewContext(client.slice(start,end)+';productGallery');
  const shared=[{id:'front',isThumbnail:true,colorwayId:null},{id:'back',colorwayId:null}];
  assert.deepEqual(Array.from(gallery({media:shared},{id:'default',media:[]}),x=>x.id),['front','back']);
  const black={id:'black'},violet={id:'violet'};
  const media=[{id:'black-back',colorwayId:'black'},{id:'violet-back',colorwayId:'violet'},{id:'violet-front',colorwayId:'violet',isThumbnail:true}];
  assert.deepEqual(Array.from(gallery({media},violet),x=>x.id),['violet-front','violet-back']);
  assert.deepEqual(Array.from(gallery({media},black),x=>x.id),['black-back']);
  assert.equal(gallery({media}, {...violet,media:[media[1],media[2]]}).length,2);
});

test('checkout rejects fractional, zero and excessive quantities',async()=>{
  for(const qty of [0,-1,1.5,11,'not-a-number'])await assert.rejects(calculate([{variantId:sweatshirt.id,qty}]),/whole quantity/);
});

test('customized lines sharing one variant cannot exceed its combined stock',async()=>{
  const line=text=>({variantId:sweatshirt.id,qty:2,customization:{text,placement:'Back'}});
  await assert.rejects(calculate([line('One'),line('Two')]),/unavailable in that quantity/);
  const quote=await calculate([line('One'),line('Two')],{...sweatshirt,stock_on_hand:4});
  assert.equal(quote.total,359600);
});

test('checkout rejects customization styles and ink colours that the product does not offer',async()=>{
  for(const extra of [{style:'Unknown font'},{color:'Red'}])await assert.rejects(calculate([{variantId:sweatshirt.id,qty:1,customization:{text:'Tanish',placement:'Back',...extra}}]),/available customization style/);
});

test('saved bags refresh renamed hoodie colours and discard retired options',()=>{
  const client=fs.readFileSync(new URL('../src/main.jsx',import.meta.url),'utf8');
  const helper=client.slice(client.indexOf('function reconcileCart('),client.indexOf('function useCart('));
  const reconcile=vm.runInNewContext(helper+';reconcileCart');
  const cart=[{productId:'hood',variantId:'black-m',color:'Default',qty:2,customization:null},{productId:'hood',variantId:'test-m',qty:1}];
  const catalog=[{id:'hood',name:'Chill Hai?',image:'/black.png',colorways:[{id:'black',image:'/black.png'}],variants:[{id:'black-m',colorwayId:'black',color:'Black',price:99900,active:true},{id:'test-m',colorwayId:'test',color:'test',price:99900,active:false}]}];
  const result=reconcile(cart,catalog);
  assert.equal(result.length,1);assert.equal(result[0].color,'Black');assert.equal(result[0].qty,2);assert.equal(result[0].price,99900);
});
