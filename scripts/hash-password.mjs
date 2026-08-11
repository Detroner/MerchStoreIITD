#!/usr/bin/env node
import argon2 from 'argon2';

const pass = process.argv[2];
if (!pass) {
  console.error('Usage: node scripts/hash-password.mjs <password>');
  process.exit(2);
}

try {
  const hash = await argon2.hash(pass);
  console.log(hash);
} catch (err) {
  console.error('Hashing failed:', err);
  process.exit(1);
}
