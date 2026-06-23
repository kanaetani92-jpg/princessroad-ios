# GitHub Codespacesでの展開手順

ZIPをCodespacesのExplorerへドラッグしたあと、ターミナルで実行します。

```bash
cd /workspaces/プリンセスロードのリポジトリ名
unzip -o princess-road-ios-timer-performance-fix-full-20260624.zip
cp -a princess-road-ios-timer-performance-fix-full-20260624/. .
```

ZIP内のフォルダをそのまま新しいリポジトリとして使う場合:

```bash
unzip -o princess-road-ios-timer-performance-fix-full-20260624.zip
cd princess-road-ios-timer-performance-fix-full-20260624
npm ci
npm run validate
npx cap sync ios
```

GitHubへ反映する場合:

```bash
git status
git add .
git commit -m "Reduce timer rendering and storage load"
git push
```

Codemagicでは、最初に`ios-capacitor-check`、成功後に`ios-ipa-build`を実行します。
