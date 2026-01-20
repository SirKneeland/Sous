import 'dotenv/config'
import express from 'express'
import { getChatResponse, ChatRequest } from './openai'

const app = express()
const PORT = 8787

app.use(express.json())

app.post('/api/chat', async (req, res) => {
  try {
    const body = (req.body ?? {}) as Partial<ChatRequest>
    const { userMessage, recipe, hasRecipe } = body
    const userMessageText =
      typeof userMessage === 'string'
        ? userMessage
        : userMessage && typeof userMessage === 'object' && 'content' in userMessage
          ? String((userMessage as any).content ?? '')
          : String(userMessage ?? '')

    if (!userMessageText) {
      return res.status(400).json({
        error: { message: 'Missing required field: userMessage', retryable: false }
      })
    }

    if (hasRecipe && !recipe) {
      return res.status(400).json({
        error: { message: 'Missing required field: recipe', retryable: false }
      })
    }

    if (!process.env.OPENAI_API_KEY) {
      console.error('[Sous API] Missing OPENAI_API_KEY environment variable')
      return res.status(500).json({
        error: {
          message: 'Server configuration error: missing API key',
          retryable: false
        }
      })
    }

    console.error(
      `[Sous API] Incoming request: hasRecipe=${Boolean(hasRecipe)}, userMessage="${userMessageText.slice(0, 80)}${userMessageText.length > 80 ? '...' : ''}"`
    )

    const response = await getChatResponse({
      userMessage: userMessageText,
      recipe: recipe ?? null,
      hasRecipe: Boolean(hasRecipe),
    })

    res.json(response)
  } catch (err) {
    console.error('[Sous API] Unhandled error in /api/chat:', err)
    res.status(500).json({
      error: {
        message: 'Internal server error',
        retryable: true
      }
    })
  }
})

app.listen(PORT, () => {
  console.log(`[Sous API] Server running on http://localhost:${PORT}`)
})
