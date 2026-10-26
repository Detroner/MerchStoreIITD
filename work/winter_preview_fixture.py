"""Mirror the current sweatshirt configuration in the non-persistent local preview adapter."""
def sweatshirt():
    front='/assets/winter/sweatshirt-front.jpg'
    back='/assets/winter/sweatshirt-back.png'
    colorway={'id':'winter-black','name':'Black','slug':'black','swatch':'#17171d','cardColor':'#929290','active':True,'showInCatalog':True,'sortOrder':0,'image':front}
    return {'id':'winter-sweatshirt','name':'Sweatshirt','slug':'winter-sweatshirt','price':99900,'compare_price':0,'color':'#929290','image':front,'featured':True,'status':'active','customizable':True,'rating':0,'reviewCount':0,'categorySlug':'apparel','typeSlug':'sweatshirt','sort_order':-10,
      'description':'A black crewneck with IIT Delhi on the front and your name in white lettering in your chosen font at the middle back. Part of The IIT Delhi Drop.',
      'features':['The IIT Delhi Drop','Black crewneck','Personalized name at the middle back','White lettering in your chosen font','Personalization included'],
      'colorways':[colorway],
      'variants':[{'id':'winter-'+size,'sku':'IITD-WINTER-SWEAT-BLK-'+size,'size':size,'color':'Black','colorwayId':'winter-black','price':99900,'stock':20,'reserved':0,'active':True} for size in ['S','M','L','XL','XXL']],
      'media':[{'id':'winter-photo-'+str(i),'url':url,'alt':'Sweatshirt '+('back' if i else 'front'),'type':'image','colorwayId':'winter-black','sortOrder':i,'isThumbnail':i==0,'active':True} for i,url in enumerate([front,back])],
      'customization':{'enabled':True,'label':'Your name · middle back','min':1,'max':50,'pattern':r'^[A-Za-z0-9 ._-]{1,16}(?:\n[A-Za-z0-9 ._-]{1,16}){0,2}$','placements':['Back'],'styles':['Allison','Story Script','Erica One','Kavoon','Jim Nightshade'],'colors':['White'],'surcharge':0,'addedDays':2,'returnPolicy':'Customized items cannot be returned unless defective.'}}
