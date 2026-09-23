import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
import {CouponError,couponInput,couponDiscount,quoteCoupon,recordCoupon,registerCouponRoutes} from '../lib/coupons.mjs';

const coupon={id:'11111111-1111-1111-1111-111111111111',code:'DROP20',type:'percentage',value:20,min_order:100000,max_discount:15000,active:true,used_count:0,usage_limit:0,per_customer_limit:0};
test('percentage is capped and minimum spend is inclusive',()=>{
  assert.equal(couponDiscount(coupon,100000).discount,15000);
  assert.throws(()=>couponDiscount(coupon,99999),/Minimum purchase/);
  assert.equal(couponDiscount({...coupon,max_discount:null},100000).discount,20000);
});
test('percentage rounds down to whole paise and never exceeds the bill',()=>{
  assert.equal(couponDiscount({...coupon,min_order:0,value:17,max_discount:null},999).discount,169);
  assert.equal(couponDiscount({...coupon,type:'fixed',value:999999,min_order:0,max_discount:null},100).discount,100);
  assert.equal(couponDiscount({...coupon,value:100,max_discount:null},100000).discount,100000);
});
test('schedule starts inclusively and expires exclusively in an explicit timezone',()=>{
  const scheduled={...coupon,starts_at:'2026-09-21T10:00:00+05:30',ends_at:'2026-09-21T11:00:00+05:30'};
  const start=Date.parse(scheduled.starts_at),end=Date.parse(scheduled.ends_at);
  assert.throws(()=>couponDiscount(scheduled,100000,0,{now:start-1}),/not active yet/);
  assert.equal(couponDiscount(scheduled,100000,0,{now:start}).discount,15000);
  assert.equal(couponDiscount(scheduled,100000,0,{now:end-1}).discount,15000);
  assert.throws(()=>couponDiscount(scheduled,100000,0,{now:end}),/expired/);
});
test('paused, removed, missing and exhausted codes are rejected',()=>{
  for(const row of [null,{...coupon,active:false},{...coupon,deleted_at:new Date()}])assert.throws(()=>couponDiscount(row,100000),/not active/);
  assert.throws(()=>couponDiscount({...coupon,usage_limit:1,used_count:1},100000),/redemption limit/);
  assert.throws(()=>couponDiscount({...coupon,per_customer_limit:1},100000,0,{customerUses:1}),/coupon limit/);
});
test('coupon input validates money, percent and date ranges',()=>{
  assert.equal(couponInput({code:' drop20 '}).code,'DROP20');
  assert.equal(couponInput({code:'TEST',max_discount:''}).max_discount,null);
  assert.equal(couponInput({code:'TEST',starts_at:new Date('2026-01-01T00:00:00Z')}).starts_at,'2026-01-01T00:00:00.000Z');
  for(const fields of [{value:101},{value:0},{value:1.5},{min_order:-1},{max_discount:0},{max_discount:1.1},{starts_at:'2026-01-01T10:00'},{starts_at:'2026-01-02T00:00:00Z',ends_at:'2026-01-01T00:00:00Z'},{active:'false'}])assert.throws(()=>couponInput({code:'TEST',...fields}),CouponError);
});
test('normalization, customer limits and row locking are shared between quote and checkout',async()=>{
  const calls=[];
  const db=async(sql,args)=>{calls.push({sql,args});return {rows:sql.includes('count(*)')?[{count:1}]:[{...coupon,per_customer_limit:1}]}};
  await assert.rejects(quoteCoupon(db,' drop20 ','user',100000,0,{lock:true}),/coupon limit/);
  assert.equal(calls[0].args[0],'DROP20');
  assert.match(calls[0].sql,/FOR UPDATE$/);
  assert.deepEqual(await quoteCoupon(db,'','user',100000,0),{discount:0,shipping:0,couponId:null,couponCode:null});
});
test('admin routes create, edit, pause and remove without deleting history',async()=>{
  const routes=new Map(),guard=()=>{},app=Object.fromEntries(['post','patch','delete'].map(method=>[method,(path,auth,handler)=>{assert.equal(auth,guard);routes.set(method+' '+path,handler)}]));
  let row;
  const keys=['code','type','value','min_order','max_discount','starts_at','ends_at','usage_limit','per_customer_limit','active'];
  const query=async(sql,values)=>{
    if(sql.startsWith('INSERT')){row={...Object.fromEntries(keys.map((key,i)=>[key,values[i]])),id:coupon.id,used_count:0};return {rows:[row]}}
    if(sql.startsWith('SELECT'))return {rows:row&&!row.deleted_at?[row]:[]};
    if(sql.includes('deleted_at=now()')){row={...row,active:false,deleted_at:new Date()};return {rows:[{id:row.id}]}}
    row={...row,...Object.fromEntries(keys.map((key,i)=>[key,values[i]]))};return {rows:[row]};
  };
  registerCouponRoutes(app,guard,query);
  const call=async(method,body)=>{let result,error;const res={status(){return this},json(value){result=value}};await routes.get(method+' /api/admin/coupons'+(method==='post'?'':'/:id'))({body,params:{id:coupon.id}},res,e=>{error=e});if(error)throw error;return result};
  await call('post',{code:'DROP20',value:20,max_discount:15000,min_order:100000});
  assert.equal(row.max_discount,15000);
  await call('patch',{starts_at:'2026-10-01T10:00:00+05:30',ends_at:'2026-10-01T11:00:00+05:30'});
  assert.equal(row.starts_at,'2026-10-01T04:30:00.000Z');
  await call('patch',{active:false});assert.equal(row.active,false);
  await call('delete',{});assert.ok(row.deleted_at);
  await assert.rejects(call('patch',{active:true}),/not found/);
});

