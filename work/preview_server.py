import json, secrets, hmac, hashlib, mimetypes, re
import os
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

ROOT=Path(__file__).resolve().parents[1]
SETTINGS={'brand':'THE IIT DELHI DROP','eyebrow':'OFFICIAL CAMPUS GOODS / EST. 2026','headline':'BIG BRAINS.\nBIGGER FITS.','subhead':'Campus-made merchandise for the curious, sleep-deprived and world-changing.','announcement':'FREE SHIPPING ABOVE ₹1,499 ✦ FRESH DROP IS LIVE ✦ MADE FOR CAMPUS','primary':'#ed3b24','secondary':'#163ea8','accent':'#f5ce3e','background':'#f4eddf','ink':'#17171d','radius':'20','motion':'1','motionIntensity':'1','motionPreset':'campus-pop','heroImage':'/assets/merch-hero.png','heroButton':'EXPLORE THE DROP','storyTitle':'Made of red brick & big ideas.','storyBody':'Designed for the people who turn impossible questions into everyday conversations.','footerNote':'Designed on campus. Worn everywhere.'}
CATEGORIES=[{'id':'cat-apparel','name':'Apparel','slug':'apparel'},{'id':'cat-accessories','name':'Accessories','slug':'accessories'},{'id':'cat-home','name':'Home','slug':'home'},{'id':'cat-stationery','name':'Stationery','slug':'stationery'}]
TYPES=[{'id':'type-tee','name':'T-shirt','slug':'t-shirt'},{'id':'type-hoodie','name':'Hoodie','slug':'hoodie'},{'id':'type-track','name':'Trackpants','slug':'trackpants'},{'id':'type-cap','name':'Cap','slug':'cap'},{'id':'type-bag','name':'Bag','slug':'bag'},{'id':'type-mug','name':'Mug','slug':'mug'},{'id':'type-stationery','name':'Stationery','slug':'stationery'}]
HOSTELS=[{'id':f'hostel-{i+1}','name':name} for i,name in enumerate(['Aravali','Girnar','Himadri','Jwalamukhi','Kailash','Karakoram','Kumaon','Nilgiri','Satpura','Shivalik','Udaigiri','Vindhyachal','Zanskar'])]

def make_variants(pid,apparel,price):
 sizes=['S','M','L','XL'] if apparel else ['One Size']; colors=['Navy','Cream'] if apparel else ['Campus Edition'];out=[]
 for i,(size,color) in enumerate((x,y) for x in sizes for y in colors):out.append({'id':f'variant-{pid}-{i+1}','sku':f'IITD-{pid.upper()}-{i+1:02d}','size':size,'color':color,'price':price,'stock':max(2,9-i),'active':True})
 return out
def custom(enabled=True): return {'enabled':enabled,'label':'Name or nickname','min':1,'max':16,'placements':['Front'],'styles':['Campus Block','Notebook Script'],'colors':['White','Red','Cobalt'],'surcharge':14900,'addedDays':2,'returnPolicy':'Customized items cannot be returned unless defective.'} if enabled else None
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
 pid,name,slug,category,category_slug,ptype,type_slug,price,compare,badge,color,desc,is_custom,rating,count=seed;apparel=category=='Apparel';PRODUCTS.append({'id':pid,'name':name,'slug':slug,'category':category,'categorySlug':category_slug,'type':ptype,'typeSlug':type_slug,'price':price,'compare_price':compare,'badge':badge,'color':color,'description':desc,'image':'/assets/merch-hero.png','featured':pid in ['hood','tee','track','jacket'],'customizable':is_custom,'status':'active','rating':0,'reviewCount':0,'variants':make_variants(pid,apparel,price),'customization':custom() if is_custom else None})

