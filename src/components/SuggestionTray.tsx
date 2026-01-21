import { Suggestion } from '../types/chat'

interface SuggestionTrayProps {
  suggestions: Suggestion[]
  onApply: (suggestion: Suggestion) => void
  onDismiss: (suggestionId: string) => void
}

export function SuggestionTray({ suggestions, onApply, onDismiss }: SuggestionTrayProps) {
  if (suggestions.length === 0) {
    return null
  }

  return (
    <div className="suggestion-tray">
      <div className="suggestion-tray-header">
        <span className="suggestion-tray-title">Suggestions</span>
        <span className="suggestion-tray-hint">Review and apply if desired</span>
      </div>
      <div className="suggestion-tray-list">
        {suggestions.map(suggestion => (
          <div key={suggestion.id} className="suggestion-card">
            <div className="suggestion-content">
              <span className="suggestion-title">{suggestion.title}</span>
              {suggestion.rationale && (
                <p className="suggestion-rationale">{suggestion.rationale}</p>
              )}
            </div>
            <div className="suggestion-actions">
              <button
                className="suggestion-apply-btn"
                onClick={() => onApply(suggestion)}
              >
                Apply
              </button>
              <button
                className="suggestion-dismiss-btn"
                onClick={() => onDismiss(suggestion.id)}
              >
                Dismiss
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
