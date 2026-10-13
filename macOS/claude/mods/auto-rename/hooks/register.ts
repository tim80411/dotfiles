import { atom, read, update } from 'claude-code'
import type { PromptOrigin, Register } from 'claude-code'

import type { IsDone } from '../types'

const notYet: IsDone = false
const isDone = atom({ plugin: 'auto-rename', key: 'isDone' } as const, notYet)

// Only the person's own prompts count: not peers, schedules, plugins or task notices.
export const isPersonTyped = (origin: PromptOrigin): boolean =>
  origin.kind === 'composer' || origin.kind === 'bridge'

export const register: Register = on => {
  let hasFirstPrompt = false

  // A manual /rename wins: never overwrite a name the person chose.
  on('command.run', { command: 'rename' }, async ($, e, next) => {
    const result = await next(e)
    if (e.origin.kind !== 'plugin') {
      await update($, isDone, () => true).catch(() => undefined)
    }
    return result
  })

  on('prompt.submit', async ($, e, next) => {
    const result = await next(e)
    const isFirst = isPersonTyped(e.origin) && !hasFirstPrompt && result.drop === undefined
    if (isFirst && !(await read($, isDone).catch(() => true))) {
      hasFirstPrompt = true
    }
    return result
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (!hasFirstPrompt || e.reason !== 'answer' || (await read($, isDone).catch(() => true))) {
      return result
    }
    await update($, isDone, () => true)

    // /rename with no args names the session from the conversation; it must
    // run once the session is idle, outside this dispatch.
    $.clock.after(0, () => {
      void $.command.run({ command: 'rename' }).catch(() => update($, isDone, () => false))
    })

    return result
  })
}
