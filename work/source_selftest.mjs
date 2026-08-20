import assert from 'node:assert/strict';
import fs from 'node:fs';

const server=fs.readFileSync(new URL('../server.mjs',import.meta.url),'utf8');
const client=fs.readFileSync(new URL('../src/main.jsx',import.meta.url),'utf8');
const styles=fs.readFileSync(new URL('../src/styles.css',import.meta.url),'utf8');
const migration=fs.readFileSync(new URL('../migrations/004_order_operations_colorways.sql',import.meta.url),'utf8');

for(const route of ['/api/admin/orders','/api/admin/orders/summary','/api/admin/orders/matrix','/api/admin/vendor-batches','/api/admin/products/:id/customization','/api/admin/products/:id/colorways'])assert.ok(server.includes(route),`Missing ${route}`);
for(const table of ['product_colorways','vendor_batches','vendor_batch_items','order_status_history'])assert.ok(migration.includes(`CREATE TABLE ${table}`),`Missing ${table}`);
for(const component of ['StudioOrdersV2','StudioProductsV2','colorway-selector','vendor-batches/preview'])assert.ok(client.includes(component),`Missing ${component}`);
for(const selector of ['.orders-workspace','.orders-filterbar','.matrix-card','.colorway-layout','@media(max-width:760px)'])assert.ok(styles.includes(selector),`Missing ${selector}`);
assert.ok(client.includes('product.catalogItemId||product.id'),'Catalogue cards need stable colorway keys');
assert.ok(server.includes("vbi.id IS NULL AND o.payment_status IN('paid','captured')"),'New-vendor eligibility must require payment');
console.log('source self-test passed');
