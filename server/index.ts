import 'dotenv/config'
import express from 'express'
import { getChatResponse, ChatRequest } from './openai'
import { intentRouter } from './intentRouter'

const app = express()
const PORT = 8787

app.use(express.json({ limit: '10mb' }))

app.post('/api/chat', async (req, res) => {
  try {
    const body = (req.body ?? {}) as Partial<ChatRequest & { image?: unknown; contextMessages?: unknown }>
    const { userMessage, recipe, hasRecipe, image } = body
    const userMessageText =
      typeof userMessage === 'string'
        ? userMessage
        : userMessage && typeof userMessage === 'object' && 'content' in userMessage
          ? String((userMessage as any).content ?? '')
          : String(userMessage ?? '')

    // Normalize image: must be a data URL string or undefined
    const imageDataUrl = typeof image === 'string' && image.startsWith('data:image/')
      ? image
      : undefined

    // Validate and sanitize contextMessages
    const N = 6
    const rawContext = body.contextMessages
    const contextMessages = Array.isArray(rawContext)
      ? rawContext
          .filter((m): m is { role: 'user' | 'assistant'; content?: unknown; text?: unknown } =>
            m && typeof m === 'object' &&
            (m.role === 'user' || m.role === 'assistant')
          )
          .map(m => ({
            role: m.role as 'user' | 'assistant',
            content: String(m.content ?? m.text ?? '').slice(0, 800) + (String(m.content ?? m.text ?? '').length > 800 ? '...' : '')
          }))
          .slice(-N)
      : undefined

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

    // Route the intent based on message and canvas state
    const routedIntent = intentRouter({
      messageText: userMessageText,
      hasCanvas: Boolean(hasRecipe),
      selectedOptionId: null, // UI can pass this for button taps
    })

    console.error(
      `[Sous API] Incoming request: hasRecipe=${Boolean(hasRecipe)}, hasImage=${Boolean(imageDataUrl)}, intent=${routedIntent.intent}, contextCount=${contextMessages?.length ?? 0}, userMessage="${userMessageText.slice(0, 80)}${userMessageText.length > 80 ? '...' : ''}"`
    )
    console.error(`[Sous API] Intent reason: ${routedIntent.reason}`)

    const response = await getChatResponse({
      userMessage: userMessageText,
      recipe: recipe ?? null,
      hasRecipe: Boolean(hasRecipe),
      intent: routedIntent.intent,
      image: imageDataUrl,
      contextMessages,
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
