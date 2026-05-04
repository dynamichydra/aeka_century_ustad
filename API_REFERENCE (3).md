# API Reference — Century Ustad

Base URL (production): `https://century-ustad-api-507497848998.asia-south1.run.app`
Base URL (local dev): `http://localhost:8000`

Interactive docs (Swagger UI): `{base_url}/docs`

---

## Authentication

All endpoints currently operate with a system-level owner (`SYSTEM`) by default. User-scoped endpoints read the caller's identity from the `Authorization` header once Firebase Auth is enabled.

```
Authorization: Bearer <firebase_id_token>
```

> Until Firebase Auth is wired up, passing no header is valid and the server treats the caller as `SYSTEM`.

---

## Response Format

All successful responses return JSON. Error responses follow FastAPI's standard shape:

```json
{
  "detail": "Human-readable error message"
}
```

| HTTP Status | Meaning |
|---|---|
| 200 | Success |
| 201 | Resource created |
| 422 | Validation error (invalid image, bad classification, etc.) |
| 500 | Internal server error |

---

## Furniture Object

Most endpoints return a list of furniture objects with this shape:

| Field | Type | Description |
|---|---|---|
| `id` | `string (UUID)` | Unique identifier |
| `imageUrl` | `string` | Public Firebase Storage URL |
| `fileName` | `string` | Stored filename (slug + UUID suffix) |
| `product` | `string` | Product type (e.g. `Wardrobe`, `Sofa`) |
| `interiorCategory` | `string[]` | Room types (e.g. `["Bedroom"]`) |
| `furnitureCategory` | `string` | Furniture group (e.g. `Wardrobe`) |
| `subCategory` | `string[]` | Sub-types (e.g. `["Sliding Door"]`) |
| `description` | `string` | AI-generated search description |
| `ownerId` | `string` | `SYSTEM` for catalog items, or user UID |

---

## Endpoints

---

### Upload

#### `POST /upload`

Upload a furniture image. The server classifies it with Gemini, optimises it to JPEG (max 1024 px), stores it in Firebase Storage, and saves the metadata and embedding to the database.

**Request** — `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `file` | image file | Yes | JPEG, PNG, WebP, BMP, or TIFF |

**Response** `201` — Furniture object including the new `id`.

**Example curl**
```bash
curl -X POST https://century-ustad-api-.../upload \
  -F "file=@/path/to/sofa.jpg"
