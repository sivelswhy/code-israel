import { useEffect, useMemo, useState } from 'react'
import './journey.css'
import { CATEGORIES, type Category, type Question } from '../data'
import { Rings } from '../App'
import type { Progress } from '../store'
import {
  adaptivePick, buildPath, canOpenChest, completedCount, currentLesson, dueQuestionIDs, isClaimed, isDone, isGold, isUnlocked, level, localDay, memoryStrength,
  QUESTS, questProgress, questsOf, RULES, streakOf, xpInLevel, xpToday, type ChestReward, type JourneyProgress, type JourneyUnit, type Lesson, type QuestKind,
} from './engine'
import { TalkingMascot } from './Mascots'
import { canNotify, remindersOn, setReminders } from './reminders'
import { play } from './sounds'

const COLORS: Record<Category, string> = { rules: 'var(--sign-blue)', safety: 'var(--sign-red)', signs: '#d97706', vehicle: 'var(--sign-green)' }
const SHORT: Record<Category, string> = { rules: 'Code', safety: 'Sécurité', signs: 'Panneaux', vehicle: 'Véhicule' }

export interface StartLesson {
  title: string
  lesson: Lesson | null
  questions: Question[]
  color: string
  /** False for a free training, which is not the daily review. */
  countsAsReview: boolean
}

interface Props {
  pool: Question[]
  progress: Progress
  freezeNotice: number
  onDismissNotice: () => void
  onStart: (s: StartLesson) => void
  onMatch: () => void
  onClaim: (quest: QuestKind) => void
  onChest: () => ChestReward | null
  switcher: React.ReactNode
}

/** The Parcours: a path of short lessons per theme, XP, a level, daily quests and a daily review of the questions missed. */
export function Journey({ pool, progress, freezeNotice, onDismissNotice, onStart, onMatch, onClaim, onChest, switcher }: Props) {
  const j = progress.journey
  const units = useMemo(() => buildPath(pool), [pool])
  const byId = useMemo(() => new Map(pool.map((q) => [q.id, q])), [pool])
  const [theme, setTheme] = useState<Category>('rules')
  const unit = units.find((u) => u.category === theme) ?? units[0]
  const current = unit ? currentLesson(j, unit) : undefined
  const questions = (ids: string[]) => ids.map((id) => byId.get(id)).filter((x): x is Question => !!x)

  useEffect(() => {
    // Open the path where the learner stopped.
    if (current) document.getElementById(`node-${current.id}`)?.scrollIntoView({ block: 'center', behavior: 'smooth' })
  }, [theme]) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <main className="page journey">
      <div className="journey-switch">{switcher}</div>
      <div className="journey-main">
        <div className="chips" role="tablist" aria-label="Thème">
          {(Object.keys(CATEGORIES) as Category[]).filter((c) => units.some((u) => u.category === c)).map((c) => (
            <button key={c} role="tab" aria-selected={theme === c} className={`chip ${theme === c ? 'on' : ''}`} style={{ ['--chip' as string]: COLORS[c] }} onClick={() => setTheme(c)}>
              {SHORT[c]}
            </button>
          ))}
        </div>
        {unit && (
          <>
            <Banner unit={unit} j={j} />
            <ol className="path">
              {unit.lessons.map((lesson, i) => {
                const unlocked = isUnlocked(j, lesson, unit)
                const isCurrent = current?.id === lesson.id
                const result = j.lessons[lesson.id]
                const gold = isGold(j, lesson)
                const side = Math.sin(i * 0.9) >= 0 ? 'left' : 'right'
                return (
                  <li key={lesson.id} id={`node-${lesson.id}`} className="path-row" style={{ ['--i' as string]: i }}>
                    <div className="path-node-wrap">
                      <button
                        className={`path-node ${gold ? 'gold' : result ? 'done' : isCurrent ? 'current' : unlocked ? 'open' : 'locked'}`}
                        style={{ ['--node' as string]: COLORS[unit.category] }}
                        disabled={!unlocked}
                        onClick={() => onStart({ title: `${CATEGORIES[unit.category].label} · leçon ${lesson.number}`, lesson, questions: questions(lesson.questionIDs), color: COLORS[unit.category], countsAsReview: true })}
                        aria-label={`Leçon ${lesson.number}${unlocked ? '' : ', verrouillée'}${result ? `, ${result.stars} étoile${result.stars > 1 ? 's' : ''}${gold ? ', dorée' : ''}` : isCurrent ? ', à faire' : ''}`}
                      >
                        <span aria-hidden="true">{gold ? '🏆' : result ? '✓' : isCurrent ? '▶' : unlocked ? '★' : '🔒'}</span>
                      </button>
                      {result && (
                        <span className="path-stars" aria-hidden="true">
                          {[1, 2, 3].map((n) => <span key={n} className={n <= result.stars ? 'on' : ''}>★</span>)}
                        </span>
                      )}
                    </div>
                    {isCurrent && (
                      <div className={`path-guide ${side}`}>
                        <TalkingMascot name="rouli" mood="happy" size={76} message="Prêt ? C’est parti !" pool={pool} />
                      </div>
                    )}
                  </li>
                )
              })}
            </ol>
          </>
        )}
      </div>
      <aside className="journey-side">
        <Summary
          j={j}
          progress={progress}
          freezeNotice={freezeNotice}
          onDismissNotice={onDismissNotice}
          onReview={() => onStart({ title: 'Révision du jour', lesson: null, questions: questions(dueQuestionIDs(j)).slice(0, RULES.reviewSize), color: 'var(--sign-red)', countsAsReview: true })}
          onTraining={() => onStart({ title: 'Entraînement adapté', lesson: null, questions: questions(adaptivePick(j, pool.map((q) => q.id))), color: 'var(--ring-blue)', countsAsReview: false })}
          onMatch={onMatch}
          onClaim={onClaim}
          onChest={onChest}
        />
      </aside>
    </main>
  )
}

