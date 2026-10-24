import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const server=fs.readFileSync(new URL('../server.mjs',import.meta.url),'utf8');
const client=fs.readFileSync(new URL('../src/main.jsx',import.meta.url),'utf8');
const sourceRoute=prefix=>server.split('\n').find(line=>line.startsWith(prefix));
const normalize=value=>JSON.parse(JSON.stringify(value));
const helper=client.slice(client.indexOf('function orderCustomizationLines('),client.indexOf('function StudioOrders('));
const lines=vm.runInNewContext(helper+';orderCustomizationLines');
const customization={text:'Tanish\nIIT Delhi\nClass of 2026',placement:'Middle back',style:'Allison',color:'White'};

test('customization line numbering preserves blank lines, spaces and Windows newlines',()=>{
  assert.deepEqual(normalize(lines({customization})),['Tanish','IIT Delhi','Class of 2026']);
  assert.deepEqual(normalize(lines({customization:{text:'  A  \r\n\r\nB'}})),['  A  ','','B']);
  assert.deepEqual(normalize(lines({customization:null})),[]);
});

test('authenticated fulfilment response includes order snapshots in both delivery lists',async()=>{
  const customized={id:'item-a',name:'Sweatshirt',quantity:1,customized:true,customization};
  const plain={id:'item-b',name:'Sweatshirt',quantity:1,customized:false,customization:null};
  const rows=['unfulfilled','delivered'].map((status,i)=>({order_id:'order-'+i,order_no:'TEST-'+i,total:'99900',payment_status:'paid',fulfilment_status:status,items:[customized,plain]}));
  let handler,payload;const guard=()=>{};
  vm.runInNewContext(sourceRoute("app.get('/api/admin/orders/fulfilment'"),{
    app:{get(path,auth,fn){assert.equal(auth,guard);handler=fn}},requireAdmin:guard,PAID_STATUSES:['paid','captured'],
    query:async(sql,values)=>{
      assert.match(sql,/LEFT JOIN order_item_customizations oc ON oc.order_item_id=i.id/);
      assert.match(sql,/'customized',oc.id IS NOT NULL/);
      assert.match(sql,/'text',oc.custom_text,'placement',oc.placement,'style',oc.style,'color',oc.text_color/);
      assert.doesNotMatch(sql,/JOIN products/); // Historical customization must survive catalogue edits.
      assert.deepEqual(normalize(values),[['paid','captured']]);return {rows};
    }
  });
  await handler({}, {json(value){payload=value}},error=>{throw error});
  for(const group of ['pending','delivered']){
    assert.equal(payload[group].length,1);
    assert.equal(payload[group][0].items[0].customization.text,customization.text);
    assert.equal(payload[group][0].items[1].customized,false);
    assert.equal(payload[group][0].items[1].customization,null);
  }
});

test('both CSV exports retain full customization and separate lines, font, ink and placement',async()=>{
  const start=client.indexOf('  const download=(orders,withDelivered,filename)=>',client.indexOf('function StudioOrders('));
  const exportSource=client.slice(start,client.indexOf('  // One row per line item',start));
  let blob,clicked=false,link={click(){clicked=true},remove(){}};
  const download=vm.runInNewContext(helper+exportSource+';download',{
    Blob,URL:{createObjectURL(value){blob=value;return 'blob:test'},revokeObjectURL(){}},
    document:{createElement(){return link},body:{appendChild(){}}},day:value=>value
  });
  const order={orderNo:'TEST-1',total:99900,orderedAt:'2026-10-24',deliveredAt:'2026-10-25',paymentStatus:'paid',items:[{name:'Sweatshirt',color:'Black',size:'M',quantity:1,customized:true,customization:{...customization,text:'A, B\n"IIT Delhi"\nClass of 2026'}},{name:'Plain',quantity:1,customized:false,customization:null}]};
  for(const delivered of [false,true]){
    download([order],delivered,'orders.csv');
    const csv=await blob.text();assert.ok(clicked);assert.equal(link.download,'orders.csv');
    assert.match(csv,/Customized,Customization text,Line 1,Line 2,Line 3,Placement,Font,Ink colour/);
    assert.ok(csv.includes('Yes,"A, B\n""IIT Delhi""\nClass of 2026","A, B","""IIT Delhi""",Class of 2026,Middle back,Allison,White'));
    assert.match(csv,/Plain,,,1,No,/);
    assert.equal(csv.includes('Delivered on'),delivered);
    assert.deepEqual(Array.from(new Uint8Array(await blob.arrayBuffer()).slice(0,3)),[239,187,191]);
  }
});

test('colour removal and restoration retain inventory and order history, with admin protection',async()=>{
  let handler;const guard=()=>{};
  let row={id:'black',product_id:'sweatshirt',name:'Black',slug:'black',swatch_hex:'#17171d',card_color:'#163ea8',active:true,show_in_catalog:true,sort_order:0};
  const calls=[];
  vm.runInNewContext(sourceRoute("app.patch('/api/admin/colorways/:id'"),{
    app:{patch(path,auth,fn){assert.equal(auth,guard);handler=fn}},requireAdmin:guard,slugify:value=>value,
    query:async(sql,values)=>{
      calls.push(sql);assert.doesNotMatch(sql,/DELETE|order_items|stock_on_hand|reserved_stock/);
      if(sql.startsWith('SELECT'))return {rows:values[0]===row.id?[row]:[]};
      if(sql.startsWith('UPDATE product_colorways')){
        assert.equal(values[7],row.id);row={...row,active:values[4],show_in_catalog:values[5]};return {rows:[row]};
      }
      assert.match(sql,/UPDATE product_variants SET color=\$1,updated_at=now\(\) WHERE colorway_id=\$2/);
      assert.deepEqual(normalize(values),['Black','black']);return {rows:[]};
    }
  });
  for(const active of [false,true]){
    let payload;await handler({params:{id:'black'},body:{active,showInCatalog:active}},{json(value){payload=value}},error=>{throw error});
    assert.equal(payload.colorway.active,active);assert.equal(payload.colorway.show_in_catalog,active);
  }
  let code;await handler({params:{id:'missing'},body:{active:false}},{status(value){code=value;return this},json(){}},error=>{throw error});assert.equal(code,404);
});

test('public variant queries and checkout exclude removed colours even on direct product links',()=>{
  for(const prefix of ['const productSelect=','const catalogSelect='])assert.match(sourceRoute(prefix),/v.active AND \(v.colorway_id IS NULL OR EXISTS\(SELECT 1 FROM product_colorways vc WHERE vc.id=v.colorway_id AND vc.active\)\)/);
  assert.match(sourceRoute('async function calculateQuote('),/product_colorways.*active/);
});