```

**Errors**
- `422` — Gemini returned a product not in the valid taxonomy.

---

### Browse

#### `GET /browse/featured`

Returns up to 10 randomly sampled items from the public catalog (`ownerId = SYSTEM`). The selection changes on every call — suitable for a home/landing page carousel.

**Query params** — none

**Response** `200` — Array of up to 10 furniture objects.

---

#### `GET /browse/room/{interior_category}`

Browse all catalog and user items that belong to a specific room type. Results include public items (`SYSTEM`) plus items belonging to the authenticated user.

**Path parameter**

| Parameter | Type | Values |
|---|---|---|
| `interior_category` | `string` | `Kitchen`, `Living Room`, `Bedroom`, `Kids Room`, `Dining`, `Study`, `Bathroom`, `Office` |

**Response** `200` — Array of furniture objects.

**Example**
```
GET /browse/room/Bedroom
GET /browse/room/Living%20Room
```

---

#### `GET /browse/group/{furniture_category}`

Browse by furniture group.

**Path parameter**

| Parameter | Type | Values |
|---|---|---|
| `furniture_category` | `string` | `Wardrobe`, `Chest of Drawers`, `Cabinet`, `Bookshelves`, `Tables`, `Bed`, `TV Unit`, `Wall Panelling`, `Dressing Unit`, `Sofa`, `Chair`, `Office Cubicles`, `Dining Table + Chairs`, `Bar Unit` |

**Response** `200` — Array of furniture objects.

**Example**
```
GET /browse/group/Wardrobe
GET /browse/group/Tables
```

---

#### `GET /browse/product/{product}`

Browse by specific product name, with an optional sub-category filter.

**Path parameter**

| Parameter | Type | Description |
|---|---|---|
| `product` | `string` | Exact product name (see taxonomy below) |

**Query parameter (optional)**

| Parameter | Type | Description |
|---|---|---|
| `subCategory` | `string` | Filter to a specific sub-type |

**Response** `200` — Array of furniture objects.

**Examples**
```
GET /browse/product/Wardrobe
GET /browse/product/Wardrobe?subCategory=Sliding+Door
GET /browse/product/Sofa?subCategory=L-Shape
```

**Valid products**

> Bar Unit, Bathroom Cabinet, Bed, Bedside Table, Bookshelves, Cafeteria Furniture, Center Table, Chairs, Chest of Drawers, Coffee Table, Conference Table, Conference Room Furniture, Crockery Cabinet, Dining Table, Dining Table + Chairs, Drawers, Dressing Unit, Headboard, Kids Bed, Kids Wardrobe, Kitchen Cabinet, Office Cabinet, Office Cubicles, Office Table, Reception Area Furniture, Reception Table, Shoe Cabinet, Sofa, Study Table, TV Unit, Wall Panelling, Wardrobe

**Valid sub-categories per product**

| Product | Sub-categories |
|---|---|
| Wardrobe | 1 Door, 2 Door, 3 Door, 4 Door, 4+ Door, Sliding Door |
| Drawers | 1 Drawer, 2 Drawer, 4 Drawer |
| Shoe Cabinet | 1 Door, 2 Door, Open rack, Rack with seating, Tilt out shoe rack |
| Crockery Cabinet | 1 Door, 2 Door, 3 Door, 4 Door |
| Bathroom Cabinet | Mirror Cabinets, Wall Mounted Cabinets, Standing Cabinets, Tall Storage Cabinets, Corner Cabinets |
| Office Cabinet | 1 Door, 2 Door, 3 Door, 4 Door, 4+ Door |
| Bookshelves | Open rack, 1 Door, 2 Door, 3 Door |
| Dining Table | 2 Seater, 4 Seater, 6 Seater, 8 Seater |
| Bed | Kid's Bed, Single bed, Double Bed, Queen bed, King bed, Bunk bed |
| Headboard | Single bed, Queen bed, King bed |
| Sofa | 1 seater, 2 Seater, 3 Seater, 4 Seater, 5 Seater, 6 Seater, L-Shape |

---

### Search

#### `POST /search/similar`

Upload an image to find the 5 most visually similar items in the catalog. Uses Gemini to generate a description of the uploaded image, embeds it, then performs cosine similarity search against stored embeddings.

**Request** — `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `file` | image file | Yes | The reference image to match against |

**Response** `200` — Array of up to 5 furniture objects ordered by similarity.

---

#### `GET /search/text`

Free-text similarity search. The query string is embedded and compared against all stored description embeddings.

**Query parameter**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `q` | `string` | Yes | Natural language description |

**Response** `200` — Array of furniture objects ordered by similarity.

**Examples**
```
GET /search/text?q=white+sliding+wardrobe
GET /search/text?q=modern+grey+L+shape+sofa
GET /search/text?q=wooden+study+table+with+drawers
```

---

### User History

All endpoints in this group are scoped to the authenticated user. They return only records where `ownerId` matches the caller's Firebase UID.

#### `GET /me/uploads`

Returns all furniture images uploaded by the current user.

**Response** `200` — Array of furniture objects.

---

#### `GET /me/edits`

Returns the before/after image edit history for the current user.

**Response** `200` — Array of edit objects:

| Field | Type | Description |
|---|---|---|
| `id` | `string (UUID)` | Edit record ID |
| `originalImageUrl` | `string` | URL of the original image |
| `editedImageUrl` | `string` | URL of the edited/processed image |
| `ownerId` | `string` | User ID |
| `furnitureId` | `string (UUID) \| null` | Reference to the source furniture record (if any) |
| `createdAt` | `string (ISO 8601)` | Timestamp |

---

#### `POST /me/edits`

Log a before/after image editing pair. The edited image is uploaded to Firebase Storage and a record linking it to the original is saved. These records do **not** appear in the public search catalog.

**Request** — `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `edited_file` | image file | Yes | The edited/processed image |
| `original_url` | `string` | Yes | Public URL of the original image |
| `furniture_id` | `string (UUID)` | No | ID of the related furniture record |

**Response** `201` — The created edit record.

---

## Taxonomy Quick Reference

### Rooms (`interiorCategory`)
`Kitchen` · `Living Room` · `Bedroom` · `Kids Room` · `Dining` · `Study` · `Bathroom` · `Office`

### Furniture Groups (`furnitureCategory`)
`Wardrobe` · `Chest of Drawers` · `Cabinet` · `Bookshelves` · `Tables` · `Bed` · `TV Unit` · `Wall Panelling` · `Dressing Unit` · `Sofa` · `Chair` · `Office Cubicles` · `Dining Table + Chairs` · `Bar Unit`
