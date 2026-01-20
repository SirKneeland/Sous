import { useState, useCallback } from 'react'
import { useRecipeState } from '../hooks/useRecipeState'
import { demoRecipe } from '../data/demoRecipe'
import { RecipeCanvas } from '../components/RecipeCanvas'
import { ChatPane } from '../components/ChatPane'
import { ChatMessage } from '../types/chat'
import { getStubbedLLMResponse, sendRejectionEvent } from '../services/llm'

export function DemoPage() {
  const {
    recipe,
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
      // Get LLM response (stubbed for Milestone 2)
      const response = await getStubbedLLMResponse(content, recipe)

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
      // Handle error
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
  }, [recipe, applyRecipePatches])

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
          onToggleIngredient={toggleIngredient}
          onMarkStepDone={markStepDone}
          onSetCurrentStep={setCurrentStep}
          pendingChangeSet={pendingChangeSet}
          onApproveChanges={handleApproveChanges}
          onRejectChanges={handleRejectChanges}
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
