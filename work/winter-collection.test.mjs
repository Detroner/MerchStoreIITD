import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source=fs.readFileSync(new URL('../server.mjs',import.meta.url),'utf8');
const quoteSource=source.split('\n').find(line=>line.startsWith('async function calculateQuote('));
const sweatshirt={id:'sweatshirt-m',product_id:'sweatshirt',slug:'winter-sweatshirt',name:'Sweatshirt',size:'M',color:'Black',sku:'IITD-WINTER-SWEAT-BLK-M',base_price:89900,stock_on_hand:2,reserved_stock:0,customizable:true,enabled:true,max_characters:16,allowed_pattern:'^[A-Za-z0-9 ._-]+$',placements:['Back'],styles:['Allison'],text_colors:['White'],surcharge:0};
const calculate=(items,variant=sweatshirt)=>vm.runInNewContext(quoteSource+';calculateQuote(items)',{items,query:async()=>({rows:[variant]}),paymentStatus:()=>({provider:'test'})});

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
