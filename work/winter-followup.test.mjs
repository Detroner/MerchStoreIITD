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
  assert.deepEqual(JSON.parse(JSON.stringify(winter.columns)),['Size','Length','Chest']);
  assert.deepEqual(JSON.parse(JSON.stringify(winter.rows)),[['S',26,40],['M',27,42],['L',28,44],['XL',29,46],['XXL',30,48]]);
  assert.equal(tee.rows.find(row=>row[0]==='M')[1],44);
  assert.equal(tee.columns.length,5);
});
