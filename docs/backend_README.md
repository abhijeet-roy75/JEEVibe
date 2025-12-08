# JEEVibe Backend API

Node.js Express server for Snap & Solve feature.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file:
```bash
cp .env.example .env
```

3. Add your OpenAI API key:
```
OPENAI_API_KEY=your_key_here
PORT=3000
NODE_ENV=development
```

4. Start server:
```bash
npm start
```

## API Endpoints

### POST /api/solve
Upload image and get solution with follow-up questions.

**Request:**
- Method: POST
- Content-Type: multipart/form-data
- Body: `image` (file, max 5MB)

**Response:**
```json
{
  "success": true,
  "data": {
    "recognizedQuestion": "...",
    "subject": "Mathematics",
    "topic": "Calculus - Integration",
    "difficulty": "medium",
    "solution": {
      "approach": "...",
      "steps": ["Step 1", "Step 2"],
      "finalAnswer": "...",
      "priyaMaamTip": "..."
    },
    "followUpQuestions": [
      {
        "question": "...",
        "options": {"A": "...", "B": "...", "C": "...", "D": "..."},
        "correctAnswer": "A",
        "explanation": {...}
      }
    ]
  }
}
```

### GET /api/health
Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-11-21T10:00:00.000Z"
}
```

## Environment Variables

- `OPENAI_API_KEY` - Your OpenAI API key (required)
- `PORT` - Server port (default: 3000)
- `NODE_ENV` - Environment (development/production)

## Notes

- Images are processed in memory (no disk storage for POC)
- Maximum image size: 5MB
- OpenAI API timeout: 30 seconds
- Uses gpt-4o model for both vision and text generation

