import { useEffect, useRef, useState } from 'react'

const SCRIPT: Array<{ cmd: string; out: string[] }> = [
  {
    cmd: 'brew install cs4alhaider/tap/envhub',
    out: ['🍺  envhub 1.0.0 installed'],
  },
  {
    cmd: 'envhub scan ~/Developer --deep',
    out: ['Found 11 env files in 4 folders · 2.8s'],
  },
  {
    cmd: 'envhub get STRIPE_SECRET_KEY --project ./acme-api --mask',
    out: ['sk_live_••••••••'],
  },
  {
    cmd: 'envhub workspace move ./acme-api Backend',
    out: ['Moved “acme-api” to “Backend”.  # the app updates instantly'],
  },
]

/** A fake terminal that types the CLI story on loop once it scrolls into view. */
export default function Terminal() {
  const [lines, setLines] = useState<Array<{ text: string; kind: 'cmd' | 'out' }>>([])
  const [typing, setTyping] = useState('')
  const [started, setStarted] = useState(false)
  const host = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = host.current
    if (!el) return
    const io = new IntersectionObserver(
      es => es.forEach(e => e.isIntersecting && (setStarted(true), io.disconnect())),
      { threshold: 0.35 },
    )
    io.observe(el)
    return () => io.disconnect()
  }, [])

  useEffect(() => {
    if (!started) return
    let alive = true
    const timers: number[] = []
    const wait = (ms: number) => new Promise<void>(r => { timers.push(window.setTimeout(r, ms)) })

    ;(async () => {
      // Small initial pause, then loop the script forever.
      await wait(500)
      while (alive) {
        setLines([])
        for (const step of SCRIPT) {
          if (!alive) return
          // type the command
          for (let i = 1; i <= step.cmd.length; i++) {
            if (!alive) return
            setTyping(step.cmd.slice(0, i))
            await wait(step.cmd[i - 1] === ' ' ? 46 : 22)
          }
          await wait(320)
          setTyping('')
          setLines(prev => [...prev, { text: step.cmd, kind: 'cmd' as const }])
          await wait(240)
          for (const out of step.out) {
            setLines(prev => [...prev, { text: out, kind: 'out' as const }])
          }
          await wait(1100)
        }
        await wait(2400)
      }
    })()

    return () => {
      alive = false
      timers.forEach(clearTimeout)
    }
  }, [started])

  return (
    <div className="term" ref={host} aria-label="envhub CLI demo">
      <div className="term-bar" aria-hidden>
        <i style={{ background: '#ff5f57' }} />
        <i style={{ background: '#febc2e' }} />
        <i style={{ background: '#28c840' }} />
      </div>
      <div className="term-body">
        {lines.map((l, i) =>
          l.kind === 'cmd' ? (
            <div key={i}><span className="p">❯ </span>{l.text}</div>
          ) : (
            <div key={i} className={l.text.includes('#') ? 'c' : undefined}>{l.text}</div>
          ),
        )}
        <div>
          <span className="p">❯ </span>
          {typing}
          <span className="caret" />
        </div>
      </div>
    </div>
  )
}
