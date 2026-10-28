/** Options of the Parcours mode, kept in the browser. */
const HEBREW = 'code-israel:hebrew'

/** Hebrew reading exercises in the lessons: off unless the learner turns them on. */
export function hebrewExercisesOn() {
  try {
    return localStorage.getItem(HEBREW) === 'on'
  } catch {
    return false
  }
}

export function setHebrewExercises(on: boolean) {
  try {
    localStorage.setItem(HEBREW, on ? 'on' : 'off')
  } catch {
    // Storage unavailable: the choice lasts until the page is reloaded.
  }
}
