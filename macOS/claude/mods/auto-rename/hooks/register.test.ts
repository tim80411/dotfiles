import { expect, test } from 'claude-code/testing'

import { isPersonTyped } from './register'

test('only prompts the person typed start the rename', async () => {
  expect(isPersonTyped({ kind: 'composer' })).toBe(true)
  expect(isPersonTyped({ kind: 'bridge' })).toBe(true)
  expect(isPersonTyped({ kind: 'sdk' })).toBe(false)
  expect(isPersonTyped({ kind: 'task-notification' })).toBe(false)
})
