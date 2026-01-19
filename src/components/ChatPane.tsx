interface ChatPaneProps {
  onReset: () => void
}

export function ChatPane({ onReset }: ChatPaneProps) {
  return (
    <div className="chat-pane">
      <div className="chat-messages">
        <div className="chat-message assistant">
          <p>I'm Sous, your cooking companion! I'll help you through this recipe.</p>
          <p className="chat-hint">In Milestone 2, you'll be able to chat with me about substitutions, mistakes, and adjustments.</p>
        </div>
      </div>
      <div className="chat-input-area">
        <input
          type="text"
          className="chat-input"
          placeholder="Chat coming in Milestone 2..."
          disabled
        />
        <button className="reset-btn" onClick={onReset}>
          Reset Recipe
        </button>
      </div>
    </div>
  )
}
