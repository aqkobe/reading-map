#!/usr/bin/env bash
set -e
REPO="reading-map"
TOKEN="${GITHUB_TOKEN:?请先 export GITHUB_TOKEN=ghp_xxx}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"; [ -f index.html ] || { echo "目录里找不到 index.html"; exit 1; }

echo "==> 校验 token 并获取账号"
WHO=$(curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/user)
OWNER=$(printf '%s' "$WHO" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('login',''))
except: print('')" 2>/dev/null)
[ -n "$OWNER" ] || { echo "❌ token 无效或无网络：$WHO"; exit 1; }
echo "    账号: $OWNER"

echo "==> 检查仓库是否存在"
EXIST=$(curl -sS -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/repos/$OWNER/$REPO)
echo "    repos/$OWNER/$REPO → HTTP=$EXIST"
if [ "$EXIST" != "200" ]; then
  echo "❌ 仓库不存在。请到 https://github.com/new 手动创建："
  echo "   Repository name: $REPO  → Public → 不要勾 Add README → Create repository"
  echo "   创建后重新运行本脚本。"; exit 1
fi

echo "==> git 初始化并提交"
git init -q
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "❌ git 初始化失败，当前目录: $DIR"; ls -la; exit 1; }
git add -A
git -c user.email="${GIT_EMAIL:-me@example.com}" -c user.name="${GIT_NAME:-deploy}" commit -q -m "deploy" || echo "（无新内容需提交，继续推送）"
git branch -M main
git remote remove origin 2>/dev/null || true
git remote add origin "https://$TOKEN@github.com/$OWNER/$REPO.git"
git push -u origin main --force

echo "==> 开启 GitHub Pages"
curl -sS -o /dev/null -w "pages HTTP=%{http_code}\n" -X POST \
  -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/$OWNER/$REPO/pages \
  -d '{"build_type":"legacy","source":{"branch":"main","path":"/"}}' \
  || echo "⚠️ 自动开 Pages 失败，请手动去 Settings → Pages 选 main/(root)"

echo ""; echo "✅ 完成！1~2 分钟后访问： https://$OWNER.github.io/$REPO/"
