import { useState, useRef, useEffect } from 'react'
import { ChatMessage } from '../types/chat'

interface ChatPaneProps {
  messages: ChatMessage[]
  onSendMessage: (message: string) => void
  onUndo: () => void
  onReset: () => void
  canUndo: boolean
  isLoading: boolean
}

export function ChatPane({
  messages,
  onSendMessage,
  onUndo,
  onReset,
  canUndo,
  isLoading
}: ChatPaneProps) {
  const [input, setInput] = useState('')
  const messagesEndRef = useRef<HTMLDivElement>(null)

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    const trimmed = input.trim()
    if (!trimmed || isLoading) return

    onSendMessage(trimmed)
    setInput('')
  }

  return (
    <div className="chat-pane">
      <div className="chat-messages">
        {messages.length === 0 && (
          <div className="chat-message assistant">
            <p>I'm Sous, your cooking companion! I'll help you through this recipe.</p>
            <p className="chat-hint">Try saying: "I forgot the onions", "I burned the garlic", or "make it spicier"</p>
          </div>
        )}
        {messages.map(msg => (
          <div key={msg.id} className={`chat-message ${msg.role}`}>
            <p>{msg.content}</p>
          </div>
        ))}
        {isLoading && (
          <div className="chat-message assistant loading">
            <p>Thinking...</p>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>
      <form className="chat-input-area" onSubmit={handleSubmit}>
        <input
          type="text"
          className="chat-input"
          placeholder="Tell me what's happening..."
          value={input}
          onChange={e => setInput(e.target.value)}
          disabled={isLoading}
        />
        <div className="chat-buttons">
          <button
            type="submit"
            className="send-btn"
            disabled={!input.trim() || isLoading}
          >
            Send
          </button>
          <button
            type="button"
            className="undo-btn"
            onClick={onUndo}
            disabled={!canUndo || isLoading}
          >
            Undo
          </button>
          <button type="button" className="reset-btn" onClick={onReset}>
            Reset
          </button>
        </div>
      </form>
    </div>
  )
}
