import { useState, useCallback } from 'react'
import { useRecipeState } from '../hooks/useRecipeState'
import { demoRecipe } from '../data/demoRecipe'
import { RecipeCanvas } from '../components/RecipeCanvas'
import { ChatPane } from '../components/ChatPane'
import { ChatMessage } from '../types/chat'
import { sendRejectionEvent } from '../services/llm'
import { LLMResponse } from '../types/recipe'

interface ChatApiError {
  error: {
    message: string
    retryable: boolean
  }
}

type ChatApiResponse = LLMResponse | ChatApiError

function isErrorResponse(response: ChatApiResponse): response is ChatApiError {
  return 'error' in response
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
  const [isLoading, setIsLoading] = useState(false)

  const handleSendMessage = useCallback(async (content: string) => {
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
        body: JSON.stringify({ userMessage: content, recipe, hasRecipe })
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

      // Apply patches to recipe
      if (response.patches.length > 0) {
        const result = applyRecipePatches(response.patches)

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
  }, [recipe, hasRecipe, applyRecipePatches])

  const handleReset = useCallback(() => {
    resetRecipe()
    setMessages([])
  }, [resetRecipe])

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
        />
      </div>
    </div>
  )
}
