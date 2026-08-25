---
name: gh-ops
description: GitHub operations discipline for branches, commits, issues, pull requests, code review, and merges. Use whenever committing or pushing a branch, opening or closing an issue, opening, reviewing, or merging a pull request, or running any gh CLI operation.
---

# gh-ops

## 分支

Trunk-based。自default分支`<issue#>-<slug>`，枝命短促，工畢即併。clone自upstream者從其舊俗。

## 提交

一commit一事，自足之改。祈使語、小寫起、句號免、忌謀劃套話（phase/step/milestone之屬），直言其變。

## 議題

- 引用必全稱`owner/repo#N`，勿單書`#N`；`Related:`/`Depends on:`冠之如式。
- 問之前遍閱該issue：正文、評論、所連PR；已決勿再問。
- label取既有者，`--milestone`宜則加之；未問勿創label。issue與PR，assignee恆`atqamz`。
- 多部之作：一tracking issue統之，諸部盡落方閉。
- PR既開或工既落則留言於該issue，「始作」之聲勿發。閉必附果：`gh issue close N -c "done: ..."`。

## PR

- Body三段：`## Summary`（一至三條）、獨行之closing keyword連`owner/repo#N`、`## Test plan`。
- 一PR一自足之改：百行上下為善，千行嫌巨。測試隨改同PR；重構與功能析為二；相續之PR，各併之際build毋壞。
- 關鍵字`Closes`/`Fixes`/`Resolves`緊貼引用，無關鍵字者連而不閉。keyword書於commit message者雖閉issue而PR不顯連結，故必書於body。併入default branch方生效；多issue則關鍵字逐一複之，逗號並列惟閉其一。跨repo書全稱，閉否由post-merge驗之定。

## 審閱

- 合併前review盡決：P1/P2以code正之，勿僅答於thread；既決之評以`gh api`覆之而後resolve；push新碼則re-request review。
- CI綠不足為safe，reviews未清不併。
- 不明其求先問清；欲駁則陳理與tradeoff，謀共識，勿硬頂。

## 合併

`gh pr merge --merge`或`--squash`擇一，中間commit雜者squash；`--rebase`永不用。

Post-merge每合必行：`gh issue view N --repo owner/repo --json state -q .state`驗之，仍開則`gh issue close N -c "landed in #PR"`；遠近branch俱刪。auto-close不可恃，驗以防漏。
