import type { KeyboardEvent } from 'react'

/** The arrow keys move from one answer to the next (Tab and Enter already work on buttons). True when the key was used. */
export function moveBetweenAnswers(e: KeyboardEvent<HTMLElement>): boolean {
  if (!['ArrowDown', 'ArrowRight', 'ArrowUp', 'ArrowLeft'].includes(e.key)) return false
  const buttons = Array.from(e.currentTarget.querySelectorAll<HTMLButtonElement>('button:not(:disabled)'))
  if (!buttons.length) return false
  e.preventDefault()
  const step = e.key === 'ArrowDown' || e.key === 'ArrowRight' ? 1 : -1
  const at = buttons.indexOf(document.activeElement as HTMLButtonElement)
  const to = at === -1 ? (step > 0 ? 0 : buttons.length - 1) : (at + step + buttons.length) % buttons.length
  buttons[to].focus()
  return true
}

/** Puts the keyboard on the first answer of a new question, so that the arrows work straight away. */
export function focusFirstAnswer(list: HTMLElement | null) {
  list?.querySelector<HTMLButtonElement>('button:not(:disabled)')?.focus({ preventScroll: true })
}

/** True when the key is Enter on an answer that is already the chosen one: pressing it again confirms. */
export function confirmsAnswer(e: KeyboardEvent<HTMLElement>): boolean {
  return e.key === 'Enter' && (e.target as HTMLElement).getAttribute?.('aria-pressed') === 'true'
}