REVIEWS=[]
USERS={};SESSIONS={};OTP={};ADMIN_SESSIONS=set();ADDRESSES={}
DEMO_ITEMS=[{'id':'demo-item-1','productId':'hood','name':'Core Memory Hoodie','slug':'core-memory-hoodie','sku':'IITD-HOOD-02','size':'M','color':'Navy','image':'/assets/merch-hero.png','quantity':1,'unitPrice':249900,'deliveredAt':'2026-08-06T12:00:00Z','reviewed':False,'customization':{'text':'TANISH','placement':'Front','style':'Campus Block','color':'White'}},{'id':'demo-item-2','productId':'tee','name':'Main Building Tee','slug':'main-building-tee','sku':'IITD-TEE-03','size':'L','color':'Navy','image':'/assets/merch-hero.png','quantity':1,'unitPrice':99900,'deliveredAt':None,'reviewed':False,'customization':None}]
ORDERS=[{'id':'order-1','order_no':'IITD-2048','customer_name':'Demo Customer','total':364700,'order_status':'delivered','fulfilment_status':'delivered','created_at':'2026-08-02T09:40:00Z','items':DEMO_ITEMS}]
COUPONS=[{'id':'coupon-1','code':'CAMPUS10','type':'percentage','value':10,'min_order':99900,'usage_limit':500,'used_count':84,'active':True},{'id':'coupon-2','code':'FREESHIP','type':'free_shipping','value':0,'min_order':49900,'usage_limit':250,'used_count':41,'active':False}]

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
  if path=='/api/store':return self.json_out({'settings':SETTINGS,'categories':CATEGORIES,'productTypes':TYPES,'hostels':HOSTELS})
  if path=='/api/catalog':
   items=[p for p in PRODUCTS if p.get('status')=='active']
   if params.get('category','all')!='all':items=[p for p in items if p['categorySlug']==params['category']]
   if params.get('type','all')!='all':items=[p for p in items if p['typeSlug']==params['type']]
   if params.get('size','all')!='all':items=[p for p in items if any(v['size']==params['size'] and v['stock']>0 for v in p['variants'])]
   if params.get('customizable')=='true':items=[p for p in items if p['customizable']]
   sort=params.get('sort','featured')
   if sort=='newest':items=list(reversed(items))
   elif sort=='price_asc':items.sort(key=lambda p:p['price'])
   elif sort=='price_desc':items.sort(key=lambda p:p['price'],reverse=True)
   elif sort=='rating':items.sort(key=lambda p:p['rating'],reverse=True)
   else:items.sort(key=lambda p:(not p['featured'],PRODUCTS.index(p)))
   limit=max(1,min(24,int(params.get('limit',12))));offset=max(0,int(params.get('cursor',0)));page=items[offset:offset+limit]
   return self.json_out({'items':page,'nextCursor':str(offset+limit) if offset+limit<len(items) else None})
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
  if path=='/api/admin/data':
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   customers=[{'id':str(i+1),'full_name':u.get('fullName',''),'phone_e164':phone,'affiliation':u.get('affiliation'),'created_at':'2026-08-09T10:00:00Z'} for i,(phone,u) in enumerate(USERS.items())]
   products=[{'id':p['id'],'name':p['name'],'slug':p['slug'],'base_price':p['price'],'compare_price':p['compare_price'],'badge':p['badge'],'card_color':p['color'],'status':p['status'],'featured':p['featured'],'customizable':p['customizable'],'category':p['category'],'product_type':p['type'],'image':p['image'],'stock':sum(v['stock'] for v in p['variants'])} for p in PRODUCTS]
   breakdown=[]
   for order in ORDERS:
    for item in order['items']:
     row=next((x for x in breakdown if x['product_name']==item['name'] and x['size']==item['size']),None)
     if row:row['units']+=item['quantity'];row['orders']+=1
     else:breakdown.append({'product_name':item['name'],'size':item['size'],'units':item['quantity'],'orders':1})
   return self.json_out({'customers':customers,'reviews':REVIEWS,'orders':ORDERS,'products':products,'categories':CATEGORIES,'productTypes':TYPES,'coupons':COUPONS,'orderBreakdown':breakdown,'settings':SETTINGS,'payment':{'provider':'Razorpay','mode':'demo','live':False,'database':'PostgreSQL'}})
  if path.startswith('/assets/'):file=ROOT/'public'/path.lstrip('/')
  else:file=ROOT/('index.html' if path in ['/','/studio','/studio/','/cart','/account','/login'] or path.startswith('/products/') else path.lstrip('/'))
  if file.is_file():
   payload=file.read_bytes();self.send_response(200);self.send_header('Content-Type',mimetypes.guess_type(file)[0] or 'application/octet-stream');self.send_header('Content-Length',len(payload));self.end_headers();return self.wfile.write(payload)
  self.send_error(404)
 def do_POST(self):
  path=urlparse(self.path).path;body=self.body()
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
     surcharge=product['customization']['surcharge']
    subtotal+=variant['price']*qty;custom_total+=surcharge*qty;items.append({'variantId':variant['id'],'name':product['name'],'quantity':qty,'unitPrice':variant['price'],'customization':customization,'customizationSurcharge':surcharge})
   if not items:return self.json_out({'error':'Your bag is empty.'},400)
   shipping=0 if subtotal+custom_total>=149900 else 9900;return self.json_out({'currency':'INR','items':items,'subtotal':subtotal,'customizationTotal':custom_total,'discount':0,'shipping':shipping,'total':subtotal+custom_total+shipping,'payment':{'provider':'Razorpay','mode':'demo','live':False}})
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
   valid=hmac.compare_digest(str(body.get('email','')).lower(),'admin@iitdmerch.local') and hmac.compare_digest(str(body.get('password','')),os.environ.get('ADMIN_PREVIEW_PASSWORD',''))
   if not valid:return self.json_out({'error':'Invalid administrator credentials.'},401)
   token=secrets.token_hex(24);ADMIN_SESSIONS.add(token);return self.json_out({'email':'admin@iitdmerch.local','role':'Super admin','proof':'demo-admin-proof'},cookie=f'admin_session={token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=28800')
  if path=='/api/admin/catalog-structure':
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   name=str(body.get('name','')).strip()[:80];kind=body.get('kind');slug=re.sub(r'[^a-z0-9]+','-',name.lower()).strip('-')
   if not name or kind not in ['category','productType']:return self.json_out({'error':'Choose a structure type and enter a name.'},400)
   target=CATEGORIES if kind=='category' else TYPES;item={'id':secrets.token_hex(6),'name':name,'slug':slug};target.append(item);return self.json_out({'item':item},201)
  self.send_error(404)
 def do_DELETE(self):
  path=urlparse(self.path).path
  if path.startswith('/api/account/addresses/'):
   session=self.require_customer()
   if not session:return
   book=ADDRESSES.get(session['user']['phone'],[]);target=path.rsplit('/',1)[1];ADDRESSES[session['user']['phone']]=[x for x in book if x['id']!=target];return self.json_out({'ok':True})
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
  if path=='/api/admin/settings' or path.startswith('/api/admin/products/') or path.startswith('/api/admin/coupons/'):
   token=cookie_value(self.headers,'admin_session')
   if token not in ADMIN_SESSIONS or self.headers.get('X-Admin-Proof')!='demo-admin-proof':return self.json_out({'error':'Administrator authentication required.'},401)
   if path=='/api/admin/settings':
    allowed={'brand','announcement','headline','subhead','primary','secondary','accent','background','ink','radius','motion','motionIntensity','motionPreset','heroImage','heroButton','storyTitle','storyBody','footerNote'}
    SETTINGS.update({key:str(value)[:1000] for key,value in body.items() if key in allowed});return self.json_out({'ok':True,'settings':SETTINGS})
   if path.startswith('/api/admin/products/'):
    product=next((p for p in PRODUCTS if p['id']==path.rsplit('/',1)[1]),None)
    if not product:return self.json_out({'error':'Product not found.'},404)
    mapping={'name':'name','basePrice':'price','comparePrice':'compare_price','badge':'badge','cardColor':'color','status':'status','featured':'featured','customizable':'customizable','image':'image'}
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
