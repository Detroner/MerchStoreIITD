import json, secrets, hmac, hashlib, mimetypes, re
import os
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

ROOT=Path(__file__).resolve().parents[1]
PREVIEW_ADMIN_EMAIL=os.environ.get('ADMIN_PREVIEW_EMAIL','preview-admin@example.invalid')
PREVIEW_ADMIN_PASSWORD=os.environ.get('ADMIN_PREVIEW_PASSWORD','')
SETTINGS={'brand':'THE IIT DELHI DROP','eyebrow':'CAMPUS GOODS / EST. 2026','headline':'BIG BRAINS.\nBIGGER FITS.','subhead':'Campus-made merchandise for the curious, sleep-deprived and world-changing.','announcement':'FREE SHIPPING ABOVE ₹1,499 ✦ FRESH DROP IS LIVE ✦ MADE FOR CAMPUS','primary':'#ed3b24','secondary':'#163ea8','accent':'#f5ce3e','background':'#f4eddf','ink':'#17171d','radius':'20','motion':'1','motionIntensity':'1','motionPreset':'campus-pop','heroImage':'/assets/merch-hero.png','heroButton':'EXPLORE THE DROP','storyTitle':'Made of red brick & big ideas.','storyBody':'Designed for the people who turn impossible questions into everyday conversations.','footerNote':'Designed on campus. Worn everywhere.'}
CATEGORIES=[{'id':'cat-apparel','name':'Apparel','slug':'apparel'},{'id':'cat-accessories','name':'Accessories','slug':'accessories'},{'id':'cat-home','name':'Home','slug':'home'},{'id':'cat-stationery','name':'Stationery','slug':'stationery'}]
TYPES=[{'id':'type-tee','name':'T-shirt','slug':'t-shirt'},{'id':'type-hoodie','name':'Hoodie','slug':'hoodie'},{'id':'type-track','name':'Trackpants','slug':'trackpants'},{'id':'type-cap','name':'Cap','slug':'cap'},{'id':'type-bag','name':'Bag','slug':'bag'},{'id':'type-mug','name':'Mug','slug':'mug'},{'id':'type-stationery','name':'Stationery','slug':'stationery'}]
HOSTELS=[{'id':f'hostel-{i+1}','name':name} for i,name in enumerate(['Aravali','Girnar','Himadri','Jwalamukhi','Kailash','Karakoram','Kumaon','Nilgiri','Satpura','Shivalik','Udaigiri','Vindhyachal','Zanskar'])]

def make_variants(pid,apparel,price):
 sizes=['S','M','L','XL'] if apparel else ['One Size']; colors=['Navy','Cream'] if apparel else ['Campus Edition'];out=[]
 for i,(size,color) in enumerate((x,y) for x in sizes for y in colors):out.append({'id':f'variant-{pid}-{i+1}','sku':f'IITD-{pid.upper()}-{i+1:02d}','size':size,'color':color,'price':price,'stock':max(2,9-i),'active':True})
 return out
def custom(enabled=True): return {'enabled':enabled,'label':'Name or nickname','min':1,'max':16,'placements':['Front chest','Back','Sleeve'],'styles':['Campus Block','Notebook Script'],'colors':['White','Red','Cobalt'],'surcharge':14900,'addedDays':2,'returnPolicy':'Customized items cannot be returned unless defective.'} if enabled else None
PRODUCTS=[]
for seed in [
 ('hood','Core Memory Hoodie','core-memory-hoodie','Apparel','apparel','Hoodie','hoodie',249900,299900,'CAMPUS FAVE','#163ea8','Heavyweight brushed cotton built for late labs and early Delhi winters.',True,4.8,38),
 ('tee','Main Building Tee','main-building-tee','Apparel','apparel','T-shirt','t-shirt',99900,129900,'NEW DROP','#ed3b24','A relaxed everyday tee with a bold architectural graphic.',True,4.6,24),
 ('cap','Red Brick Cap','red-brick-cap','Accessories','accessories','Cap','cap',69900,79900,'LIMITED','#f5ba32','Six-panel cotton cap with an embroidered campus-inspired mark.',False,4.7,16),
 ('mug','All-Nighter Mug','all-nighter-mug','Home','home','Mug','mug',44900,0,'','#22222a','Enamel mug for caffeine, chai and unreasonable deadlines.',True,4.5,11),
 ('tote','Hauz Khas Tote','hauz-khas-tote','Accessories','accessories','Bag','bag',59900,0,'LOW IMPACT','#1b7f61','Roomy canvas tote with reinforced straps and an inside pocket.',True,4.9,9),
 ('sock','Workshop Socks','workshop-socks','Apparel','apparel','T-shirt','t-shirt',34900,0,'ALMOST GONE','#8c4ac9','Cushioned crew socks made for long walks across campus.',False,0,0),
 ('track','Lecture Hall Trackpants','lecture-hall-trackpants','Apparel','apparel','Trackpants','trackpants',159900,189900,'FRESH CUT','#183c9f','Relaxed straight-leg trackpants with deep pockets and a clean campus mark.',True,4.4,7),
 ('note','Drafting Desk Notebook','drafting-desk-notebook','Stationery','stationery','Stationery','stationery',29900,0,'STUDIO PICK','#e66f3d','A lay-flat notebook for sketches, equations and half-formed breakthroughs.',True,4.8,5),
 ('bottle','Hauz Steel Bottle','hauz-steel-bottle','Home','home','Mug','mug',79900,99900,'NEW','#157865','Double-wall steel hydration for the long route from LHC to hostel.',True,4.3,6),
 ('lanyard','Red Brick Lanyard','red-brick-lanyard','Accessories','accessories','Bag','bag',19900,0,'','#a33127','A woven lanyard with a quick-release clip and card sleeve.',False,4.6,8),
 ('jacket','Convocation Jacket','convocation-jacket','Apparel','apparel','Hoodie','hoodie',329900,379900,'ALUMNI EDIT','#26262c','A structured campus jacket for milestones, memories and Delhi evenings.',True,4.9,14),
 ('desk','Studio Desk Mat','studio-desk-mat','Stationery','stationery','Stationery','stationery',89900,109900,'WORK MODE','#1747e5','A generous desk mat for keyboards, drafting tools and ambitious plans.',False,4.5,4)
]:
 pid,name,slug,category,category_slug,ptype,type_slug,price,compare,badge,color,desc,is_custom,rating,count=seed;apparel=category=='Apparel';PRODUCTS.append({'id':pid,'name':name,'slug':slug,'category':category,'categorySlug':category_slug,'type':ptype,'typeSlug':type_slug,'price':price,'compare_price':compare,'badge':badge,'color':color,'description':desc,'image':'/assets/merch-hero.png','featured':pid in ['hood','tee','track','jacket'],'customizable':is_custom,'status':'active','rating':rating,'reviewCount':count,'variants':make_variants(pid,apparel,price),'customization':custom() if is_custom else None})
