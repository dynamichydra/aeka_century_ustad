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
| 403 | Forbidden — item belongs to a different owner |
| 404 | Not found |
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

**Query parameters (optional)**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `limit` | `integer` | `50` | Max items to return (1–200) |
| `offset` | `integer` | `0` | Number of items to skip |

**Response** `200` — Array of furniture objects.

**Example**
```
GET /browse/room/Bedroom
GET /browse/room/Living%20Room
GET /browse/room/Bedroom?limit=20&offset=40
```

---

#### `GET /browse/group/{furniture_category}`

Browse by furniture group.

**Path parameter**

| Parameter | Type | Values |
|---|---|---|
| `furniture_category` | `string` | `Wardrobe`, `Chest of Drawers`, `Cabinet`, `Bookshelves`, `Tables`, `Bed`, `TV Unit`, `Wall Panelling`, `Dressing Unit`, `Sofa`, `Chair`, `Office Cubicles`, `Dining Table + Chairs`, `Bar Unit` |

**Query parameters (optional)**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `limit` | `integer` | `50` | Max items to return (1–200) |
| `offset` | `integer` | `0` | Number of items to skip |

**Response** `200` — Array of furniture objects.

**Example**
```
GET /browse/group/Wardrobe
GET /browse/group/Tables?limit=10
```

---

#### `GET /browse/product/{product}`

Browse by specific product name, with optional sub-category filter and pagination.

**Path parameter**

| Parameter | Type | Description |
|---|---|---|
| `product` | `string` | Exact product name (see taxonomy below) |

**Query parameters (optional)**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `subCategory` | `string` | — | Filter to a specific sub-type |
| `limit` | `integer` | `50` | Max items to return (1–200) |
| `offset` | `integer` | `0` | Number of items to skip |

**Response** `200` — Array of furniture objects.

**Examples**
```
GET /browse/product/Wardrobe
GET /browse/product/Wardrobe?subCategory=Sliding+Door
GET /browse/product/Sofa?subCategory=L-Shape&limit=10
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

### Item Detail

#### `GET /furniture/{id}`

Returns a single furniture item by its UUID.

**Path parameter**

| Parameter | Type | Description |
|---|---|---|
| `id` | `string (UUID)` | The furniture item's unique identifier |

**Response** `200` — Single furniture object.

**Errors**
- `404` — Item not found.

---

### Search

#### `POST /search/similar`

Upload an image to find the 5 most visually similar items in the catalog. Uses Gemini to generate a description of the uploaded image, embeds it, then performs cosine similarity search against stored embeddings.

**Request** — `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `file` | image file | Yes | The reference image to match against |
| `product` | `string` | No | Restrict results to this product (e.g. `Wardrobe`) |
| `furnitureCategory` | `string` | No | Restrict results to this furniture group |
| `interiorCategory` | `string` | No | Restrict results to this room type |
| `subCategory` | `string` | No | Restrict results to this sub-type |

> When multiple filters are provided, only the highest-priority one is applied: `product` > `subCategory` > `furnitureCategory` > `interiorCategory`.

**Response** `200` — Array of up to 5 furniture objects ordered by similarity.

---

#### `GET /search/text`

Free-text similarity search. The query string is embedded and compared against all stored description embeddings.

**Query parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `q` | `string` | Yes | Natural language description |
| `product` | `string` | No | Restrict results to this product (e.g. `Wardrobe`) |
| `furnitureCategory` | `string` | No | Restrict results to this furniture group |
| `interiorCategory` | `string` | No | Restrict results to this room type |
| `subCategory` | `string` | No | Restrict results to this sub-type |

> Same filter priority as `/search/similar`: `product` > `subCategory` > `furnitureCategory` > `interiorCategory`.

**Response** `200` — Array of furniture objects ordered by similarity.

**Examples**
```
GET /search/text?q=white+sliding+wardrobe
GET /search/text?q=grey+sofa&product=Sofa
GET /search/text?q=modern+cabinet&furnitureCategory=Cabinet
GET /search/text?q=wooden+shelf&interiorCategory=Study
```

---

### User History

All `/me/*` endpoints are scoped to a specific user. Until Firebase Auth is enabled, identity is passed explicitly as the `owner` parameter (user's email address).

#### `GET /me/uploads`

Returns all furniture images uploaded by the current user (paginated).

**Query parameters**

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `limit` | `integer` | No | `50` | Max items to return (1–200) |
| `offset` | `integer` | No | `0` | Number of items to skip |

**Response** `200` — Array of furniture objects.

---

#### `DELETE /me/uploads/{id}`

Delete a furniture item uploaded by the current user. Removes both the database record and the file from Firebase Storage.

**Path parameter**

| Parameter | Type | Description |
|---|---|---|
| `id` | `string (UUID)` | The furniture item's unique identifier |

**Response** `200`
```json
{ "deleted": "<uuid>" }
```

**Errors**
- `404` — Item not found.
- `403` — Item belongs to a different owner.

---

#### `GET /me/edits`

Returns the before/after image edit history for the given owner.

**Query parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `owner` | `string (email)` | Yes | User's email address |

**Response** `200` — Array of edit objects:

| Field | Type | Description |
|---|---|---|
| `id` | `string (UUID)` | Edit record ID |
| `originalImageUrl` | `string` | URL of the original furniture image |
| `editedImageUrl` | `string` | URL of the edited/processed image |
| `ownerId` | `string (email)` | User's email address |
| `furnitureId` | `string (UUID)` | UUID of the source furniture record |
| `createdAt` | `string (ISO 8601)` | Timestamp |

---

#### `POST /me/edits`

Log a before/after image editing pair. The server resolves the original image URL from the furniture record. The edited image is uploaded to Firebase Storage. These records do **not** appear in browse or search results.

**Request** — `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `edited_file` | image file | Yes | The edited/processed image |
| `id` | `string (UUID)` | Yes | UUID of the original furniture item |
| `owner` | `string (email)` | Yes | User's email address |

**Response** `201` — The created edit record.

**Errors**
- `404` — Furniture item with the given `id` not found.

---

## Taxonomy Quick Reference

### Rooms (`interiorCategory`)
`Kitchen` · `Living Room` · `Bedroom` · `Kids Room` · `Dining` · `Study` · `Bathroom` · `Office`

### Furniture Groups (`furnitureCategory`)
`Wardrobe` · `Chest of Drawers` · `Cabinet` · `Bookshelves` · `Tables` · `Bed` · `TV Unit` · `Wall Panelling` · `Dressing Unit` · `Sofa` · `Chair` · `Office Cubicles` · `Dining Table + Chairs` · `Bar Unit`
