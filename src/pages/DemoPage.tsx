import { useState, useCallback } from 'react'
import { useRecipeState } from '../hooks/useRecipeState'
import { demoRecipe } from '../data/demoRecipe'
import { RecipeCanvas } from '../components/RecipeCanvas'
import { ChatPane } from '../components/ChatPane'
import { ChatMessage, Suggestion } from '../types/chat'
import { sendRejectionEvent } from '../services/llm'
import { LLMResponse } from '../types/recipe'

interface ChatApiError {
  error: {
    message: string
    retryable: boolean
  }
}

interface ChatApiSuccess extends LLMResponse {
  suggestions?: Suggestion[]
}

type ChatApiResponse = ChatApiSuccess | ChatApiError

function isErrorResponse(response: ChatApiResponse): response is ChatApiError {
  return 'error' in response
}

// Helper to clamp string length with ellipsis
function clamp(s: string, max = 800): string {
  return s.length > max ? s.slice(0, max) + '...' : s
}

// Helper to extract content from message (handles .content or .text)
function extractContent(m: unknown): string {
  if (!m || typeof m !== 'object') return ''
  const obj = m as Record<string, unknown>
  if (typeof obj.content === 'string') return obj.content
  if (typeof obj.text === 'string') return obj.text
  return String(obj.content ?? obj.text ?? '')
}

