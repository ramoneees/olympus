# PDF Toolkit API

Sidecar service for n8n to process PDFs locally. Base URL: `http://localhost:5000`

All endpoints accept `multipart/form-data` with a `file` field.

---

## Endpoints

### Health Check

```
GET /health
```

**Response:**
```json
{
  "status": "healthy"
}
```

---

### Decrypt PDF

Remove password protection from a PDF.

```
POST /decrypt
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| file | file | yes | PDF file |
| password | string | if encrypted | PDF password |

**Response:** Decrypted PDF binary (`application/pdf`)

**Errors:**
- `401` - Incorrect or missing password
- `400` - No file provided or PDF error
- `500` - Server error

---

### Get Metadata

Extract page count, encryption status, and document info.

```
POST /metadata
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| file | file | yes | PDF file |
| password | string | if encrypted | PDF password |

**Response:**
```json
{
  "pages": 5,
  "encrypted": false,
  "metadata": {
    "Title": "Bank Statement",
    "Author": "Bank",
    "Creator": "Adobe Acrobat",
    "Producer": "Adobe PDF Library",
    "CreationDate": "D:20240101120000Z"
  }
}
```

---

### Convert to Images

Convert PDF pages to base64-encoded images for vision LLMs.

```
POST /to-images
```

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| file | file | yes | - | PDF file |
| password | string | if encrypted | - | PDF password |
| format | string | no | `png` | Image format: `png` or `jpeg` |
| dpi | int | no | `150` | Resolution (72-300 typical) |
| pages | string | no | all | Pages to convert: `1,2,3` or `1-5` |

**Response:**
```json
{
  "images": [
    {
      "page": 1,
      "image": "iVBORw0KGgoAAAANSUhEUgAA...",
      "format": "png"
    },
    {
      "page": 2,
      "image": "iVBORw0KGgoAAAANSUhEUgAA...",
      "format": "png"
    }
  ]
}
```

**Usage in n8n:**
1. HTTP Request node → `POST /to-images`
2. Split node → split by `images`
3. Use `{{ $json.image }}` (base64) in vision LLM node

---

### Extract Text

Extract raw text content from PDF.

```
POST /extract-text
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| file | file | yes | PDF file |
| password | string | if encrypted | PDF password |

**Response:**
```json
{
  "text": "Bank Statement\nAccount: 12345\nDate: 2024-01-01\n..."
}
```

**Note:** Works best with text-based PDFs. Scanned documents require OCR (not included).

---

### Extract Pages

Create a new PDF with only selected pages.

```
POST /extract-pages
```

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| file | file | yes | - | PDF file |
| password | string | if encrypted | - | PDF password |
| pages | string | no | `1` | Pages to extract: `1,3,5` |

**Response:** PDF binary with selected pages (`application/pdf`)

---

## Error Response Format

```json
{
  "error": "Description of the error"
}
```

Common error codes:
- `400` - Bad request (missing file, invalid params)
- `401` - Authentication failed (wrong password)
- `500` - Internal server error

---

## n8n Workflow Examples

### Vision LLM Pipeline

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌────────────┐
│  PDF Input  │ -> │  /to-images  │ -> │ Split Node  │ -> │ Vision LLM │
└─────────────┘    └──────────────┘    └─────────────┘    └────────────┘
```

**HTTP Request node config:**
- Method: `POST`
- URL: `http://localhost:5000/to-images`
- Body Content Type: `Multipart-Form Data`
- Body Parameters:
  - `file`: `{{ $binary.data }}` (from previous node)
  - `password`: `{{ $env.PDF_PASSWORD }}`
  - `format`: `png`
  - `dpi`: `150`

### Text Extraction Pipeline

```
┌─────────────┐    ┌──────────────┐    ┌────────────┐
│  PDF Input  │ -> │ /extract-text│ -> │ LLM Parser │
└─────────────┘    └──────────────┘    └────────────┘
```

### Decrypt + Archive

```
┌─────────────┐    ┌─────────────┐    ┌────────────┐
│ Encrypted   │ -> │   /decrypt  │ -> │   Store    │
│    PDF      │    │             │    │  (S3/NFS)  │
└─────────────┘    └─────────────┘    └────────────┘
```

---

## curl Examples

```bash
# Health check
curl http://localhost:5000/health

# Decrypt PDF
curl -X POST http://localhost:5000/decrypt \
  -F "file=@statement.pdf" \
  -F "password=mypassword" \
  -o decrypted.pdf

# Get metadata
curl -X POST http://localhost:5000/metadata \
  -F "file=@statement.pdf"

# Convert to images (pages 1-3)
curl -X POST http://localhost:5000/to-images \
  -F "file=@statement.pdf" \
  -F "pages=1,2,3" \
  -F "format=png" \
  -F "dpi=200"

# Extract text
curl -X POST http://localhost:5000/extract-text \
  -F "file=@statement.pdf"

# Extract pages 2 and 4
curl -X POST http://localhost:5000/extract-pages \
  -F "file=@statement.pdf" \
  -F "pages=2,4" \
  -o pages-2-4.pdf
```
