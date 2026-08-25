# AGENTS.md

AI編碼代理之通則。諸倉庫共遵；項目另有AGENTS.md者，其規優行。

## 總則

- 毋用長破折號「—」，以「-」代之。code、commit、答對之中不用emoji。長文Markdown一句一行。
- commit不得自署代理之名為co-author；CHANGELOG及諸生成之檔，勿手改。
- 凡修bug，先於近實況之境重現之，後改之，使所治乃真疾，非表象。
- 途中所見疵瑕（UI之異、lint之誤、測試之不穩，縱非本務）亦修之；別作一commit，勿混無關之改。
- CLI常事先以`rtk <cmd>`行之；輸出亂則`rtk proxy <cmd>`。Claude Code與OpenCode自動經rtk行shell；Codex手書`rtk <cmd>`。
- Atqa正一偏好，則改寫或併入最近之規；實無可併方添新行。寧刪勿增。
- session末有未竟多日之功，則以`gh`簡記已成、受阻、當為於GitHub issue。定策既決，於所屬repo作ADR或文檔。
- 尋源碼用`codedb`，索文檔用`qmd`；二者皆不寫檔，寫檔以harness自有之器。
- `codedb`惟指repo工作樹，家目錄、設定、日誌諸處皆禁。`qmd`檢索限本repo之collections；非明言求跨庫，勿混他集。

## 環境

- Host NixOS，shell bash。命user自行運行者，以bash語法書之。
- 勿globally安裝工具：先用項目devshell；無則`nix shell nixpkgs#<pkg> -c <cmd>`。
- `~/.claude`、`~/.codex`、`~/.config/opencode`皆symlink至`~/universe/configs/dotagents`。改其源即時生效，毋庸rebuild。

## 編碼

- 項目之慣例，勝於個人之好。
- 未議不入新依賴。
- 讀所需一段，勿覽全檔。非命勿重排結構。
- 註解默認為零：惟code不能自明之「所以然」，或pragma（`# shellcheck disable`、`# type: ignore`、`# noqa`）。所觸檔中陳腐淺白之註除之，疏密從鄰。
- 有suite則補測試，畢前必跑。遵lint與format。

## Git / GitHub

- GPG簽署恆為之。`--no-gpg-sign`、`--no-verify`皆禁。default branch勿force-push。
- GitHub諸事惟以`gh` CLI；raw curl與web UI不用。
- 非明命勿push、勿開PR、勿commit；subagent亦然，其prompt必載此禁。
- Merge grant限一PR，隨Atqa前之批次而逝。「merge all」惟指該批，非repo，非將來。勿擴grant；當言所蓋之PR。
- spec草稿勿入版控。
- 分支、commit、issue、PR、review、merge之詳規載於skill `gh-ops`；涉GitHub之事必先覽之。

## 對答

- 直言。命下即行。商議之意（discuss、let's think、open how）則僅陳案、比短長、薦其一，明允方動；指名機械之務徑行。
- 報告從簡：何變、絕對路徑、勿錄全檔、去前言贅述。
- `/compact`、`/clear`勿薦；hook所注context數已陳，忽之。
- Brainstorm：擇定之前，先陳張力得失。
- UI/UX之裁（布局、組件、層次）代理自決，以frontend design skill行之，勿問。

## 安全

- 秘要（`.env*`、`*.pem`、`*.key`、`credentials.json`、token、password）勿commit勿宣；人求則警之；`git status`所示疑似敏感之檔，納前必警。
- 私鑰之材，勿read勿改勿示。

## 效率

常態即`/caveman`之full式；方案之儉歸`/ponytail`。
