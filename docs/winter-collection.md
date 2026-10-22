# Winter Collection — Drop 02

The Winter Collection appears above Drop 01, with two colourway cards for the same Sweatshirt product (Black and Lavender), and the existing Chill Hai? hoodie to the right on desktop. Each sweatshirt card has working colour dots and passes the selected colour to its product page. The larger live preview also has Black/Lavender buttons; the selected colour and multiline name carry through its product link. Mobile grids use two columns. Prices and stock remain controlled by Studio.

Migration 027 deactivates sweatshirt XS variants without deleting history and enables up to three lines of 16 characters each. Migration 028 renames the same colourway to Lavender, preserving IDs, SKUs, photos and order history; both old Violet and Lavendar links still resolve. It also sets Black S–XXL to 20 available units each, as confirmed by the owner on 22 October 2026, preserving reservations and recording the stock adjustment in the inventory ledger.

Both the sweatshirt and Chill Hai? hoodie use the same size-guide dialog as The Dogra Drip, with the supplied winter measurements in inches: S 26 length / 40 chest; M 27 / 42; L 28 / 44; XL 29 / 46; XXL 30 / 48. The T-shirt chart remains unchanged.

Shared Studio photos are included in catalogue thumbnails and product galleries, alongside any photos assigned to the selected colourway. This restores both existing Chill Hai? photos without creating a duplicate product.

## Customization

The SVG preview uses the selected colour's image and displays up to three centered lines in the self-hosted Allison font. Explicit front/back photo labels take priority; otherwise the thumbnail is the front and the next active image is the back. Replacement uploads therefore work with generic labels and new filenames. The same selection is used on the homepage, product page and enlarged view. Text is validated in the browser and server, then preserved as a newline-separated string in the cart and order snapshot. Switching colour retains the text and shows that colour's back. No other colour's stock is used when an option is unavailable.

## Assets

- `public/assets/winter/sweatshirt-front.jpg`: original supplied Black front.
- `public/assets/winter/sweatshirt-back.png`: blank Black back, generated earlier.
- `public/assets/winter/sweatshirt-violet-back.png`: blank Violet back, edited with the built-in image tool from the existing Studio upload. The original upload remains on disk.
- `public/assets/fonts/Allison-Regular.ttf`: self-hosted Allison, with its OFL license.

Violet edit prompt: “Use case: precise-object-edit. Edit target: the supplied violet sweatshirt back photograph. Remove ONLY the white sample words 'Your name' from the middle back and fill that area with seamlessly matching violet fabric texture. Preserve exact garment shape, position, color, lighting, seams, ribbing, gray background and square composition. Do not add any text, logos or objects. This blank back image will be used underneath a live text preview.”

## Validation

`npm run check` covers quote validation, multiline preservation, per-colour galleries, replacement back uploads, shared hoodie images, legacy colour links, exact size measurements and existing coupon checks. Browser checks cover homepage colour selection, name handoff, product and enlarged previews, and both winter size guides. Deploy through the existing GitHub Actions workflow; migration 028 is applied there.
