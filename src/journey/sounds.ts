import { asset } from '../data'

/** Short sound effects of the Parcours mode and the voice that reads a question aloud. Everything is bundled or built in the browser. */
export type SoundName = 'tap' | 'right' | 'wrong' | 'star' | 'complete'

const FILES: Record<SoundName, string> = {
  tap: 'sounds/tap.wav',
  right: 'sounds/right.mp3',
  wrong: 'sounds/wrong.mp3',
  star: 'sounds/star.wav',
  complete: 'sounds/complete.wav',
}

const KEY = 'code-israel:sounds'
const players = new Map<SoundName, HTMLAudioElement>()

export function soundsOn() {
  try {
    return localStorage.getItem(KEY) !== 'off'
  } catch {
    return true
  }
}

export function setSounds(on: boolean) {
  try {
    localStorage.setItem(KEY, on ? 'on' : 'off')
  } catch {
    // Storage unavailable: the choice lasts until the page is reloaded.
  }
}

export function play(name: SoundName, delay = 0) {
  if (delay > 0) {
    setTimeout(() => play(name), delay)
    return
  }
  if (!soundsOn()) return
  let audio = players.get(name)
  if (!audio) {
    audio = new Audio(asset(FILES[name]))
    players.set(name, audio)
  }
  audio.currentTime = 0
  // The browser may refuse to play before the first tap: the sound is simply skipped.
  audio.play().catch(() => {})
}

export const canSpeak = () => 'speechSynthesis' in window

export function speak(text: string) {
  if (!canSpeak()) return
  speechSynthesis.cancel()
  const u = new SpeechSynthesisUtterance(text)
  u.lang = 'fr-FR'
  u.rate = 0.95
  speechSynthesis.speak(u)
}

export const stopSpeaking = () => {
  if (canSpeak()) speechSynthesis.cancel()
}