const source=fs.readFileSync(new URL('../server.mjs',import.meta.url),'utf8');
function paymentHarness(row=coupon){
  const calls=[],provider=[],orders=[],attempts=[];
  const query=async(sql,values=[])=>{
    calls.push({sql,values});
    if(sql.includes('FROM product_variants v JOIN products'))return {rows:[{id:'variant',product_id:'product',name:'Tee',slug:'tee',base_price:'100000',stock_on_hand:10,reserved_stock:0}]};
    if(sql.includes('FROM addresses'))return {rows:[{id:'address',recipient_name:'Customer',hostel_id:'hostel'}]};
    if(sql.startsWith('SELECT * FROM coupons'))return {rows:row?[row]:[]};
    if(sql.includes('count(*)'))return {rows:[{count:0}]};
    if(sql.startsWith('INSERT INTO orders')){orders.push(values);return {rows:[]}}
    if(sql.startsWith('INSERT INTO order_items'))return {rows:[{id:'item'}]};
    if(sql.startsWith('INSERT INTO payment_attempts')){attempts.push(values);return {rows:[]}}
    return {rows:[]};
  };
  const client={query,release(){}};
  let handler;
  const context={crypto,randomToken:()=>crypto.randomUUID().slice(0,6),query,pool:{connect:async()=>client},CouponError,quoteCoupon,recordCoupon,requireCustomer:()=>{},paymentStatus:()=>({live:true}),razorpayConfigured:()=>true,razorpayMode:()=> 'test',process:{env:{RAZORPAY_KEY_ID:'test_key'}},razorpayRequest:async(path,body)=>{provider.push({path,body});return {id:'order_provider'}},app:{post(path,middleware,callback){handler=callback}}};
  const helpers=['addressSnapshot','createPendingRazorpayOrder','applyQuoteTotal','calculateQuote'];
  const helperSource=helpers.map(name=>source.split('\n').find(line=>line.startsWith('function '+name+'(')||line.startsWith('async function '+name+'('))).join('\n');
  const dbQueryLine=source.split('\n').find(line=>line.startsWith('const dbQuery='));
  const route=source.slice(source.indexOf("app.post('/api/checkout/razorpay/order'"),source.indexOf("app.post('/api/checkout/razorpay/verify'"));
  vm.runInNewContext(dbQueryLine+'\n'+helperSource+'\n'+route,context);
  return {calls,provider,orders,attempts,async run(overrides={}){
    let result,error;const res={status(){return this},json(value){result=value}};
    await handler({body:{items:[{variantId:'variant',qty:2}],couponCode:'DROP20',addressId:'address',total:1,amount:1,discount:199999,...overrides},customer:{user_id:'customer'}},res,e=>{error=e});
    return {result,error};
  }};
}
test('Razorpay receives only the authoritative capped discount and server total',async()=>{
  const h=paymentHarness(),{result,error}=await h.run();
  assert.equal(error,undefined);
  assert.equal(result.quote.subtotal,200000);
  assert.equal(result.quote.discount,15000);
  assert.equal(result.payment.amount,185000);
  assert.equal(h.provider[0].body.amount,185000);
  assert.equal(h.orders[0][10],185000);
  assert.equal(h.orders[0][7],15000);
  assert.equal(h.attempts[0][2],185000);
  assert.ok(h.calls.findIndex(x=>x.sql.startsWith('INSERT INTO orders'))<h.calls.findIndex(x=>x.sql.startsWith('INSERT INTO coupon_redemptions')));
});
test('invalid and expired coupons never reach Razorpay',async()=>{
  for(const row of [null,{...coupon,active:false},{...coupon,ends_at:'2000-01-01T00:00:00Z'},{...coupon,min_order:300000},{...coupon,deleted_at:new Date()}]){
    const h=paymentHarness(row),{error}=await h.run();
    assert.ok(error instanceof CouponError);assert.equal(h.provider.length,0);assert.equal(h.orders.length,0);assert.ok(h.calls.some(x=>x.sql==='ROLLBACK'));
  }
});
test('minimum Razorpay amount is checked after all deductions',async()=>{
  const h=paymentHarness({...coupon,value:100,max_discount:null}),{error}=await h.run();
  assert.match(error.message,/at least INR 1/);assert.equal(h.provider.length,0);assert.equal(h.attempts.length,0);
});
test('no coupon uses the undiscounted server total, ignoring client totals',async()=>{
  const h=paymentHarness(),{result,error}=await h.run({couponCode:''});
  assert.equal(error,undefined);assert.equal(result.payment.amount,200000);assert.equal(h.provider[0].body.amount,200000);
});
