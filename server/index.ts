import 'dotenv/config'
import express from 'express'
import { getChatResponse, ChatRequest } from './openai'

const app = express()
const PORT = 8787

app.use(express.json())

app.post('/api/chat', async (req, res) => {
  const { userMessage, recipe } = req.body as ChatRequest

  if (!userMessage || !recipe) {
    res.status(400).json({
      error: {
        message: 'Missing required fields: userMessage and recipe',
        retryable: false
      }
    })
    return
  }

  if (!process.env.OPENAI_API_KEY) {
    res.status(500).json({
      error: {
        message: 'Server configuration error: missing API key',
        retryable: false
      }
    })
    return
  }

  const response = await getChatResponse({ userMessage, recipe })
  res.json(response)
})

app.listen(PORT, () => {
  console.log(`[Sous API] Server running on http://localhost:${PORT}`)
})
