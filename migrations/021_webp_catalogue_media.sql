-- The catalogue photos shipped as 1920px PNGs totalling ~17MB, which is what made the
-- storefront crawl on phones. They are now 1400px WebP (~0.4MB for the set, visually
-- identical at every size the site renders), so the stored keys move to the new extension.
-- Only the six known catalogue files are touched; anything uploaded through Studio is left alone.
UPDATE product_media SET storage_key=replace(storage_key,'.png','.webp')
WHERE storage_key IN (
  '/media/208cba41-36df-408b-9683-01dc156dedc3.png',
  '/media/2fd2641a-8e48-4345-8d59-ef3099e68b13.png',
  '/media/997f61dd-faa0-4b45-a43a-e657e89e0ec9.png',
  '/media/ed6636b7-1669-4dcd-9f8d-8af7a65d7775.png',
  '/media/f1317891-2435-405f-9a78-2381672c5db3.png',
  '/media/f657564e-0784-44c2-9fb5-ad9d666f86fa.png'
);
