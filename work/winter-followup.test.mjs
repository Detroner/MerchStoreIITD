import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source=fs.readFileSync(new URL('../src/main.jsx',import.meta.url),'utf8');
const helpers=source.slice(source.indexOf('function productGallery('),source.indexOf('function SweatshirtPreview('));
const {sweatshirtViews,matchesSweatshirtColor}=vm.runInNewContext(helpers+';({sweatshirtViews,matchesSweatshirtColor})');
const lavender={id:'lavender'};
const front={id:'front',type:'image',colorwayId:'lavender',alt:'Sweatshirt',isThumbnail:true,sortOrder:1,url:'/media/front.jpg'};
const replacement={id:'replacement',type:'image',colorwayId:'lavender',alt:'Lavendar',sortOrder:2,url:'/media/new-back.jpg'};

test('replacement back photo gets the preview without a special filename or label',()=>{
  const views=sweatshirtViews({media:[replacement,front]},lavender);
  assert.equal(views.front.id,front.id);
  assert.equal(views.back.url,replacement.url);
});

test('back selection excludes another colour, inactive media and video',()=>{
  const media=[{...replacement,id:'black',colorwayId:'black',alt:'Black back'},{...replacement,id:'removed',active:false,alt:'Lavender back'},{...replacement,id:'video',type:'video',alt:'Back'},front,replacement];
  assert.equal(sweatshirtViews({media},lavender).back.id,'replacement');
  assert.equal(sweatshirtViews({media:[front]},lavender).back,undefined);
});

test('explicit back label takes priority over an additional front image',()=>{
  const back={...replacement,id:'labelled',alt:'Lavender sweatshirt back'};
  assert.equal(sweatshirtViews({media:[front,replacement,back]},lavender).back.id,'labelled');
});

test('old violet and misspelled lavender links resolve to Lavender only',()=>{
  for(const requested of ['lavender','lavendar','violet'])assert.equal(matchesSweatshirtColor('lavender',requested),true);
  assert.equal(matchesSweatshirtColor('black','violet'),false);
  assert.equal(matchesSweatshirtColor('lavender',null),false);
});

test('winter measurements match the supplied chart and leave Dogra measurements intact',()=>{
  const start=source.indexOf('const SIZE_CHART='),end=source.indexOf('// Terms, privacy',start);
  const {winter,tee}=vm.runInNewContext(source.slice(start,end)+';({winter:WINTER_SIZE_CHART,tee:SIZE_CHART})');
  assert.deepEqual(JSON.parse(JSON.stringify(winter.columns)),['Size','Chest','Waist','Arm length']);
  assert.deepEqual(JSON.parse(JSON.stringify(winter.rows)),[['XS','30¾ - 33¾','26 - 29¼','23¼'],['S','33¾ - 35½','29¼ - 30¾','23¼ - 23¾'],['M','37 - 38½','32¼ - 33¾','23¾ - 24'],['L','40¼ - 41¾','35½ - 37','24¼ - 24½'],['XL','43¼ - 44¾','38¾ - 40½','24½'],['XXL','46½ - 48','42¼ - 44','24½ - 24¾']]);
  assert.equal(tee.rows.find(row=>row[0]==='M')[1],44);
  assert.equal(tee.columns.length,5);
});
