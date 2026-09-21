export class CouponError extends Error {
  constructor(message,status=400){super(message);this.status=status}
}
const integer=(value,label,min=0,max=Number.MAX_SAFE_INTEGER)=>{
  if(value===null||value===''||typeof value==='boolean'||!Number.isSafeInteger(Number(value))||Number(value)<min||Number(value)>max)throw new CouponError(label+' is invalid.');
  return Number(value);
};
const timestamp=(value,label)=>{
  if(value instanceof Date)value=value.toISOString();
  if(value===null||value==='')return null;
  if(typeof value!=='string'||!/(Z|[+-]\d{2}:\d{2})$/i.test(value)||!Number.isFinite(Date.parse(value)))throw new CouponError(label+' must include a valid date, time and timezone.');
  return new Date(value).toISOString();
};
export function couponInput(body,current={}){
  if(!body||typeof body!=='object'||Array.isArray(body))throw new CouponError('Coupon fields must be an object.');
  const data={code:'',type:'percentage',value:10,min_order:0,max_discount:null,starts_at:null,ends_at:null,usage_limit:0,per_customer_limit:0,active:true,...current,...body};
  const code=String(data.code).trim().toUpperCase();
  if(!/^[A-Z0-9_-]{2,40}$/.test(code))throw new CouponError('Use 2-40 letters, numbers, hyphens or underscores for the code.');
  if(!['percentage','fixed','free_shipping'].includes(data.type))throw new CouponError('Choose a valid discount type.');
  const value=data.type==='free_shipping'?0:integer(data.value,'Discount',1,data.type==='percentage'?100:100000000);
  const min_order=integer(data.min_order,'Minimum purchase',0,100000000);
  const max_discount=data.max_discount===null||data.max_discount===''?null:integer(data.max_discount,'Maximum discount',1,100000000);
  const starts_at=timestamp(data.starts_at,'Start time'),ends_at=timestamp(data.ends_at,'End time');
  if(starts_at&&ends_at&&Date.parse(ends_at)<=Date.parse(starts_at))throw new CouponError('End time must be after start time.');
  if(typeof data.active!=='boolean')throw new CouponError('Active must be true or false.');
  return {code,type:data.type,value,min_order,max_discount,starts_at,ends_at,usage_limit:integer(data.usage_limit,'Usage limit',0,2147483647),per_customer_limit:integer(data.per_customer_limit,'Customer limit',0,2147483647),active:data.active};
}
export function couponDiscount(row,subtotal,shipping=0,{now=Date.now(),customerUses=0}={}){
  if(!row||!row.active||row.deleted_at)throw new CouponError('This coupon is not active.');
  if(row.starts_at&&Date.parse(row.starts_at)>now)throw new CouponError('This coupon is not active yet.');
  if(row.ends_at&&Date.parse(row.ends_at)<=now)throw new CouponError('This coupon has expired.');
  if(subtotal<Number(row.min_order))throw new CouponError('Minimum purchase for this coupon is INR '+(Number(row.min_order)/100).toFixed(2)+'.');
  if(Number(row.usage_limit)>0&&Number(row.used_count)>=Number(row.usage_limit))throw new CouponError('This coupon has reached its redemption limit.');
  if(Number(row.per_customer_limit)>0&&customerUses>=Number(row.per_customer_limit))throw new CouponError('You have reached this coupon limit.');
  let discount=row.type==='percentage'?Math.floor(subtotal*Number(row.value)/100):row.type==='fixed'?Number(row.value):0;
  if(row.max_discount!==null&&row.max_discount!==undefined)discount=Math.min(discount,Number(row.max_discount));
  discount=Math.max(0,Math.min(subtotal,discount));
  const shippingDiscount=row.type==='free_shipping'?Math.min(shipping,row.max_discount==null?shipping:Number(row.max_discount)):0;
  return {discount,shipping:shipping-shippingDiscount,couponId:row.id,couponCode:row.code};
}
export async function quoteCoupon(db,code,userId,subtotal,shipping,{lock=false}={}){
  const normalized=String(code||'').trim().toUpperCase();
  if(!normalized)return {discount:0,shipping,couponId:null,couponCode:null};
  const query=(sql,values)=>typeof db==='function'?db(sql,values):db.query(sql,values);
  const row=(await query('SELECT * FROM coupons WHERE code=$1'+(lock?' FOR UPDATE':''),[normalized])).rows[0];
  let customerUses=0;
  if(row&&userId&&Number(row.per_customer_limit)>0)customerUses=Number((await query('SELECT count(*)::int count FROM coupon_redemptions WHERE coupon_id=$1 AND user_id=$2',[row.id,userId])).rows[0].count);
  return couponDiscount(row,subtotal,shipping,{customerUses});
}
export async function recordCoupon(client,coupon,userId,orderId){
  if(!coupon.couponId)return;
  await client.query('UPDATE coupons SET used_count=used_count+1 WHERE id=$1',[coupon.couponId]);
  await client.query('INSERT INTO coupon_redemptions(coupon_id,user_id,order_id) VALUES($1,$2,$3)',[coupon.couponId,userId,orderId]);
}
export function registerCouponRoutes(app,requireAdmin,query){
  const keys=['code','type','value','min_order','max_discount','starts_at','ends_at','usage_limit','per_customer_limit','active'];
  const checkId=id=>{if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))throw new CouponError('Coupon not found.',404)};
  const fail=(error,res,next)=>error.code==='23505'?res.status(409).json({error:'This coupon code already exists, including removed codes. Use a new code.'}):next(error);
  app.post('/api/admin/coupons',requireAdmin,async(req,res,next)=>{
    try{
      const data=couponInput(req.body);
      const result=await query('INSERT INTO coupons('+keys.join(',')+') VALUES('+keys.map((_,i)=>'$'+(i+1)).join(',')+') RETURNING *',keys.map(key=>data[key]));
      res.status(201).json({coupon:result.rows[0]});
    }catch(error){fail(error,res,next)}
  });
  app.patch('/api/admin/coupons/:id',requireAdmin,async(req,res,next)=>{
    try{
      checkId(req.params.id);
      const current=(await query('SELECT * FROM coupons WHERE id=$1 AND deleted_at IS NULL',[req.params.id])).rows[0];
      if(!current)throw new CouponError('Coupon not found.',404);
      const data=couponInput(req.body,current);
      const result=await query('UPDATE coupons SET '+keys.map((key,i)=>key+'=$'+(i+1)).join(',')+' WHERE id=$11 AND deleted_at IS NULL RETURNING *',[...keys.map(key=>data[key]),req.params.id]);
      if(!result.rows[0])throw new CouponError('Coupon not found.',404);
      res.json({coupon:result.rows[0]});
    }catch(error){fail(error,res,next)}
  });
  app.delete('/api/admin/coupons/:id',requireAdmin,async(req,res,next)=>{
    try{
      checkId(req.params.id);
      const result=await query('UPDATE coupons SET active=false,deleted_at=now() WHERE id=$1 AND deleted_at IS NULL RETURNING id',[req.params.id]);
      if(!result.rows[0])throw new CouponError('Coupon not found.',404);
      res.json({ok:true});
    }catch(error){next(error)}
  });
}
