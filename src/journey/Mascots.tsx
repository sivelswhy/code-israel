import { useEffect, useId, useRef, useState } from 'react'
import type { Question } from '../data'

export type MascotName = 'rouli' | 'feo' | 'stoppy'
export type Mood = 'idle' | 'happy' | 'cheer' | 'sad' | 'thinking'

/** The three guides, drawn in SVG: Rouli the car, Féo the traffic light and Stoppy the stop sign. They blink, bounce and react to the mood. */
export function Mascot({ name, mood = 'idle', size = 96 }: { name: MascotName; mood?: Mood; size?: number }) {
  return (
    <svg className={`mascot mood-${mood}`} width={size} height={size} viewBox="0 0 100 100" role="img" aria-label={LABELS[name]}>
      {name === 'rouli' && <Car mood={mood} />}
      {name === 'feo' && <Light mood={mood} />}
      {name === 'stoppy' && <Stop mood={mood} text={size >= 70} />}
      {mood === 'sad' && <Tear x={name === 'feo' ? 40 : 32} y={name === 'stoppy' ? 42 : 52} />}
      {(mood === 'happy' || mood === 'cheer') && <Sparkles />}
    </svg>
  )
}

const LABELS: Record<MascotName, string> = { rouli: 'Rouli, la voiture', feo: 'Féo, le feu tricolore', stoppy: 'Stoppy, le panneau stop' }

const INK = '#212121'

/** A pair of eyes of total width `w`, centred on (cx, cy): the same proportions as in the iPhone and Mac apps. */
function Eyes({ cx, cy, w, mood }: { cx: number; cy: number; w: number; mood: Mood }) {
  const d = w * 0.36
  const happy = mood === 'happy' || mood === 'cheer'
  const look = mood === 'thinking' ? { x: 0.07 * d * 2, y: -0.08 * d * 2 } : mood === 'sad' ? { x: 0, y: 0.07 * d * 2 } : { x: 0, y: 0 }
  return (
    <g>
      {[cx - w * 0.09 - d, cx + w * 0.09].map((x) =>
        happy ? (
          // Happy eyes: a small arch.
          <path key={x} d={`M${x} ${cy - 0.35 * d + 0.55 * d} Q${x + d / 2} ${cy - 0.35 * d - 0.25 * d} ${x + d} ${cy - 0.35 * d + 0.55 * d}`} fill="none" stroke={INK} strokeWidth={w * 0.07} strokeLinecap="round" />
        ) : (
          <g key={x}>
            <ellipse className="eye" cx={x + d / 2} cy={cy} rx={d / 2} ry={d * 0.575} fill="#fff" />
            <circle cx={x + d / 2 + look.x} cy={cy + look.y} r={d * 0.25} fill={INK} />
          </g>
        ),
      )}
    </g>
  )
}

/** A mouth of width `w` whose frame starts at `top`. */
function Mouth({ cx, top, w, mood, color = INK }: { cx: number; top: number; w: number; mood: Mood; color?: string }) {
  const h = w * 0.5
  const x0 = cx - w / 2
  switch (mood) {
    case 'cheer':
    case 'happy':
      return (
        <>
          <path className={mood === 'cheer' ? 'mouth-open' : undefined} d={`M${x0} ${top + h * 0.1} Q${cx} ${top + h * 1.8} ${x0 + w} ${top + h * 0.1}z`} fill={color === '#fff' ? '#333' : color} />
          <rect x={cx - w * 0.25} y={top + h * 0.74} width={w * 0.5} height={h * 0.22} rx={h * 0.11} fill="#ff7380" />
        </>
      )
    case 'sad':
      return <path d={`M${x0} ${top + h * 0.75} Q${cx} ${top - h * 0.1} ${x0 + w} ${top + h * 0.75}`} fill="none" stroke={color} strokeWidth={w * 0.1} strokeLinecap="round" />
    case 'thinking':
      return <circle cx={cx + w * 0.15} cy={top + h / 2} r={w * 0.15} fill="none" stroke={color} strokeWidth={w * 0.09} />
    default:
      return <path d={`M${x0} ${top + h * 0.3} Q${cx} ${top + h * 0.95} ${x0 + w} ${top + h * 0.3}`} fill="none" stroke={color} strokeWidth={w * 0.1} strokeLinecap="round" />
  }
}

