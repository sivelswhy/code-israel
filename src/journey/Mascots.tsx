import { useEffect, useRef, useState } from 'react'
import type { Question } from '../data'

export type MascotName = 'rouli' | 'feo' | 'stoppy'
export type Mood = 'idle' | 'happy' | 'cheer' | 'sad' | 'thinking'

/** The three guides, drawn in SVG: Rouli the car, Féo the traffic light and Stoppy the stop sign. They blink, bounce and react to the mood. */
export function Mascot({ name, mood = 'idle', size = 96 }: { name: MascotName; mood?: Mood; size?: number }) {
  return (
    <svg className={`mascot mood-${mood}`} width={size} height={size} viewBox="0 0 100 100" role="img" aria-label={LABELS[name]}>
      {name === 'rouli' && <Car mood={mood} />}
      {name === 'feo' && <Light mood={mood} />}
      {name === 'stoppy' && <Stop mood={mood} />}
      {(mood === 'happy' || mood === 'cheer') && <Sparkles />}
    </svg>
  )
}

const LABELS: Record<MascotName, string> = { rouli: 'Rouli, la voiture', feo: 'Féo, le feu tricolore', stoppy: 'Stoppy, le panneau stop' }

function Eyes({ cx, cy, gap, mood, color = '#1d1d1f' }: { cx: number; cy: number; gap: number; mood: Mood; color?: string }) {
  const up = mood === 'thinking' ? -1.4 : 0
  return (
    <g className="eyes" fill={color}>
      {[-1, 1].map((s) =>
        mood === 'happy' || mood === 'cheer' ? (
          // Happy eyes are upside-down U's.
          <path key={s} d={`M${cx + s * gap - 3.4} ${cy + 1.4} q3.4 -5.4 6.8 0`} fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" />
        ) : (
          <g key={s}>
            <ellipse className="eye" cx={cx + s * gap} cy={cy} rx="3.6" ry="4.2" fill="#fff" />
            <circle className="pupil" cx={cx + s * gap + (mood === 'thinking' ? 1 : 0)} cy={cy + up} r="2.1" />
          </g>
        ),
      )}
    </g>
  )
}

function Mouth({ cx, cy, w, mood, color = '#1d1d1f' }: { cx: number; cy: number; w: number; mood: Mood; color?: string }) {
  switch (mood) {
    case 'cheer':
      return <path className="mouth-open" d={`M${cx - w} ${cy - 1} q${w} ${w * 1.5} ${w * 2} 0z`} fill="#7a1f2b" stroke={color} strokeWidth="1.4" strokeLinejoin="round" />
    case 'happy':
      return <path d={`M${cx - w} ${cy} q${w} ${w * 0.9} ${w * 2} 0`} fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" />
    case 'sad':
      return <path d={`M${cx - w * 0.8} ${cy + 2} q${w * 0.8} ${-w * 0.9} ${w * 1.6} 0`} fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" />
    case 'thinking':
      return <path d={`M${cx - w * 0.6} ${cy + 1} h${w * 1.2}`} stroke={color} strokeWidth="2.2" strokeLinecap="round" />
    default:
      return <path d={`M${cx - w * 0.7} ${cy} q${w * 0.7} ${w * 0.55} ${w * 1.4} 0`} fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" />
  }
}

