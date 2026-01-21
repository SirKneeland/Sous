import { useState, useRef, useEffect, RefObject } from 'react'
import { ChatMessage, Suggestion } from '../types/chat'
import { SuggestionTray } from './SuggestionTray'

type UIFocus = 'cooking' | 'editing'

interface ChatPaneProps {
  messages: ChatMessage[]
  onSendMessage: (message: string, image?: string) => void
  onUndo: () => void
  onReset: () => void
  canUndo: boolean
  isLoading: boolean
  suggestions?: Suggestion[]
  onApplySuggestion?: (suggestion: Suggestion) => void
  onDismissSuggestion?: (suggestionId: string) => void
  // Mobile UI props
  uiFocus?: UIFocus
  onCollapse?: () => void
  isMobile?: boolean
  inputDraft?: string
  setInputDraft?: (value: string) => void
  inputRef?: RefObject<HTMLInputElement>
  pendingImage?: string | null
  onClearPendingImage?: () => void
}

export function ChatPane({
  messages,
  onSendMessage,
  onUndo,
  onReset,
  canUndo,
  isLoading,
  suggestions = [],
  onApplySuggestion,
  onDismissSuggestion,
  uiFocus = 'editing',
  onCollapse,
  isMobile = false,
  inputDraft,
  setInputDraft,
  inputRef,
  pendingImage,
  onClearPendingImage
}: ChatPaneProps) {
  // Use shared draft state if provided (mobile), otherwise local state (desktop)
  const [localInput, setLocalInput] = useState('')
  const input = inputDraft !== undefined ? inputDraft : localInput
  const setInput = setInputDraft !== undefined ? setInputDraft : setLocalInput

  // Use external ref if provided (mobile), otherwise internal ref
  const internalInputRef = useRef<HTMLInputElement>(null)
  const actualInputRef = inputRef || internalInputRef

  // Use pending image from parent if provided (mobile), otherwise local state
  const [localSelectedImage, setLocalSelectedImage] = useState<string | null>(null)
  const selectedImage = pendingImage !== undefined ? pendingImage : localSelectedImage
  const setSelectedImage = onClearPendingImage
    ? (img: string | null) => img === null ? onClearPendingImage() : setLocalSelectedImage(img)
    : setLocalSelectedImage

  const messagesEndRef = useRef<HTMLDivElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Determine if we should show chat history
  // Desktop: always show; Mobile: only show in editing mode
  const showHistory = !isMobile || uiFocus === 'editing'

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    const trimmed = input.trim()
    if (!trimmed || isLoading) return

    onSendMessage(trimmed, selectedImage ?? undefined)
    setInput('')
    if (onClearPendingImage) {
      onClearPendingImage()
    } else {
      setLocalSelectedImage(null)
    }
  }

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    // Validate file type
    if (!file.type.startsWith('image/')) {
      return
    }

    // Convert to data URL
    const reader = new FileReader()
    reader.onload = () => {
      const dataUrl = reader.result as string
      setSelectedImage(dataUrl)
    }
    reader.readAsDataURL(file)

    // Reset input so same file can be selected again
    e.target.value = ''
  }

  const handlePhotoClick = () => {
    fileInputRef.current?.click()
  }

  const clearSelectedImage = () => {
    setSelectedImage(null)
  }

  return (
    <div className={`chat-pane ${isMobile ? uiFocus : ''}`}>
      {/* Collapse button - mobile + editing only */}
      {isMobile && uiFocus === 'editing' && onCollapse && (
        <button
          type="button"
          className="chat-collapse-btn"
          onClick={onCollapse}
          aria-label="Collapse chat"
        >
          <span className="chat-collapse-handle" />
        </button>
      )}

      {/* Chat history - conditionally rendered */}
      {showHistory && (
        <div className="chat-messages">
          {messages.length === 0 && (
            <div className="chat-message assistant">
              <p>I'm Sous, your cooking companion! I'll help you through this recipe.</p>
              <p className="chat-hint">Try saying: "I forgot the onions", "I burned the garlic", or "make it spicier"</p>
            </div>
          )}
          {messages.map((msg, index) => {
            // Find if this is the last assistant message (for inline suggestions)
            const isLastAssistantMessage =
              msg.role === 'assistant' &&
              !messages.slice(index + 1).some(m => m.role === 'assistant')

            return (
              <div key={msg.id}>
                <div className={`chat-message ${msg.role}`}>
                  <p>{msg.content}</p>
                </div>
                {isLastAssistantMessage && suggestions.length > 0 && onApplySuggestion && onDismissSuggestion && (
                  <SuggestionTray
                    suggestions={suggestions}
                    onApply={onApplySuggestion}
                    onDismiss={onDismissSuggestion}
                  />
                )}
              </div>
            )
          })}
          {isLoading && (
            <div className="chat-message assistant loading">
              <p>Thinking...</p>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>
      )}
      <form className="chat-input-area" onSubmit={handleSubmit}>
        {selectedImage && (
          <div className="image-preview">
            <img src={selectedImage} alt="Selected" />
            <button
              type="button"
              className="image-preview-clear"
              onClick={clearSelectedImage}
              aria-label="Remove image"
            >
              &times;
            </button>
          </div>
        )}
        <div className="chat-input-row">
          <input
            type="file"
            ref={fileInputRef}
            onChange={handleFileSelect}
            accept="image/*"
            style={{ display: 'none' }}
          />
          <button
            type="button"
            className="photo-btn"
            onClick={handlePhotoClick}
            disabled={isLoading}
            aria-label="Attach photo"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
              <circle cx="8.5" cy="8.5" r="1.5"/>
              <polyline points="21 15 16 10 5 21"/>
            </svg>
          </button>
          <input
            ref={actualInputRef}
            type="text"
            className="chat-input"
            placeholder={selectedImage ? "Ask about this photo..." : "Tell me what's happening..."}
            value={input}
            onChange={e => setInput(e.target.value)}
            disabled={isLoading}
          />
        </div>
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
