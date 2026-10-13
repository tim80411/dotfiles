export type IsDone = boolean

declare module 'claude-code' {
  interface PluginState {
    'auto-rename': { isDone: IsDone }
  }
}