function Banner({ unit, j }: { unit: JourneyUnit; j: JourneyProgress }) {
  const done = completedCount(j, unit)
  return (
    <section className="unit-banner" style={{ background: COLORS[unit.category] }}>
      <h2>{CATEGORIES[unit.category].label}</h2>
      <p>{CATEGORIES[unit.category].hint}</p>
      <div className="unit-bar">
        <div className="track"><div className="track-fill" style={{ transform: `scaleX(${Math.max(0.03, done / unit.lessons.length)})`, background: '#fff' }} /></div>
        <span className="mono">{done}/{unit.lessons.length}</span>
      </div>
    </section>
  )
}

interface SummaryProps {
  j: JourneyProgress
  progress: Progress
  freezeNotice: number
  onDismissNotice: () => void
  onReview: () => void
  onTraining: () => void
  onMatch: () => void
  onClaim: (q: QuestKind) => void
  onChest: () => ChestReward | null
}

function Summary({ j, progress, freezeNotice, onDismissNotice, onReview, onTraining, onMatch, onClaim, onChest }: SummaryProps) {
  const today = xpToday(j)
  const days = streakOf(progress.daily, j.frozenDays)
  const due = dueQuestionIDs(j)
  const memory = memoryStrength(j)
  const quests = questsOf()
  const [reward, setReward] = useState<ChestReward | null>(null)
  const [reminders, setReminderState] = useState(remindersOn())
  const hour = Object.keys(j.hours).length ? Number(Object.entries(j.hours).sort((a, b) => b[1] - a[1] || Number(a[0]) - Number(b[0]))[0][0]) : 19
  const chestDone = j.today.day === localDay(new Date()) && j.today.chestOpened

  return (
    <div className="summary">
      <section className="card goal-card">
        <Rings rings={[{ value: Math.min(1, today / RULES.dailyXP), color: 'var(--ring-orange)' }]} size={84} stroke={12} />
        <div>
          <h3>Objectif du jour</h3>
          <p className="muted">{Math.min(today, RULES.dailyXP)} / {RULES.dailyXP} XP</p>
          {days > 0 && <p className="streak">🔥 {days} jour{days > 1 ? 's' : ''} d’affilée</p>}
        </div>
        <div className="goal-feo"><TalkingMascot name="feo" mood={today >= RULES.dailyXP ? 'cheer' : today > 0 ? 'thinking' : 'sad'} size={60} pool={[]} /></div>
      </section>

      <section className="card">
        <div className="level-row">
          <strong style={{ color: 'var(--ring-blue)' }}>🏆 Niveau {level(j)}</strong>
          <span className="muted mono">{j.xp} XP</span>
        </div>
        <div className="track"><div className="track-fill" style={{ transform: `scaleX(${Math.max(0.03, xpInLevel(j) / RULES.xpPerLevel)})`, background: 'var(--ring-blue)' }} /></div>
        <p className="muted small">{RULES.xpPerLevel - xpInLevel(j)} XP avant le niveau {level(j) + 1}</p>
      </section>

      <div className="pills">
        <Pill icon="🔥" value={String(days)} label={days > 1 ? 'jours' : 'jour'} />
        <Pill icon="❄️" value={String(j.freezes)} label={j.freezes > 1 ? 'gels' : 'gel'} />
        <Pill icon="🧠" value={memory === null ? '–' : `${Math.round(memory * 100)} %`} label="mémoire" />
      </div>

      {freezeNotice > 0 && (
        <section className="card notice" role="status">
          <span>❄️ {freezeNotice > 1 ? `${freezeNotice} gels de série ont sauvé votre série.` : 'Un gel de série a sauvé votre série hier.'}</span>
          <button className="icon-btn" onClick={onDismissNotice} aria-label="Fermer">✕</button>
        </section>
      )}

      <section className="card quests">
        <h3>🎯 Quêtes du jour</h3>
        {quests.map((quest) => {
          const done = isDone(j, quest)
          const claimed = isClaimed(j, quest)
          const value = questProgress(j, quest)
          return (
            <div className="quest" key={quest}>
              <span className={`quest-icon ${claimed ? 'claimed' : ''}`} aria-hidden="true">{claimed ? '✓' : QUEST_ICON[quest]}</span>
              <div>
                <strong>{QUESTS[quest].title}</strong>
                <div className="track"><div className="track-fill" style={{ transform: `scaleX(${Math.max(0.04, value / QUESTS[quest].target)})`, background: claimed ? 'var(--ring-green)' : 'var(--ring-blue)' }} /></div>
              </div>
              {claimed ? <span className="mark ok">✓</span> : done ? (
                <button className="claim" onClick={() => { onClaim(quest); play('star') }}>+{RULES.questXP} XP</button>
              ) : <span className="muted small mono">{value}/{QUESTS[quest].target}</span>}
            </div>
          )
        })}
        <div className="chest">
          <span className="chest-icon" aria-hidden="true">{chestDone ? '📭' : '🎁'}</span>
          <div>
            <strong>Coffre du jour</strong>
            <small className="muted">{chestDone ? 'Ouvert. Revenez demain !' : canOpenChest(j) ? `Prêt : +${RULES.chestXP} XP à gagner.` : 'Récupérez les 3 quêtes pour l’ouvrir.'}</small>
          </div>
          {canOpenChest(j) && (
            <button className="claim gold" onClick={() => { const r = onChest(); if (r) { setReward(r); play('complete') } }}>Ouvrir</button>
          )}
        </div>
        {reward && (
          <p className="reward" role="status">
            🎉 Coffre ouvert : +{reward.xp} XP{reward.freeze ? ' et un gel de série pour sauver un jour manqué.' : '.'}
          </p>
        )}
      </section>

      <button className="action-card" onClick={onReview} disabled={!due.length}>
        <span className="action-icon" style={{ background: due.length ? 'var(--sign-red)' : 'var(--new)' }} aria-hidden="true">🔁</span>
        <span>
          <strong>Révision du jour</strong>
          <small>{due.length ? `${due.length} question${due.length > 1 ? 's' : ''} à revoir` : 'Rien à revoir : revenez demain.'}</small>
        </span>
      </button>
      <button className="action-card" onClick={onTraining}>
        <span className="action-icon" style={{ background: 'var(--ring-blue)' }} aria-hidden="true">🎯</span>
        <span>
          <strong>Entraînement adapté</strong>
          <small>{RULES.adaptiveSize} questions choisies pour que vous en réussissiez environ {Math.round(RULES.targetSuccess * 100)} %.</small>
        </span>
      </button>
      <button className="action-card" onClick={onMatch}>
        <span className="action-icon" style={{ background: 'var(--ring-green)' }} aria-hidden="true">🧩</span>
        <span>
          <strong>Jeu des panneaux</strong>
          <small>Associez {RULES.matchPairs} panneaux à leur sens : +{RULES.xpMatch} XP.</small>
        </span>
      </button>

      {canNotify() && (
        <label className="card reminders">
          <span>
            <strong>🔔 Rappels</strong>
            <small className="muted">Un rappel à {hour} h, l’heure où vous étudiez d’habitude, et une alerte le soir si votre série est en danger. Ils s’affichent tant que le site est ouvert dans un onglet.</small>
          </span>
          <input type="checkbox" role="switch" checked={reminders} onChange={async (e) => setReminderState(await setReminders(e.target.checked))} />
        </label>
      )}
      <p className="muted small">Les questions ratées reviennent quand la mémoire s’affaiblit : après environ 1 jour, puis de plus en plus tard si vous les réussissez.</p>
    </div>
  )
}

const QUEST_ICON: Record<QuestKind, string> = { xp: '⚡', lessons: '🏁', perfect: '⭐', run: '🔥', review: '🔁' }

function Pill({ icon, value, label }: { icon: string; value: string; label: string }) {
  return (
    <div className="pill">
      <span aria-hidden="true">{icon}</span>
      <strong className="mono">{value}</strong>
      <small>{label}</small>
    </div>
  )
}
