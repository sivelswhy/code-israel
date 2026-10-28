import { habitualHour, localDay, streakAlert, type JourneyProgress } from './engine'

/**
 * Reminders: one a day at the hour the learner usually studies, and a warning in the evening when the streak is at risk.
 * A web page cannot wake itself up: they are shown as long as the site is open in a tab or an installed app.
 */
const KEY = 'code-israel:reminders'
let timers: number[] = []

export const canNotify = () => 'Notification' in window

export function remindersOn() {
  try {
    return canNotify() && Notification.permission === 'granted' && localStorage.getItem(KEY) === 'on'
  } catch {
    return false
  }
}

/** Turns the reminders on (asking for permission the first time) or off. Returns whether they are on. */
export async function setReminders(on: boolean): Promise<boolean> {
  let enabled = on
  if (on) enabled = canNotify() && (Notification.permission === 'granted' || (await Notification.requestPermission()) === 'granted')
  try {
    localStorage.setItem(KEY, enabled ? 'on' : 'off')
  } catch {
    // Storage unavailable: the choice lasts until the page is reloaded.
  }
  return enabled
}

const nextDaily = (hour: number, now: Date) => {
  const d = new Date(now)
  d.setHours(hour, 0, 0, 0)
  if (d <= now) d.setDate(d.getDate() + 1)
  return d
}

async function show(title: string, body: string) {
  try {
    const registration = await navigator.serviceWorker?.getRegistration()
    if (registration) await registration.showNotification(title, { body, icon: `${import.meta.env.BASE_URL}icon-192.png` })
    else new Notification(title, { body })
  } catch {
    // Notifications blocked since: nothing to show.
  }
}

/** Plans the notifications again from the current progress. */
export function scheduleReminders(journey: JourneyProgress, daily: Record<string, number>, streak: number) {
  timers.forEach(clearTimeout)
  timers = []
  if (!remindersOn()) return
  const now = new Date()
  const plan = (when: Date, title: string, body: string, again?: () => void) => {
    const delay = when.getTime() - now.getTime()
    // setTimeout cannot wait more than about 24 days: the page plans again whenever it is opened.
    if (delay > 0 && delay < 2 ** 31 - 1) timers.push(window.setTimeout(() => { void show(title, body); again?.() }, delay))
  }
  const replan = () => scheduleReminders(journey, daily, streak)
  plan(nextDaily(habitualHour(journey.hours), now), 'C’est l’heure de votre leçon', 'Quelques minutes suffisent pour avancer vers le permis.', replan)
  if (streak > 0) plan(streakAlert(now, daily[localDay(now)] !== undefined), 'Votre série est en danger', 'Une leçon avant minuit suffit pour la garder.')
}