for product in PRODUCTS:
 names=[]
 for variant in product['variants']:
  if variant['color'] not in names:names.append(variant['color'])
 product['colorways']=[]
 for index,name in enumerate(names):
  cid=f"colorway-{product['id']}-{index+1}";slug=re.sub(r'[^a-z0-9]+','-',name.lower()).strip('-');swatch={'navy':'#16305c','cream':'#eee2c8','black':'#17171d','white':'#f7f4ea'}.get(name.lower(),product['color'])
  product['colorways'].append({'id':cid,'name':name,'slug':slug,'swatch':swatch,'cardColor':product['color'],'active':True,'showInCatalog':True,'sortOrder':index,'image':product['image']})
  for variant in product['variants']:
   if variant['color']==name:variant['colorwayId']=cid
 product.update({'category_id':next((x['id'] for x in CATEGORIES if x['slug']==product['categorySlug']),''),'product_type_id':next((x['id'] for x in TYPES if x['slug']==product['typeSlug']),''),'short_description':product['description'][:120],'sort_order':len(PRODUCTS),'deleted_at':None})
 product['media']=[{'id':f"media-{product['id']}-1",'url':product['image'],'type':'image','mimeType':'image/png','fileSize':None,'poster':None,'alt':product['name'],'sortOrder':0,'colorwayId':None,'active':True}]

REVIEWS=[{'id':'review-1','product_id':'hood','rating':5,'title':'Feels properly premium','body':'The weight is perfect for winter mornings and the fit is relaxed without looking oversized. The embroidery stayed sharp after washing.','status':'approved','full_name':'Ananya S.','submitted_at':'2026-08-07T10:00:00Z'},{'id':'review-2','product_id':'hood','rating':4,'title':'A new late-lab uniform','body':'Warm, comfortable and the pockets are actually useful. I sized up for a roomier fit.','status':'approved','full_name':'Kabir M.','submitted_at':'2026-08-05T10:00:00Z'},{'id':'review-3','product_id':'tee','rating':5,'title':'The graphic lands','body':'Soft fabric and a clean print. Looks even better in person.','status':'pending','full_name':'Rhea A.','submitted_at':'2026-08-09T10:00:00Z'}]
USERS={};SESSIONS={};OTP={};ADMIN_SESSIONS=set();ADDRESSES={}
DEMO_ITEMS=[{'id':'demo-item-1','productId':'hood','name':'Core Memory Hoodie','slug':'core-memory-hoodie','sku':'IITD-HOOD-02','size':'M','color':'Navy','image':'/assets/merch-hero.png','quantity':1,'unitPrice':249900,'deliveredAt':'2026-08-06T12:00:00Z','reviewed':False,'customization':{'text':'TANISH','placement':'Front chest','style':'Campus Block','color':'White'}},{'id':'demo-item-2','productId':'tee','name':'Main Building Tee','slug':'main-building-tee','sku':'IITD-TEE-03','size':'L','color':'Navy','image':'/assets/merch-hero.png','quantity':1,'unitPrice':99900,'deliveredAt':None,'reviewed':False,'customization':None}]
ORDERS=[{'id':'order-1','order_no':'IITD-2048','customer_name':'Demo Customer','total':364700,'order_status':'delivered','fulfilment_status':'delivered','created_at':'2026-08-02T09:40:00Z','items':DEMO_ITEMS}]
COUPONS=[{'id':'coupon-1','code':'CAMPUS10','type':'percentage','value':10,'min_order':99900,'usage_limit':500,'used_count':84,'active':True},{'id':'coupon-2','code':'FREESHIP','type':'free_shipping','value':0,'min_order':49900,'usage_limit':250,'used_count':41,'active':False}]
BATCHES=[]