function Car({ mood }: { mood: Mood }) {
  return (
    <g className="body">
      <ellipse cx="50" cy="90" rx="34" ry="4" fill="#000" opacity="0.12" />
      <path d="M24 42 Q28 14 50 14 Q72 14 76 42z" fill="#2b7bff" />
      <rect x="8" y="38" width="84" height="38" rx="15" fill="#2b7bff" />
      <rect x="27" y="21" width="46" height="25" rx="11" fill="#cfe8ff" />
      <Eyes cx={50} cy={31} gap={9} mood={mood} />
      <Mouth cx={50} cy={40} w={5} mood={mood} />
      {(mood === 'happy' || mood === 'cheer') && (
        <>
          <circle cx="35" cy="38" r="3.4" fill="#ff7a90" opacity="0.55" />
          <circle cx="65" cy="38" r="3.4" fill="#ff7a90" opacity="0.55" />
        </>
      )}
      <circle cx="17" cy="58" r="4.6" fill="#ffd23f" />
      <circle cx="83" cy="58" r="4.6" fill="#ffd23f" />
      <rect x="30" y="66" width="40" height="5" rx="2.5" fill="#1b5fd0" />
      <g className="wheels">
        <circle cx="28" cy="77" r="10" fill="#222" />
        <circle cx="28" cy="77" r="4" fill="#9a9aa0" />
        <circle cx="72" cy="77" r="10" fill="#222" />
        <circle cx="72" cy="77" r="4" fill="#9a9aa0" />
      </g>
      {mood === 'sad' && <Tear x={39} y={36} />}
    </g>
  )
}

function Light({ mood }: { mood: Mood }) {
  // The lamp that is lit shows how things are going: red when sad, orange when thinking, green when happy.
  const lit = mood === 'sad' ? 0 : mood === 'thinking' ? 1 : 2
  const lamps = [
    { cy: 26, on: '#ff3b30', off: '#5a2a2a' },
    { cy: 50, on: '#ffb020', off: '#5a4a2a' },
    { cy: 74, on: '#30d158', off: '#2a5a3a' },
  ]
  return (
    <g className="body">
      <ellipse cx="50" cy="94" rx="22" ry="3.5" fill="#000" opacity="0.12" />
      <rect x="44" y="84" width="12" height="10" rx="3" fill="#3a3a3f" />
      <rect x="27" y="4" width="46" height="84" rx="16" fill="#3a3a3f" />
      {lamps.map((l, i) => (
        <circle key={i} cx="50" cy={l.cy} r="11.5" fill={i === lit || (mood === 'idle' && i === 2) ? l.on : l.off} />
      ))}
      <g>
        <Eyes cx={50} cy={lamps[mood === 'idle' ? 2 : lit].cy - 2} gap={4.6} mood={mood} />
        <Mouth cx={50} cy={lamps[mood === 'idle' ? 2 : lit].cy + 5} w={3.4} mood={mood} />
      </g>
    </g>
  )
}

function Stop({ mood }: { mood: Mood }) {
  const pts = Array.from({ length: 8 }, (_, i) => {
    const a = (Math.PI / 4) * i + Math.PI / 8
    return `${50 + 45 * Math.cos(a)},${50 + 45 * Math.sin(a)}`
  }).join(' ')
  const inner = Array.from({ length: 8 }, (_, i) => {
    const a = (Math.PI / 4) * i + Math.PI / 8
    return `${50 + 39 * Math.cos(a)},${50 + 39 * Math.sin(a)}`
  }).join(' ')
  return (
    <g className="body">
      <polygon points={pts} fill="#e0231b" />
      <polygon points={inner} fill="none" stroke="#fff" strokeWidth="2.4" />
      <Eyes cx={50} cy={38} gap={10} mood={mood} color="#fff" />
      <Mouth cx={50} cy={54} w={6} mood={mood} color="#fff" />
      <text x="50" y="76" textAnchor="middle" fontSize="13" fontWeight="800" fill="#fff" fontFamily="system-ui, sans-serif">STOP</text>
      {mood === 'sad' && <Tear x={41} y={44} />}
    </g>
  )
}

function Tear({ x, y }: { x: number; y: number }) {
  return <path className="tear" d={`M${x} ${y} q-3 5 0 7 q3 -2 0 -7z`} fill="#6ec3ff" />
}

function Sparkles() {
  return (
    <g className="sparkles" fill="#ffc83d">
      {[[10, 14], [90, 10], [94, 46]].map(([x, y], i) => (
        <path key={i} className="sparkle" style={{ animationDelay: `${i * 0.3}s` }} d={`M${x} ${y - 6} l1.8 4.2 l4.2 1.8 l-4.2 1.8 l-1.8 4.2 l-1.8 -4.2 l-4.2 -1.8 l4.2 -1.8z`} />
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
