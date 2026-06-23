import { readFile, stat } from "node:fs/promises";

const files = {
  web: "www/index.html",
  publicWeb: "ios/App/App/public/index.html",
  capacitor: "capacitor.config.json",
  iosCapacitor: "ios/App/App/capacitor.config.json",
  plist: "ios/App/App/Info.plist",
  project: "ios/App/App.xcodeproj/project.pbxproj",
  appDelegate: "ios/App/App/AppDelegate.swift",
  icon: "ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png",
};

const contents = Object.fromEntries(
  await Promise.all(
    Object.entries(files).map(async ([key, path]) => [key, await readFile(path, key === "icon" ? null : "utf8")]),
  ),
);

const requireText = (key, needle) => {
  if (!contents[key].includes(needle)) {
    throw new Error(`${files[key]} is missing: ${needle}`);
  }
};

requireText("web", "<title>プリンセスロード</title>");
requireText("web", "次のタスクから進みましょう");
requireText("web", "宝箱");
requireText("web", "NativeAudioMode");
requireText("publicWeb", "<title>プリンセスロード</title>");
requireText("capacitor", "works.psychcraft.princessroad");
requireText("capacitor", '"appName": "プリンセスロード"');
requireText("iosCapacitor", "works.psychcraft.princessroad");
requireText("plist", "<string>プリンセスロード</string>");
requireText("project", "PRODUCT_BUNDLE_IDENTIFIER = works.psychcraft.princessroad;");
requireText("project", "CURRENT_PROJECT_VERSION = 3;");
requireText("appDelegate", "NativeAudioModePlugin");
requireText("appDelegate", "NativeHapticEngine");
requireText("appDelegate", "プリンセスロード タスクの記録");
requireText("web", "バックアップを書き出す");
requireText("web", "playTaskHaptic");
requireText("web", "保留にして移動");
requireText("web", "undo-task-move");
requireText("web", "ステップの設定");
requireText("web", "おしろ全体で共通");
requireText("web", "レッスンごとに指定");
requireText("web", "タスクごとに指定");
requireText("web", "すべてのタスクのステップ数");
requireText("web", "stepScope");
requireText("web", "castleStepCount");
requireText("web", ".sparkle-step-editor[hidden] { display: none; }");
requireText("web", "currentSparkleRemainingSeconds");
requireText("web", "stepCounts");
requireText("web", "このおしろで育てたい私");
requireText("web", "routeSparkleMinutesInput");
requireText("web", "state.currentView = \"home\"");
requireText("web", "lessonRingGeometry");
requireText("web", "金色の区切り：タスク");
requireText("web", "<strong>次のレッスン：</strong>");
requireText("web", "set-timer-ring-mode");
requireText("web", "タスクごと");
requireText("web", "レッスンごと");
requireText("web", "focusRingRemainingSeconds");
requireText("web", "lastTimerPersistedAt");
requireText("web", "timerDividerCache");
requireText("web", "now - lastTimerPersistedAt >= 5000");
requireText("web", 'state.currentView === "history"');
requireText("web", 'state.currentView !== "home"');
requireText("web", "historyDateSummary");
requireText("web", "updateHistoryDateDisplay");
requireText("web", "選択中の実施日");
requireText("web", ".field-label + .choice-grid");
requireText("web", "historyOutcomeLabel");
requireText("web", "おしろ完成</option>");
requireText("web", "history-pagination");
requireText("web", "記録される内容");
requireText("web", "自動で記録された内容");
requireText("web", 'data-template="work">仕事');
requireText("web", "今日の仕事を確認する");

if (contents.web !== contents.publicWeb) {
  throw new Error("www/index.html and ios/App/App/public/index.html are not synchronized");
}

const icon = await stat(files.icon);
if (icon.size < 5000) {
  throw new Error("App icon appears to be invalid");
}

console.log("Princess Road iOS assets and configuration are valid");
