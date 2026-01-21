import { Patch } from './recipe'

export interface ChatMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  timestamp: number
}

// Suggestion from AI photo analysis - proposal only, not auto-applied
export interface Suggestion {
  id: string
  title: string
  rationale?: string
  patches: Patch[]
}
