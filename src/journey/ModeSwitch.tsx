export type Mode = 'classic' | 'journey'

/** Switches between the classic home (practice, exam) and the Parcours (lessons, XP, daily review). */
export function ModeSwitch({ mode, onChange }: { mode: Mode; onChange: (m: Mode) => void }) {
  return (
    <div className="mode-switch" role="tablist" aria-label="Mode">
      {([['classic', 'Classique'], ['journey', 'Parcours']] as const).map(([m, label]) => (
        <button key={m} role="tab" aria-selected={mode === m} className={mode === m ? 'on' : ''} onClick={() => onChange(m)}>
          {label}
        </button>
      ))}
    </div>
  )
}
