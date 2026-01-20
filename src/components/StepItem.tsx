import { Step } from '../types/recipe'

interface StepItemProps {
  step: Step
  stepNumber: number
  isCurrent: boolean
  onMarkDone: (id: string) => void
  onSetCurrent: (id: string) => void
  isHighlighted?: boolean
  highlightType?: 'changed' | 'added'
}

export function StepItem({
  step,
  stepNumber,
  isCurrent,
  onMarkDone,
  onSetCurrent,
  isHighlighted = false,
  highlightType
}: StepItemProps) {
  const isDone = step.status === 'done'

  const handleClick = () => {
    if (isDone) return // Done steps are locked
    if (!isCurrent) {
      onSetCurrent(step.id)
    }
  }

  const handleMarkDone = (e: React.MouseEvent) => {
    e.stopPropagation()
    if (!isDone) {
      onMarkDone(step.id)
    }
  }

  const highlightClass = isHighlighted
    ? highlightType === 'added'
      ? 'highlight-added'
      : 'highlight-changed'
    : ''

  return (
    <div
      className={`step-item ${isDone ? 'done' : ''} ${isCurrent ? 'current' : ''} ${highlightClass}`}
      onClick={handleClick}
    >
      <div className="step-header">
        <span className="step-number">{stepNumber}</span>
        {isDone && <span className="step-badge">Done</span>}
      </div>
      <p className="step-text">{step.text}</p>
      {!isDone && isCurrent && (
        <button className="mark-done-btn" onClick={handleMarkDone}>
          Mark Complete
        </button>
      )}
      {isDone && (
        <div className="step-locked">
          <span className="lock-icon">Locked</span>
        </div>
      )}
    </div>
  )
}
