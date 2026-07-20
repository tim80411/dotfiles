#!/usr/bin/env osascript -l JavaScript
// pbwatch.js — 監看本機剪貼簿，出現圖片就自動 pbpush 到 mini 剪貼簿
// 讓「Cmd+Ctrl+Shift+4 截圖 → 遠端 (mosh+tmux) Claude Code 按 Ctrl+V」全自動接通。
//
// 由 launchd (com.local.pbwatch) 以單一常駐 process 執行：
//   /usr/bin/osascript -l JavaScript ~/bin/pbwatch.js
// 設計：
// - 單一 process 輪詢 NSPasteboard.changeCount（秒級、成本趨近零），
//   不必每秒 fork osascript。
// - 只在「剪貼簿內容變了、且是圖片 (PNG/TIFF flavor)」時才推送；文字複製完全略過。
// - 推送邏輯不重複實作，直接呼叫 ~/.zsh/pbpush.zsh 的 pbpush（單一事實來源）。
// - mini 離線：pbpush 內建 ConnectTimeout 快速失敗，這裡記 log 後繼續（不 crash、不重試風暴）。
// - pbpush 不動「本機」剪貼簿，不會觸發自身 → 無迴圈風險。
ObjC.import('AppKit');
ObjC.import('Foundation');

const app = Application.currentApplication();
app.includeStandardAdditions = true;

const pb = $.NSPasteboard.generalPasteboard;
// JXA 把 NSInteger 橋接成字串，一律以字串比較避免型別坑
let last = String(pb.changeCount);

function log(msg) {
  // console.log 走 stderr，由 plist 導到 ~/Library/Logs/pbwatch.log
  console.log(new Date().toISOString() + ' ' + msg);
}

log('pbwatch 啟動（changeCount=' + last + '）');

while (true) {
  $.NSThread.sleepForTimeInterval(1.0);
  const c = String(pb.changeCount);
  if (c === last) continue;
  last = c;

  const t = pb.availableTypeFromArray($([$.NSPasteboardTypePNG, $.NSPasteboardTypeTIFF]));
  if (t.isNil()) continue; // 非圖片（文字等），略過

  try {
    const out = app.doShellScript("/bin/zsh -c 'source ~/.zsh/pbpush.zsh && pbpush'");
    log(out);
  } catch (e) {
    log('pbpush 失敗（mini 離線？）: ' + e.message);
  }
}
