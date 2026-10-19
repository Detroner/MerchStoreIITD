"""Mirror migration 026 in the non-persistent local preview adapter."""
def sweatshirt():
    front='/assets/winter/sweatshirt-front.jpg'
    back='/assets/winter/sweatshirt-back.png'
    colorway={'id':'winter-black','name':'Black','slug':'black','swatch':'#17171d','cardColor':'#929290','active':True,'showInCatalog':True,'sortOrder':0,'image':front}
    return {'id':'winter-sweatshirt','name':'Sweatshirt','slug':'winter-sweatshirt','price':89900,'compare_price':0,'color':'#929290','image':front,'featured':True,'status':'active','customizable':True,'rating':0,'reviewCount':0,'categorySlug':'apparel','typeSlug':'sweatshirt','sort_order':-10,
      'description':'A black crewneck with IIT Delhi on the front and your name in white Allison lettering at the middle back. Part of the Winter Collection.',
      'features':['Winter Collection / Drop 02','Black crewneck','Personalized name at the middle back','White Allison lettering','Personalization included'],
      'colorways':[colorway],
      'variants':[{'id':'winter-'+size,'sku':'IITD-WINTER-SWEAT-BLK-'+size,'size':size,'color':'Black','colorwayId':'winter-black','price':89900,'stock':0,'reserved':0,'active':True} for size in ['XS','S','M','L','XL','XXL']],
      'media':[{'id':'winter-photo-'+str(i),'url':url,'alt':'Sweatshirt '+('back' if i else 'front'),'type':'image','colorwayId':'winter-black','sortOrder':i,'isThumbnail':i==0,'active':True} for i,url in enumerate([front,back])],
      'customization':{'enabled':True,'label':'Your name · middle back','min':1,'max':16,'pattern':'^[A-Za-z0-9 ._-]+$','placements':['Back'],'styles':['Allison'],'colors':['White'],'surcharge':0,'addedDays':2,'returnPolicy':'Customized items cannot be returned unless defective.'}}
