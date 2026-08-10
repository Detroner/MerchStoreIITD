import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL,ssl:process.env.DATABASE_SSL==='true'?{rejectUnauthorized:false}:false});
const client=await pool.connect();
try{
  await client.query('BEGIN');
  await client.query('CREATE TABLE IF NOT EXISTS schema_migrations(name TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now())');
  const applied=new Set((await client.query('SELECT name FROM schema_migrations')).rows.map(x=>x.name));
  for(const name of fs.readdirSync(path.join(root,'migrations')).filter(x=>x.endsWith('.sql')).sort()){
    if(applied.has(name))continue;
    await client.query(fs.readFileSync(path.join(root,'migrations',name),'utf8'));
    await client.query('INSERT INTO schema_migrations(name) VALUES($1)',[name]);
    console.log(`applied ${name}`);
  }
  await client.query('COMMIT');
}catch(error){await client.query('ROLLBACK');throw error}finally{client.release();await pool.end()}