export function DemoPage() {
  const {
    recipe,
    hasRecipe,
    toggleIngredient,
    markStepDone,
    setCurrentStep,
    resetRecipe,
    applyRecipePatches,
    undo,
    canUndo,
    pendingChangeSet,
    approveChanges,
    rejectChanges
  } = useRecipeState(demoRecipe)

  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [suggestions, setSuggestions] = useState<Suggestion[]>([])
  const [isLoading, setIsLoading] = useState(false)

  const handleSendMessage = useCallback(async (content: string, image?: string) => {
    // Capture stable snapshot before any state changes
    const hadRecipeBeforeSend = hasRecipe

    // Build context from existing messages BEFORE appending new user message
    const contextMessages = messages
      .filter(m => m.role === 'user' || m.role === 'assistant')
      .slice(-6)
      .map(m => ({
        role: m.role as 'user' | 'assistant',
        content: clamp(extractContent(m))
      }))

    // Dev log to verify context accumulation
    console.log('[Sous] pre-send messages:', messages.length, messages.map(m => m.role))
    console.log('[Sous] contextMessages:', contextMessages.length, contextMessages.map(m => m.role))

    // Add user message
    const userMessage: ChatMessage = {
      id: `msg-${Date.now()}-user`,
      role: 'user',
      content,
      timestamp: Date.now()
    }
    setMessages(prev => [...prev, userMessage])
    setIsLoading(true)

    try {
      // Call backend API
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userMessage: content,
          recipe: hasRecipe ? recipe : null,
          hasRecipe,
          image,
          contextMessages,
        })
      })

      const response: ChatApiResponse = await res.json()

      // Handle error response from server
      if (isErrorResponse(response)) {
        const errorMessage: ChatMessage = {
          id: `msg-${Date.now()}-error`,
          role: 'assistant',
          content: response.error.message,
          timestamp: Date.now()
        }
        setMessages(prev => [...prev, errorMessage])
        return
      }

      // Always replace suggestions state (clear stale ones if empty/missing)
      setSuggestions(response.suggestions ?? [])

      // Apply patches to recipe
      if (response.patches.length > 0) {
        const result = applyRecipePatches(response.patches)

        // Auto-approve initial recipe creation (no review banner needed)
        const isInitialCreate =
          !hadRecipeBeforeSend &&
          response.patches?.some(p => p.op === 'replace_recipe')
        if (isInitialCreate) {
          approveChanges()
        }

        // If some patches were rejected, add info to the message
        let assistantContent = response.assistant_message
        if (result.rejectedPatches.length > 0) {
          const rejectionReasons = result.rejectedPatches
            .map(r => r.reason)
            .join('; ')
          assistantContent += ` (Note: Some changes couldn't be made: ${rejectionReasons})`
        }

        // Add assistant message
        const assistantMessage: ChatMessage = {
          id: `msg-${Date.now()}-assistant`,
          role: 'assistant',
          content: assistantContent,
          timestamp: Date.now()
        }
        setMessages(prev => [...prev, assistantMessage])
      } else {
        // No patches, just add the assistant message
        const assistantMessage: ChatMessage = {
          id: `msg-${Date.now()}-assistant`,
          role: 'assistant',
          content: response.assistant_message,
          timestamp: Date.now()
        }
        setMessages(prev => [...prev, assistantMessage])
      }
    } catch (error) {
      // Handle network/fetch error
      const errorMessage: ChatMessage = {
        id: `msg-${Date.now()}-error`,
        role: 'assistant',
        content: 'Sorry, something went wrong. Please try again.',
        timestamp: Date.now()
      }
      setMessages(prev => [...prev, errorMessage])
    } finally {
      setIsLoading(false)
    }
  }, [messages, recipe, hasRecipe, applyRecipePatches, approveChanges])

  const handleReset = useCallback(() => {
    resetRecipe()
    setMessages([])
    setSuggestions([])
  }, [resetRecipe])

  // Handle applying a suggestion - routes through patch pipeline
  const handleApplySuggestion = useCallback((suggestion: Suggestion) => {
    const result = applyRecipePatches(suggestion.patches)

    // Remove the suggestion from the list
    setSuggestions(prev => prev.filter(s => s.id !== suggestion.id))

    // Add a message about applying the suggestion
    let messageContent = `Applied: ${suggestion.title}`
    if (result.rejectedPatches.length > 0) {
      const rejectionReasons = result.rejectedPatches
        .map(r => r.reason)
        .join('; ')
      messageContent += ` (Note: Some changes couldn't be made: ${rejectionReasons})`
    }

    const applyMessage: ChatMessage = {
      id: `msg-${Date.now()}-system`,
      role: 'assistant',
      content: messageContent,
      timestamp: Date.now()
    }
    setMessages(prev => [...prev, applyMessage])
  }, [applyRecipePatches])

  // Handle dismissing a suggestion
  const handleDismissSuggestion = useCallback((suggestionId: string) => {
    setSuggestions(prev => prev.filter(s => s.id !== suggestionId))
  }, [])

  // Handle approving changes - just clears the highlights
  const handleApproveChanges = useCallback(() => {
    approveChanges()

    // Add a system message confirming approval
    const approvalMessage: ChatMessage = {
      id: `msg-${Date.now()}-system`,
      role: 'assistant',
      content: 'Changes approved!',
      timestamp: Date.now()
    }
    setMessages(prev => [...prev, approvalMessage])
  }, [approveChanges])

  // Handle rejecting changes - reverts and sends event to LLM
  const handleRejectChanges = useCallback(() => {
    const rejectedChangeSet = rejectChanges()

    if (rejectedChangeSet) {
      // Send rejection event to LLM (stubbed for now)
      sendRejectionEvent(rejectedChangeSet.patches)

      // Add a system message confirming rejection
      const rejectionMessage: ChatMessage = {
        id: `msg-${Date.now()}-system`,
        role: 'assistant',
        content: 'Changes rejected and reverted. I\'ll try a different approach next time.',
        timestamp: Date.now()
      }
      setMessages(prev => [...prev, rejectionMessage])
    }
  }, [rejectChanges])

  return (
    <div className="app-container">
      <div className="canvas-pane">
        <RecipeCanvas
          recipe={recipe}
          hasRecipe={hasRecipe}
          onToggleIngredient={toggleIngredient}
          onMarkStepDone={markStepDone}
          onSetCurrentStep={setCurrentStep}
          pendingChangeSet={pendingChangeSet}
          onApproveChanges={handleApproveChanges}
          onRejectChanges={handleRejectChanges}
          onSendMessage={handleSendMessage}
        />
      </div>
      <div className="chat-pane-container">
        <ChatPane
          messages={messages}
          onSendMessage={handleSendMessage}
          onUndo={undo}
          onReset={handleReset}
          canUndo={canUndo}
          isLoading={isLoading}
          suggestions={suggestions}
          onApplySuggestion={handleApplySuggestion}
          onDismissSuggestion={handleDismissSuggestion}
        />
      </div>
    </div>
  )
}