def get_product(slug): return next((p for p in PRODUCTS if p['slug']==slug),None)
def cookie_value(headers,name):
 for part in headers.get('Cookie','').split(';'):
  if part.strip().startswith(name+'='):return part.strip().split('=',1)[1]
 return None
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def json_out(self,obj,code=200,cookie=None):
  payload=json.dumps(obj,ensure_ascii=False).encode();self.send_response(code);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',len(payload));
  if cookie:self.send_header('Set-Cookie',cookie)
  self.end_headers();self.wfile.write(payload)
 def body(self):
  try:return json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))) or b'{}')
  except:return {}
 def customer(self):return SESSIONS.get(cookie_value(self.headers,'customer_session'))
 def require_customer(self):
  session=self.customer()
  if not session:self.json_out({'error':'Please sign in to continue.'},401);return None
  if self.command in ['POST','PATCH','DELETE'] and self.headers.get('X-CSRF-Token')!=session['csrf']:self.json_out({'error':'Invalid security token.'},403);return None
  return session
 def do_GET(self):
  parsed=urlparse(self.path);path=parsed.path;params={k:v[0] for k,v in parse_qs(parsed.query).items()}
  if path=='/api/store':return self.json_out({'settings':SETTINGS,'categories':CATEGORIES,'productTypes':TYPES,'hostels':HOSTELS,'payment':{'provider':'Razorpay','mode':'demo','live':False,'demoAllowed':True},'sms':{'provider':'demo','configured':False,'demoAllowed':True}})
  if path=='/api/catalog':
   try:
    items=[]
    for product_order,product in enumerate(PRODUCTS):
     if product.get('status')!='active':continue
     for colorway in product.get('colorways',[]):
      if not colorway.get('active',True) or not colorway.get('showInCatalog',True):continue
      card=dict(product);card.update({'catalogItemId':f"{product['id']}:{colorway['id']}",'colorwayId':colorway['id'],'colorwaySlug':colorway['slug'],'colorwayName':colorway['name'],'swatch':colorway['swatch'],'color':colorway['cardColor'],'image':colorway['image'],'variants':[v for v in product['variants'] if v.get('colorwayId')==colorway['id']], '_productOrder':product_order});items.append(card)
    if params.get('category','all')!='all':items=[p for p in items if p['categorySlug']==params['category']]
    if params.get('type','all')!='all':items=[p for p in items if p['typeSlug']==params['type']]
    if params.get('size','all')!='all':items=[p for p in items if any(v['size']==params['size'] and v['stock']>0 for v in p['variants'])]
    if params.get('customizable')=='true':items=[p for p in items if p['customizable']]
    sort=params.get('sort','featured')
    if sort=='newest':items=list(reversed(items))
    elif sort=='price_asc':items.sort(key=lambda p:p['price'])
    elif sort=='price_desc':items.sort(key=lambda p:p['price'],reverse=True)
    elif sort=='rating':items.sort(key=lambda p:p['rating'],reverse=True)
    else:items.sort(key=lambda p:(not p['featured'],p['_productOrder'],p.get('colorwayName','')))
    for item in items:item.pop('_productOrder',None)
    limit=max(1,min(24,int(params.get('limit',12))));offset=max(0,int(params.get('cursor',0)));page=items[offset:offset+limit]
    return self.json_out({'items':page,'nextCursor':str(offset+limit) if offset+limit<len(items) else None})
   except Exception as error:return self.json_out({'error':f'Preview catalogue failed: {error!r}'},500)
  if path.startswith('/api/products/'):
   product=get_product(path.rsplit('/',1)[1])
   if not product or product.get('status')!='active':return self.json_out({'error':'Product not found.'},404)
   return self.json_out({'product':product,'reviews':[r for r in REVIEWS if r['product_id']==product['id'] and r['status']=='approved']})
  if path=='/api/account/session':
   s=self.customer()
   if not s:return self.json_out({'error':'No customer session.'},401)
   return self.json_out({'user':s['user'],'csrf':s['csrf']})
  if path=='/api/account/orders':
   if not self.require_customer():return
   return self.json_out({'orders':ORDERS})
  if path=='/api/account/addresses':
   session=self.require_customer()
   if not session:return
   return self.json_out({'addresses':ADDRESSES.get(session['user']['phone'],[])})
  if path.startswith('/api/admin/orders') or path.startswith('/api/admin/vendor-batches'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   if path=='/api/admin/orders/summary':
    pieces=sum(item['quantity'] for order in ORDERS for item in order['items']);customized=sum(item['quantity'] for order in ORDERS for item in order['items'] if item.get('customization'));return self.json_out({'summary':{'orders':len(ORDERS),'pieces':pieces,'paid_value':sum(o['total'] for o in ORDERS),'new_vendor_pieces':pieces,'pending_vendor_pieces':0,'customized_pieces':customized}})
   if path=='/api/admin/orders/matrix':
    matrix=[]
    for order in ORDERS:
     for item in order['items']:
      row=next((x for x in matrix if x['product_name']==item['name'] and x['color']==item['color'] and x['size']==item['size'] and x['sku']==item['sku']),None)
      if not row:row={'product_name':item['name'],'color':item['color'],'size':item['size'],'sku':item['sku'],'units':0,'orders':0,'customized_units':0,'new_vendor_units':0,'pending_vendor_units':0};matrix.append(row)
      row['units']+=item['quantity'];row['orders']+=1;row['new_vendor_units']+=item['quantity'];row['customized_units']+=item['quantity'] if item.get('customization') else 0
    return self.json_out({'rows':matrix})
   if path=='/api/admin/orders':return self.json_out({'items':ORDERS,'nextCursor':None})
   if path.startswith('/api/admin/orders/'):
    order=next((o for o in ORDERS if o['id']==path.rsplit('/',1)[1]),None)
    if not order:return self.json_out({'error':'Order not found.'},404)
    enriched=dict(order);enriched.update({'payment_status':order.get('payment_status','paid'),'shipping_address':{'city':'New Delhi'},'history':[],'notes':[]});return self.json_out({'order':enriched})
   if path=='/api/admin/vendor-batches':return self.json_out({'batches':BATCHES})
   if path.startswith('/api/admin/vendor-batches/'):
    bid=path.split('/')[4];batch=next((x for x in BATCHES if x['id']==bid),None)
    if not batch:return self.json_out({'error':'Vendor batch not found.'},404)
    lines=['THE IIT DELHI DROP — PRODUCTION UPDATE',f"Batch: {batch['batch_no']}",'',f"NEW: {len(ORDERS)} orders / {batch['units']} pieces"]
    for item in batch['items']:lines.append(f"{item['product_name']} — {item['color']}: {item['size']} {item['quantity']}")
    lines.extend(['',f"CUSTOMIZED: {sum(x['quantity'] for x in batch['items'] if x.get('custom_text'))} pieces",'','PENDING FROM EARLIER BATCHES: 0 pieces','','Please acknowledge quantities and share the expected ready date.']);return self.json_out({'batch':batch,'message':'\n'.join(lines)})
  if path=='/api/admin/data':
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   customers=[{'id':str(i+1),'full_name':u.get('fullName',''),'phone_e164':phone,'affiliation':u.get('affiliation'),'created_at':'2026-08-09T10:00:00Z'} for i,(phone,u) in enumerate(USERS.items())]
   products=[{'id':p['id'],'name':p['name'],'slug':p['slug'],'category_id':p['category_id'],'product_type_id':p['product_type_id'],'short_description':p.get('short_description',''),'description':p['description'],'base_price':p['price'],'compare_price':p['compare_price'],'badge':p['badge'],'card_color':p['color'],'status':p['status'],'featured':p['featured'],'customizable':p['customizable'],'customization':p['customization'],'colorways':p['colorways'],'media':p.get('media',[]),'category':p['category'],'product_type':p['type'],'image':p['image'],'stock':sum(v['stock'] for v in p['variants']),'sort_order':p.get('sort_order',0),'deleted_at':p.get('deleted_at')} for p in PRODUCTS]
   breakdown=[]
   for order in ORDERS:
    for item in order['items']:
     row=next((x for x in breakdown if x['product_name']==item['name'] and x['size']==item['size']),None)
     if row:row['units']+=item['quantity'];row['orders']+=1
     else:breakdown.append({'product_name':item['name'],'color':item['color'],'size':item['size'],'sku':item['sku'],'units':item['quantity'],'orders':1,'customized_units':item['quantity'] if item.get('customization') else 0})
   mode=os.environ.get('RAZORPAY_MODE','demo');configured=mode in ['test','live'] and bool(os.environ.get('RAZORPAY_KEY_ID') and os.environ.get('RAZORPAY_KEY_SECRET'));return self.json_out({'customers':customers,'reviews':REVIEWS,'orders':ORDERS,'products':products,'categories':CATEGORIES,'productTypes':TYPES,'coupons':COUPONS,'orderBreakdown':breakdown,'settings':SETTINGS,'payment':{'provider':'Razorpay','mode':mode,'configured':configured,'live':configured,'keyId':os.environ.get('RAZORPAY_KEY_ID','') if configured else '','webhookConfigured':bool(os.environ.get('RAZORPAY_WEBHOOK_SECRET')),'database':'PostgreSQL'},'sms':{'provider':os.environ.get('SMS_PROVIDER','demo'),'configured':False}})
  if path.startswith('/assets/'):file=ROOT/'public'/path.lstrip('/')
  else:file=ROOT/('index.html' if path in ['/','/studio','/studio/','/cart','/account','/login'] or path.startswith('/products/') else path.lstrip('/'))
  if file.is_file():
   payload=file.read_bytes();self.send_response(200);self.send_header('Content-Type',mimetypes.guess_type(file)[0] or 'application/octet-stream');self.send_header('Content-Length',len(payload));self.end_headers();return self.wfile.write(payload)
  self.send_error(404)
 def do_POST(self):
  path=urlparse(self.path).path
  if path.startswith('/api/admin/products/') and path.endswith('/media/upload'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   pid=path.split('/')[4];product=next((p for p in PRODUCTS if p['id']==pid),None)
   if not product:return self.json_out({'error':'Product not found.'},404)
   mime=self.headers.get('Content-Type','').split(';')[0];allowed={'image/jpeg':'image','image/png':'image','image/webp':'image','video/mp4':'video','video/webm':'video'}
   if mime not in allowed:return self.json_out({'error':'Use JPG, PNG, WebP, MP4 or WebM media.'},415)
   length=int(self.headers.get('Content-Length',0));self.rfile.read(length)
   mid='media-'+secrets.token_hex(6);item={'id':mid,'url':'/assets/merch-hero.png','type':allowed[mime],'mimeType':mime,'fileSize':length,'poster':None,'alt':self.headers.get('X-Media-Alt',product['name']),'sortOrder':len(product.get('media',[])),'colorwayId':self.headers.get('X-Colorway-Id') or None,'active':True};product.setdefault('media',[]).append(item);return self.json_out({'media':item},201)
  body=self.body()
  if path.startswith('/api/admin/vendor-batches'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   if path=='/api/admin/vendor-batches/preview':
    eligible=[]
    for order in ORDERS:
     for item in order['items']:eligible.append({'order_item_id':item['id'],'order_no':order['order_no'],'product_name':item['name'],'sku':item['sku'],'color':item['color'],'size':item['size'],'quantity':item['quantity'],'custom_text':item.get('customization',{}).get('text') if item.get('customization') else None,'placement':item.get('customization',{}).get('placement') if item.get('customization') else None})
    return self.json_out({'eligible':eligible,'excludedNote':'Unpaid, cancelled, refunded, already batched, and unapproved customization items are excluded.'})
   if path=='/api/admin/vendor-batches':
    ids=set(body.get('orderItemIds',[]));items=[]
    for order in ORDERS:
     for item in order['items']:
      if item['id'] in ids:items.append({'order_item_id':item['id'],'order_no':order['order_no'],'product_name':item['name'],'sku':item['sku'],'color':item['color'],'size':item['size'],'quantity':item['quantity'],'custom_text':item.get('customization',{}).get('text') if item.get('customization') else None})
    batch={'id':secrets.token_hex(8),'batch_no':f"IITD-20260820-{len(BATCHES)+1:02d}",'status':'draft','revision':1,'checksum':hashlib.sha256(json.dumps(items,sort_keys=True).encode()).hexdigest(),'created_at':'2026-08-20T10:00:00Z','cutoff_at':'2026-08-20T10:00:00Z','units':sum(x['quantity'] for x in items),'items':items};BATCHES.append(batch);return self.json_out({'batch':batch},201)
   if path.endswith('/mark-sent'):
    bid=path.split('/')[4];batch=next((x for x in BATCHES if x['id']==bid),None)
    if not batch:return self.json_out({'error':'Vendor batch not found.'},404)
    batch['status']='sent';return self.json_out({'batch':batch})
  if path=='/api/auth/otp/request':
   digits=re.sub(r'\D','',str(body.get('phone','')))
   if len(digits)!=10:return self.json_out({'error':'Enter a valid Indian mobile number.'},400)
   cid=secrets.token_hex(12);OTP[cid]={'phone':'+91'+digits,'otp':'202626'};return self.json_out({'challengeId':cid,'demoOtp':'202626','message':'A verification code has been sent.'},202)
  if path=='/api/auth/otp/verify':
   challenge=OTP.pop(body.get('challengeId',''),None)
   if not challenge or not hmac.compare_digest(str(body.get('otp','')),challenge['otp']):return self.json_out({'error':'The verification code is invalid or expired.'},400)
   user=USERS.setdefault(challenge['phone'],{'id':secrets.token_hex(8),'phone':challenge['phone'],'fullName':'','email':'','affiliation':None,'isHostelResident':False,'hostelId':None,'roomNumber':''});token=secrets.token_hex(24);csrf=secrets.token_hex(16);SESSIONS[token]={'user':user,'csrf':csrf};return self.json_out({'user':user,'csrf':csrf,'needsProfile':not user['fullName']},cookie=f'customer_session={token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=2592000')
  if path=='/api/auth/logout':
   if not self.require_customer():return
   token=cookie_value(self.headers,'customer_session');SESSIONS.pop(token,None);return self.json_out({'ok':True},cookie='customer_session=; Max-Age=0; Path=/')
  if path=='/api/checkout/quote':
   items=[];subtotal=0;custom_total=0
   for request in body.get('items',[])[:50]:
    variant=None;product=None
    for p in PRODUCTS:
     variant=next((v for v in p['variants'] if v['id']==request.get('variantId')),None)
     if variant:product=p;break
    qty=max(1,min(10,int(request.get('qty',1))))
    if not variant or variant['stock']<qty:return self.json_out({'error':'An item is unavailable.'},409)
    customization=request.get('customization');surcharge=0
    if customization:
     if not product['customizable']:return self.json_out({'error':f"{product['name']} is not customizable."},400)
     text=str(customization.get('text','')).strip()
     if not text or len(text)>product['customization']['max']:return self.json_out({'error':'The customization text is not valid.'},400)
     surcharge=0
    subtotal+=variant['price']*qty;custom_total+=surcharge*qty;items.append({'variantId':variant['id'],'name':product['name'],'quantity':qty,'unitPrice':variant['price'],'customization':customization,'customizationSurcharge':surcharge})
   if not items:return self.json_out({'error':'Your bag is empty.'},400)
   shipping=0 if subtotal+custom_total>=149900 else 9900;return self.json_out({'currency':'INR','items':items,'subtotal':subtotal,'customizationTotal':custom_total,'discount':0,'shipping':shipping,'total':subtotal+custom_total+shipping,'walletAvailable':0,'walletApplied':0,'walletReward':0,'payment':{'provider':'Razorpay','mode':'demo','live':False,'demoAllowed':True}})
  if path=='/api/reviews':
   if not self.require_customer():return
   text=str(body.get('body','')).strip()
   if len(text.split())>400:return self.json_out({'error':'Reviews are limited to 400 words.'},400)
   if len(body.get('media',[]))>3:return self.json_out({'error':'Upload a maximum of three images.'},400)
   item=next((x for x in DEMO_ITEMS if x['id']==body.get('orderItemId') and x['deliveredAt']),None)
   if not item:return self.json_out({'error':'Only delivered products you ordered can be reviewed.'},403)
   if item['reviewed']:return self.json_out({'error':'You already reviewed this item.'},409)
   user=self.customer()['user'];review={'id':secrets.token_hex(6),'product_id':item['productId'],'product_name':item['name'],'rating':int(body.get('rating',5)),'title':str(body.get('title',''))[:100],'body':text,'status':'pending','full_name':user.get('fullName') or 'Verified customer','submitted_at':'2026-08-10T10:00:00Z'};REVIEWS.append(review);item['reviewed']=True;return self.json_out({'review':review,'message':'Your review is awaiting moderation.'},201)
  if path=='/api/account/addresses':
   session=self.require_customer()
   if not session:return
   postal=re.sub(r'\D','',str(body.get('postalCode','')))
   if not all(str(body.get(x,'')).strip() for x in ['recipientName','line1','city','state']) or len(postal)!=6:return self.json_out({'error':'Recipient, street, city, state and a six-digit PIN code are required.'},400)
   address={'id':secrets.token_hex(8),'label':str(body.get('label','Home'))[:30],'recipient_name':str(body['recipientName'])[:100],'phone_e164':'+91'+re.sub(r'\D','',str(body.get('phone','')))[-10:] if body.get('phone') else session['user']['phone'],'line_1':str(body['line1'])[:160],'line_2':str(body.get('line2',''))[:160],'landmark':str(body.get('landmark',''))[:100],'city':str(body['city'])[:80],'state':str(body['state'])[:80],'postal_code':postal,'is_default':bool(body.get('isDefault'))};book=ADDRESSES.setdefault(session['user']['phone'],[])
   if address['is_default']:
    for item in book:item['is_default']=False
   book.append(address);return self.json_out({'address':address},201)
  if path=='/api/admin/login':
   valid=bool(PREVIEW_ADMIN_PASSWORD) and hmac.compare_digest(str(body.get('email','')).lower(),PREVIEW_ADMIN_EMAIL.lower()) and hmac.compare_digest(str(body.get('password','')),PREVIEW_ADMIN_PASSWORD)
   if not valid:return self.json_out({'error':'Invalid administrator credentials.'},401)
   token=secrets.token_hex(24);ADMIN_SESSIONS.add(token);return self.json_out({'email':PREVIEW_ADMIN_EMAIL,'role':'Super admin','proof':'demo-admin-proof'},cookie=f'admin_session={token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=28800')
  if path=='/api/admin/products':
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   name=str(body.get('name','')).strip();slug=re.sub(r'[^a-z0-9]+','-',str(body.get('slug') or name).lower()).strip('-');sizes=[str(x).strip().upper() for x in body.get('sizes',[]) if str(x).strip()];category=next((x for x in CATEGORIES if x['id']==body.get('categoryId')),None);ptype=next((x for x in TYPES if x['id']==body.get('productTypeId')),None)
   if not name or not slug or not sizes or not category or not ptype:return self.json_out({'error':'Name, category, product type and sizes are required.'},400)
   pid='product-'+secrets.token_hex(5);color=str(body.get('colorName','Black'));cid='colorway-'+secrets.token_hex(5);price=int(body.get('basePrice',0));prefix=re.sub(r'[^A-Z0-9]+','-',str(body.get('skuPrefix') or name).upper()).strip('-');variants=[{'id':'variant-'+secrets.token_hex(5),'sku':f"{prefix}-{re.sub(r'[^A-Z0-9]+','-',color.upper())}-{size}",'size':size,'color':color,'colorwayId':cid,'price':price,'stock':int(body.get('stock',0)),'active':True} for size in sizes];colorway={'id':cid,'name':color,'slug':re.sub(r'[^a-z0-9]+','-',color.lower()).strip('-'),'swatch':body.get('swatch','#17171d'),'cardColor':body.get('cardColor','#163ea8'),'active':True,'showInCatalog':True,'sortOrder':0,'image':'/assets/merch-hero.png'};product={'id':pid,'name':name,'slug':slug,'category':category['name'],'categorySlug':category['slug'],'category_id':category['id'],'type':ptype['name'],'typeSlug':ptype['slug'],'product_type_id':ptype['id'],'short_description':str(body.get('shortDescription','')),'description':str(body.get('description','')),'price':price,'compare_price':int(body.get('comparePrice',0)),'badge':str(body.get('badge','')),'color':body.get('cardColor','#163ea8'),'image':'/assets/merch-hero.png','featured':bool(body.get('featured')),'customizable':bool(body.get('customizable')),'status':'draft','rating':0,'reviewCount':0,'variants':variants,'colorways':[colorway],'media':[],'customization':None,'sort_order':int(body.get('sortOrder',0)),'deleted_at':None};PRODUCTS.insert(0,product);return self.json_out({'product':product,'colorway':colorway,'variants':variants},201)
  if path.startswith('/api/admin/products/') and path.endswith('/restore'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   pid=path.split('/')[4];product=next((p for p in PRODUCTS if p['id']==pid),None)
   if not product or product.get('status')!='archived':return self.json_out({'error':'Only an archived product can be restored.'},409)
   product['status']='draft';product['deleted_at']=None;return self.json_out({'product':product})
  if path=='/api/admin/catalog-structure':
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   name=str(body.get('name','')).strip()[:80];kind=body.get('kind');slug=re.sub(r'[^a-z0-9]+','-',name.lower()).strip('-')
   if not name or kind not in ['category','productType']:return self.json_out({'error':'Choose a structure type and enter a name.'},400)
   target=CATEGORIES if kind=='category' else TYPES;item={'id':secrets.token_hex(6),'name':name,'slug':slug};target.append(item);return self.json_out({'item':item},201)
  if path.startswith('/api/admin/products/') and path.endswith('/colorways'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   pid=path.split('/')[4];product=next((p for p in PRODUCTS if p['id']==pid),None)
   if not product:return self.json_out({'error':'Product not found.'},404)
   name=str(body.get('name','')).strip();slug=re.sub(r'[^a-z0-9]+','-',str(body.get('slug') or name).lower()).strip('-')
   if not name:return self.json_out({'error':'Colorway name is required.'},400)
   colorway={'id':f"colorway-{pid}-{secrets.token_hex(3)}",'name':name,'slug':slug,'swatch':body.get('swatch','#17171d'),'cardColor':body.get('cardColor',product['color']),'active':body.get('active',True),'showInCatalog':body.get('showInCatalog',True),'sortOrder':body.get('sortOrder',len(product['colorways'])),'image':body.get('image') or product['image']};product['colorways'].append(colorway);return self.json_out({'colorway':colorway},201)
  self.send_error(404)
 def do_DELETE(self):
  parsed=urlparse(self.path);path=parsed.path;params=parse_qs(parsed.query)
  if path.startswith('/api/account/addresses/'):
   session=self.require_customer()
   if not session:return
   book=ADDRESSES.get(session['user']['phone'],[]);target=path.rsplit('/',1)[1];ADDRESSES[session['user']['phone']]=[x for x in book if x['id']!=target];return self.json_out({'ok':True})
  if path.startswith('/api/admin/media/'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   mid=path.rsplit('/',1)[1]
   for product in PRODUCTS:
    before=len(product.get('media',[]));product['media']=[x for x in product.get('media',[]) if x['id']!=mid]
    if len(product['media'])<before:return self.json_out({'ok':True})
   return self.json_out({'error':'Media not found.'},404)
  if path.startswith('/api/admin/products/'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   pid=path.rsplit('/',1)[1];product=next((p for p in PRODUCTS if p['id']==pid),None)
   if not product:return self.json_out({'error':'Product not found.'},404)
   if params.get('permanent')==['true']:
    if product['status']!='draft':return self.json_out({'error':'Only a draft product can be permanently deleted.'},409)
    PRODUCTS.remove(product);return self.json_out({'ok':True,'permanent':True})
   product['status']='archived';product['deleted_at']='2026-08-20T10:00:00Z';return self.json_out({'ok':True,'permanent':False})
  self.send_error(404)
 def do_PATCH(self):
  path=urlparse(self.path).path;body=self.body()
  if path=='/api/account/profile':
   session=self.require_customer()
   if not session:return
   affiliation=body.get('affiliation');resident=affiliation=='student' and body.get('isHostelResident') is True
   if affiliation not in ['student','faculty_staff','alumni','visitor_other']:return self.json_out({'error':'Select a valid affiliation.'},400)
   if resident and not body.get('hostelId'):return self.json_out({'error':'Select your hostel.'},400)
   user=session['user'];user.update({'fullName':str(body.get('fullName','')).strip()[:100],'email':str(body.get('email','')).strip(),'affiliation':affiliation,'isHostelResident':resident,'hostelId':body.get('hostelId') if resident else None,'roomNumber':str(body.get('roomNumber',''))[:30] if resident else ''});return self.json_out({'user':user})
  if path.startswith('/api/admin/reviews/'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   review=next((r for r in REVIEWS if r['id']==path.rsplit('/',1)[1]),None)
   if not review:return self.json_out({'error':'Review not found.'},404)
   review['status']=body.get('status','pending');return self.json_out({'ok':True})
  if path.startswith('/api/admin/products/') and path.endswith('/customization'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   pid=path.split('/')[4];product=next((p for p in PRODUCTS if p['id']==pid),None)
   if not product:return self.json_out({'error':'Product not found.'},404)
   config={'enabled':bool(body.get('enabled')),'label':body.get('label','Name or nickname'),'min':int(body.get('min',1)),'max':int(body.get('max',16)),'pattern':body.get('pattern','^[A-Za-z0-9 ._-]+$'),'placements':body.get('placements',[]),'styles':body.get('styles',[]),'colors':body.get('colors',[]),'surcharge':int(body.get('surcharge',0)),'addedDays':int(body.get('addedDays',0)),'returnPolicy':body.get('returnPolicy','')};product['customizable']=config['enabled'];product['customization']=config;return self.json_out({'customization':config})
  if path.startswith('/api/admin/colorways/'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   cid=path.rsplit('/',1)[1]
   for product in PRODUCTS:
    colorway=next((c for c in product['colorways'] if c['id']==cid),None)
    if colorway:
     for key in ['name','slug','swatch','cardColor','active','showInCatalog','sortOrder','image']:
      if key in body:colorway[key]=body[key]
     return self.json_out({'colorway':colorway})
   return self.json_out({'error':'Colorway not found.'},404)
  if path.startswith('/api/admin/media/'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   mid=path.rsplit('/',1)[1]
   for product in PRODUCTS:
    item=next((x for x in product.get('media',[]) if x['id']==mid),None)
    if item:
     if 'alt' in body:item['alt']=str(body['alt'])[:180]
     if 'sortOrder' in body:item['sortOrder']=max(0,int(body['sortOrder']))
     return self.json_out({'media':item})
   return self.json_out({'error':'Media not found.'},404)
  if path.startswith('/api/admin/orders/') and path.endswith('/status'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   oid=path.split('/')[4];order=next((o for o in ORDERS if o['id']==oid),None)
   if not order:return self.json_out({'error':'Order not found.'},404)
   field={'order':'order_status','payment':'payment_status','fulfilment':'fulfilment_status'}.get(body.get('field'))
   if not field:return self.json_out({'error':'Invalid status transition.'},400)
   order[field]=body.get('value');return self.json_out({'ok':True})
  if path=='/api/admin/settings' or path.startswith('/api/admin/products/') or path.startswith('/api/admin/coupons/'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   if path=='/api/admin/settings':
    allowed={'brand','announcement','headline','subhead','primary','secondary','accent','background','ink','radius','motion','motionIntensity','motionPreset','heroImage','heroButton','storyTitle','storyBody','footerNote'}
    SETTINGS.update({key:str(value)[:1000] for key,value in body.items() if key in allowed});return self.json_out({'ok':True,'settings':SETTINGS})
   if path.startswith('/api/admin/products/'):
    product=next((p for p in PRODUCTS if p['id']==path.rsplit('/',1)[1]),None)
    if not product:return self.json_out({'error':'Product not found.'},404)
    mapping={'name':'name','shortDescription':'short_description','description':'description','categoryId':'category_id','productTypeId':'product_type_id','basePrice':'price','comparePrice':'compare_price','badge':'badge','cardColor':'color','status':'status','featured':'featured','customizable':'customizable','sortOrder':'sort_order','image':'image'}
    for source,target in mapping.items():
     if source in body:product[target]=body[source]
    for variant in product['variants']:variant['price']=int(product['price'])
    return self.json_out({'ok':True})
   coupon=next((c for c in COUPONS if c['id']==path.rsplit('/',1)[1]),None)
   if not coupon:return self.json_out({'error':'Coupon not found.'},404)
   if 'active' in body:coupon['active']=bool(body['active'])
   return self.json_out({'coupon':coupon})
  self.send_error(404)

ThreadingHTTPServer(('127.0.0.1',4173),Handler).serve_forever()