/** Rouli, the car: a rounded body, a windscreen where the eyes are, and the mouth on the bonnet. */
function Car({ mood }: { mood: Mood }) {
  const id = useId()
  const glow = mood === 'cheer' ? 1 : mood === 'sad' ? 0.25 : 0.85
  return (
    <g className="body">
      <defs>
        <linearGradient id={`${id}-b`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#408cff" />
          <stop offset="1" stopColor="#0d54d9" />
        </linearGradient>
        <linearGradient id={`${id}-w`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#d9f2ff" />
          <stop offset="1" stopColor="#9ed1fa" />
        </linearGradient>
      </defs>
      <ellipse cx="50" cy="95" rx="36" ry="3" fill="#000" opacity="0.12" />
      <rect x="9" y="73" width="14" height="20" rx="4" fill={INK} />
      <rect x="77" y="73" width="14" height="20" rx="4" fill={INK} />
      <rect x="4" y="26" width="92" height="64" rx="22" fill={`url(#${id}-b)`} />
      <rect x="14" y="27" width="72" height="34" rx="17" fill={`url(#${id}-w)`} />
      <Eyes cx={50} cy={44} w={50} mood={mood} />
      {(mood === 'happy' || mood === 'cheer') && (
        <>
          <circle cx="21.25" cy="60" r="5" fill="#ff808c" opacity="0.5" />
          <circle cx="78.75" cy="60" r="5" fill="#ff808c" opacity="0.5" />
        </>
      )}
      <Mouth cx={50} top={65.5} w={26} mood={mood} />
      <circle cx="16" cy="70" r="6" fill="#ffcc00" opacity={glow} stroke="#fff" strokeOpacity="0.7" strokeWidth="1" />
      <circle cx="84" cy="70" r="6" fill="#ffcc00" opacity={glow} stroke="#fff" strokeOpacity="0.7" strokeWidth="1" />
    </g>
  )
}

/** Féo, the traffic light: the lit lamp is big and has the face. Red when sad, green when happy, orange otherwise. */
function Light({ mood }: { mood: Mood }) {
  const lit = mood === 'sad' ? 0 : mood === 'happy' || mood === 'cheer' ? 2 : 1
  const colors = ['#f23833', '#ff9e1a', '#33c759']
  return (
    <g className="body">
      <ellipse cx="50" cy="98" rx="24" ry="2.5" fill="#000" opacity="0.12" />
      <rect x="21" y="3" width="58" height="94" rx="20" fill="#333" />
      <rect x="21" y="3" width="58" height="94" rx="20" fill="none" stroke="#525252" strokeWidth="2" />
      {colors.map((color, i) => {
        const on = i === lit
        const d = on ? 42 : 20
        const cy = 50 + (i - 1) * 30 + (i === 0 && lit !== 0 ? -3 : i === 2 && lit !== 2 ? 3 : 0)
        // The face: eyes, a small gap, then the mouth, centred in the lamp.
        const eyesH = 0.3395 * d
        const total = eyesH + 0.04 * d + 0.18 * d
        const top = cy + 0.02 * d - total / 2
        return (
          <g key={i}>
            <circle cx="50" cy={cy} r={d / 2} fill={color} opacity={on ? 1 : 0.28} style={on ? { filter: `drop-shadow(0 0 4px ${color})` } : undefined} />
            {on && (
              <>
                <Eyes cx={50} cy={top + eyesH / 2} w={d * 0.82} mood={mood} />
                <Mouth cx={50} top={top + eyesH + 0.04 * d} w={d * 0.36} mood={mood} />
              </>
            )}
          </g>
        )
      })}
    </g>
  )
}

/** Stoppy, the stop sign. The word STOP is only written when the sign is big enough to read it. */
function Stop({ mood, text }: { mood: Mood; text: boolean }) {
  const id = useId()
  const octagon = (size: number, c: number) => {
    const o = (100 - size) / 2
    const a = o + c
    const b = o + size - c
    const e = o + size
    return `${a},${o} ${b},${o} ${e},${a} ${e},${b} ${b},${e} ${a},${e} ${o},${b} ${o},${a}`
  }
  const eyesH = 0.4140 * 50
  const textH = text ? 3 + 15.5 : 0
  const total = eyesH + 3 + 12 + textH
  const top = 51 - total / 2
  return (
    <g className="body">
      <defs>
        <linearGradient id={`${id}-r`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#f24540" />
          <stop offset="1" stopColor="#c71a1f" />
        </linearGradient>
      </defs>
      <ellipse cx="50" cy="97" rx="30" ry="2.5" fill="#000" opacity="0.12" />
      <polygon points={octagon(92, 92 * 0.29)} fill={`url(#${id}-r)`} />
      <polygon points={octagon(80, 80 * 0.29)} fill="none" stroke="#fff" strokeWidth="3.5" strokeLinejoin="miter" />
      <Eyes cx={50} cy={top + eyesH / 2} w={50} mood={mood} />
      <Mouth cx={50} top={top + eyesH + 3} w={24} mood={mood} color="#fff" />
      {text && (
        <text x="50" y={top + total - 3} textAnchor="middle" fontSize="13" fontWeight="800" fill="#fff" fontFamily="inherit">STOP</text>
      )}
    </g>
  )
}

function Tear({ x, y }: { x: number; y: number }) {
  return <path className="tear" d={`M${x} ${y} q-3 5 0 7 q3 -2 0 -7z`} fill="#6ec3ff" />
}

/** Three four-pointed stars around the character, as in the apps. */
function Sparkles() {
  return (
    <g className="sparkles" fill="#ffd60a">
      {[[8, 30, 7], [92, 20, 9.5], [55, 4, 7]].map(([x, y, r], i) => (
        <path key={i} className="sparkle" style={{ animationDelay: `${i * 0.3}s` }} d={`M${x} ${y - r} Q${x} ${y} ${x + r} ${y} Q${x} ${y} ${x} ${y + r} Q${x} ${y} ${x - r} ${y} Q${x} ${y} ${x} ${y - r}z`} />
      ))}
    </g>
  )
}

/** A short rule taken from the official explanations, told by the characters. */
export function tipFrom(pool: Question[]): string {
  const candidates = pool.map((q) => q.e).filter((e): e is string => !!e && e.length >= 40 && e.length <= 170)
  const e = candidates[Math.floor(Math.random() * candidates.length)]
  return e ? `Le saviez-vous ? ${e}` : 'Gardez toujours vos distances de sécurité !'
}

/** A guide you can tap: it cheers and tells a rule. `message` is what it says before being tapped. */
export function TalkingMascot({ name, mood = 'idle', size = 84, message, pool, onTap }: { name: MascotName; mood?: Mood; size?: number; message?: string; pool?: Question[]; onTap?: () => void }) {
  const [reaction, setReaction] = useState<Mood | null>(null)
  const [tip, setTip] = useState<string | null>(null)
  const timers = useRef<number[]>([])
  useEffect(() => () => timers.current.forEach(clearTimeout), [])

  const poke = () => {
    onTap?.()
    timers.current.forEach(clearTimeout)
    setReaction('cheer')
    if (pool?.length) setTip(tipFrom(pool))
    timers.current = [window.setTimeout(() => setReaction(null), 1600), window.setTimeout(() => setTip(null), 6500)]
  }

  const said = tip ?? message
  return (
    <div className="talking">
      {said && <p className="bubble" role="status">{said}</p>}
      <button className="mascot-btn" onClick={poke} aria-label={`${LABELS[name]} : toucher pour un conseil`}>
        <Mascot name={name} mood={reaction ?? mood} size={size} />
      </button>
    </div>
  )
}

/** Every character in every mood. Shown instead of the app with `?mascots` in the address, to compare with the iPhone and Mac apps. */
export function MascotGallery() {
  const moods: [string, Mood][] = [['Au repos', 'idle'], ['Content', 'happy'], ['Ravi', 'cheer'], ['Triste', 'sad'], ['Réfléchit', 'thinking']]
  const names: MascotName[] = ['rouli', 'feo', 'stoppy']
  return (
    <main className="page">
      <div style={{ display: 'grid', gridTemplateColumns: '80px repeat(3, 120px)', gap: '18px 28px', alignItems: 'center', justifyContent: 'center' }}>
        <span />
        {names.map((n) => <strong key={n}>{n}</strong>)}
        {moods.map(([label, mood]) => (
          <div key={mood} style={{ display: 'contents' }}>
            <span className="muted small" style={{ textAlign: 'right' }}>{label}</span>
            {names.map((n) => <Mascot key={n} name={n} mood={mood} size={120} />)}
          </div>
        ))}
      </div>
    </main>
  )
}
