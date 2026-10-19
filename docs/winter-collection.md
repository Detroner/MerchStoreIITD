# Winter Collection — Drop 02

The storefront leads with the ₹899 Sweatshirt above the original catalogue, and reserves a Coming soon row for the planned hoodie. The original catalogue keeps its API ordering and stock behavior; the Sweatshirt is displayed in its own collection section rather than duplicated in the grid.

Apply migration `026_winter_collection_sweatshirt.sql` through the normal deployment workflow. It creates the active product, Black colourway, XS–XXL variants, front/back media, and included white Allison customization on the back. Stock starts at zero because quantities have not been supplied. Enter actual quantities in Studio to enable purchasing. The hoodie has no SKU or purchase action yet. No sweatshirt measurements were supplied, so the existing T-shirt size chart is not shown for it.

The local preview adapter includes the same Sweatshirt shape and zero stock. Its other products remain historical test fixtures and do not represent the current production catalogue.

## Preview and assets

Typing a name switches to the back. The 16-character name carries to the product page through a URL parameter and then into the existing cart/order customization snapshot. The shared SVG overlay scales long names proportionally and appears only on the back, including the enlarged view. Empty names show an example on the collection page and leave the product-page back blank.

- `public/assets/winter/sweatshirt-front.jpg`: user's supplied front image, unchanged.
- `public/assets/winter/sweatshirt-back.png`: blank-back derivative made with the built-in image generation tool.
- `public/assets/fonts/Allison-Regular.ttf`: self-hosted Google Fonts Allison; license in `Allison-OFL.txt` alongside it.

Image editing prompt: “Edit the attached sweatshirt BACK product photo. Remove ONLY the large white cursive words 'Your name' at the middle back, replacing those pixels with seamless matching black fabric texture. Preserve the exact sweatshirt shape, IIT Delhi crest at upper back (all its existing detail), collar, sleeves, seams, lighting, gray background, original square composition and positioning. No other edits, no new text or designs. This blank middle back will receive a live name overlay on a website.”

The photo and overlaid name are illustrative previews. The original attachments remain untouched.
