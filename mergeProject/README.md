# mergeProject

각자 브랜치의 구현을 비교·선정한 뒤 **하나로 합치는 통합 프로젝트**를 두는 자리.

개인 폴더(`heeil/` 등)와 같은 구조를 쓴다. 선정이 끝나면 여기 내용을 저장소 루트로
올리면 제출 심사기준(`app/` + `README.md` + `screenshots/` + `prompts_log.md`)을 만족한다.

```
mergeProject/
  app/              Flutter 프로젝트
  README.md
  screenshots/
  prompts_log.md
```

> git은 **빈 폴더를 추적하지 못한다.** 이 README가 폴더를 저장소에 남기는 역할을 하므로
> 내용을 채우기 전까지 지우지 말 것.

합치는 절차와 브랜치 규칙은 [../heeil/TEAM_NOTES.md](../heeil/TEAM_NOTES.md) 3장.
빌드 산출물은 커밋하지 않는다 — 같은 문서 3-1장.
