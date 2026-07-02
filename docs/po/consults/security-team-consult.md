# Security Team Consult — A4 elementID PII 처리 + PrivacyManifest

> 의뢰자: po-team
> 응답: Security Team (🔴 Senior 한시니어 · 🟡 Mid 이미드 · 🟢 Junior 박주니어)
> 응답일: 2026-07-01
> 범위: RICE **Confidence** 입력 확정 + 1.0 수집 시작 전 프라이버시 정책 결론 (보안 엔지니어링 포지션)
> 입력 문서: `docs/sdk-spec/hithitkit.md` §4.2(ElementIDPolicy), §4.4(에러 모델), §11(보안/안전성), §12(미결사항 #4)
> 원칙: **모든 통제는 "어떤 위협을 막는지"를 명시한다.** 컴플라이언스는 floor(최저선)이지 ceiling이 아니며, 법적 최종 분류는 법무 escalation으로 분리한다.

---

## 💬 팀 토론 (요약)

**🟢 Junior (박주니어)**: 실제 금융앱 `accessibilityIdentifier` 샘플 보면 `account_1234`, `loan_app_886423`, `card_4915xxxx` 같은 패턴이 분명히 섞여 들어옵니다. 개발자가 접근성 식별자를 "유저 식별용"으로 재활용하는 케이스가 흔해서, elementID는 잠재 PII로 봐야 해요. 탈옥 기기에서 로컬 JSONL을 열면 이 원문이 그대로 보이는 게 제일 무섭습니다.

**🟡 Mid (이미드)**: 동의합니다. 그런데 `.drop`을 기본으로 깔면 element-level 인사이트(어떤 버튼을 누르는가)가 0이 돼서 SDK 가치 자체가 반토막 납니다. 핵심 트레이드오프는 "PII 위협 완화 vs 인사이트 가치 손실". `.hashed`(SHA-256)는 동일 식별자 간 집계(같은 버튼 그룹핑)는 살리면서 원문 PII는 평문으로 안 남기는 균형점이에요. 해싱은 백그라운드 큐에서 돌리면 터치당 <0.5ms 예산도 안 건드립니다. 스펙이 이미 `.hashed`를 기본으로 잡은 건 합리적입니다.

**🔴 Senior (한시니어)**: 정리하죠. 보안 엔지니어링 포지션으로 **기본값 `.hashed` 유지**가 맞습니다 — Secure by Default 원칙(deny-by-default가 아니라 minimize-by-default)에 부합하고, 인사이트를 죽이지 않으면서 평문 PII 노출(T-1)을 막습니다. 단 두 가지 못을 박아야 해요. (1) 해시는 무지개표/사전 공격을 막기 위해 **솔트(앱별 또는 빌드별)** 가 들어가야 평문 식별자 역추론을 어렵게 합니다. salt 없는 SHA-256은 `account_1234`처럼 low-entropy 식별자면 브루트포스로 뚫립니다. (2) **법적 PII 분류 최종 확정은 우리가 못 합니다 → 법무 확인 필요**. 우리는 "PII를 담을 수 있다"는 위협 분류까지만 하고, "법적으로 개인정보다/아니다"는 법무가 찍어야 해요. PrivacyManifest는 추적이 아니어도 제출은 floor라 무조건 들어갑니다.

**합의**: 기본값 `.hashed`(+salt) 권고, allowlist는 명시적 옵트인 운영, drop은 민감 화면용. 법적 분류 + IDFA 비추적 입장의 법적 확인은 법무 escalation.

---

## 1. A4 — elementID(accessibilityIdentifier) PII 분류 + 권장 ElementIDPolicy 기본값

### 1.1 PII 누출 경로 + 위협

| 자산 | 분류 (보안팀 엔지니어링 분류) | 누출 경로 (예) | 위협 (STRIDE) |
|---|---|---|---|
| elementID (`accessibilityIdentifier`) | **restricted (잠재 PII)** → 법적 최종 분류는 **법무 확인 필요** | 개발자가 식별자에 사용자/거래 데이터를 임베드: `account_1234`, `loan_886423`, `txn_99812`, `card_4915` | **T-1 Information Disclosure** — 평문 식별자가 로컬 JSONL(at-rest)·업로더 경계 너머로 유출 |
| elementID + nx/ny 결합 | 단독 좌표는 internal이나 식별자 결합 시 **confidential 격상** | 좌표 + 원문 elementID가 한 이벤트에 동시 저장 | T-1 가중 (정황 재식별) |

위협 요약: elementID는 SDK가 **콘텐츠를 안 본다는 불변식을 우회해 PII가 새는 유일한 1급 경로**다. 좌표는 비식별이지만 식별자는 호스트 개발자 손에서 PII를 실어올 수 있다 → 정책으로 **강제 차단**해야 한다(호스트 선의에 의존 금지).

### 1.2 정책별 위협 완화 / 트레이드오프

| 정책 | 막는 위협(T-1) 완화 효과 | 인사이트 가치 | 트레이드오프 / 잔존 위험 |
|---|---|---|---|
| **`.drop`** (미수집) | **최상** — 원문도 해시도 안 남음. PII 누출 경로 원천 제거 | **최저** — element-level 분석 불가(어떤 버튼/요소를 눌렀는지 0). 좌표 히트맵만 남음 | 인사이트 가치 손실 큼. 민감 화면 전용으로 적합 |
| **`.hashed`** (SHA-256, **기본값**) | **높음** — 원문 평문 미저장. 동일 식별자→동일 해시라 집계는 유지 | **높음** — 원문은 못 봐도 "같은 요소 그룹핑"·빈도 분석 가능 | salt 없으면 low-entropy 식별자(`account_1234`)는 무지개표/브루트포스로 역추론 가능 → **앱/빌드별 salt 필수**. salt 있어도 결정적 해시라 동일 식별자 linkage는 남음(수용 가능 잔존 위험) |
| **`.allowlist(Set)`** | **중간(선택적)** — 화이트리스트 식별자만 원문 보존, 나머지 drop | **선택적 최고** — 안전하다고 검증된 정적 식별자(`btn_login`, `tab_home`)는 원문 그대로 → 가독성 최상 | 호스트가 allowlist에 **PII 식별자를 실수로 넣으면 평문 잔존**. 명시적 옵트인일 때만 발생하지만 운영 실수 리스크 → 가이드 필수 |

### 1.3 권장 기본값 (보안 엔지니어링 포지션)

**권고: 기본값 `.hashed` 유지 (스펙 §4.2와 일치) + 다음 2개 가드 추가**

1. **salt 필수**: SHA-256에 앱별 또는 빌드별 salt 적용. 근거 — salt 없는 결정적 해시는 `account_1234`류 low-entropy 식별자를 무지개표/브루트포스로 역추론할 수 있어 T-1 완화가 무력화됨. 해싱+salt 연산은 **백그라운드 큐**에서 수행 → 터치당 <0.5ms 메인스레드 예산 무침해(§5).
2. **민감 화면은 `.drop`/제외 우선**: 로그인·계좌·금액 화면(`excludedScreenIDs`)에서는 elementID를 hashed로도 남기지 말고 drop. 수집과 히트맵 배경 캡처 양쪽 동일 적용.

**기본값 근거**:
- **Secure by Default** — 호스트가 정책을 명시 안 해도 원문 PII가 평문으로 새지 않는 안전한 출발점(`.hashed`)을 강제. `.drop`을 기본으로 하면 SDK 핵심 가치(element-level 인사이트)가 죽어 채택률이 무너지므로 floor로는 과함.
- **위협↔가치 균형** — `.hashed`는 T-1(평문 PII 유출)을 막으면서 element 집계 인사이트를 보존하는 유일한 중간점.
- **운영 권고**: 정적·비PII 식별자만 쓰는 화면은 호스트가 `.allowlist`로 가독성 확보, 민감 화면은 `.drop`. 즉 **기본 `.hashed`, 화이트리스트는 옵트인, 민감 화면은 drop**의 3-tier 운영.

> ⚠️ **법무 확인 필요 (escalation)**: elementID가 **법적으로 "개인정보(PII)"에 해당하는지의 최종 분류**는 보안팀이 단정하지 않는다. 우리는 "PII를 담을 수 있다"는 위협 분류까지만 수행. 해시 처리된 식별자가 PIPA/GDPR상 **가명정보(pseudonymized)인지 익명정보(anonymized)인지**의 법적 판정도 법무 몫(가명정보면 여전히 개인정보 규율 대상). → **§3 법무 에스컬레이션 항목 참조.**

---

## 2. PrivacyInfo.xcprivacy — 데이터 카테고리 + 수집 목적 선언

### 2.1 선언할 data category

| 항목 | 선언 값 | 근거 |
|---|---|---|
| **Collected Data Type** | **Product Interaction** (`NSPrivacyCollectedDataTypeProductInteraction`) | 탭·스크롤 dwell·depth = 앱 내 상호작용. 좌표/요소ID는 콘텐츠가 아닌 상호작용 신호 |
| **Collection Purpose** | **App Functionality** (`NSPrivacyCollectedDataTypePurposeAppFunctionality`) — UX 분석/제품 개선 | 1st-party UX 인사이트 목적. (Analytics 목적 병행 선언 여부는 §3 법무 확인 항목) |
| **Linked to user?** | **No (권고)** — 단, elementID 처리 정책 의존 | `.hashed`/`.drop` 기본 전제에서 비연결. allowlist로 식별 가능 원문을 보존하면 "Linked" 재검토 필요 → 법무 확인 |
| **Used for Tracking?** | **No** | ATT/IDFA 크로스앱 추적 아님 (§2 Non-Goals) |
| **NSPrivacyTracking** | **`false`** | 1st-party 분석 전용, IDFA·크로스앱 결합 없음 |
| **NSPrivacyTrackingDomains** | **(빈 배열/미선언)** | tracking=false이므로 추적 도메인 없음 |
| **Required Reason API** | 사용 시 해당 reason 선언 | SDK가 file timestamp·UserDefaults 등 Required-Reason API 사용 시 해당 API 카테고리도 매니페스트에 기재 필요(구현 단계 점검) |

### 2.2 포지션: "추적 아님, 그러나 매니페스트는 필수"

- 이 SDK는 **ATT/IDFA 기반 크로스앱 추적이 아니다**(1st-party UX 분석 전용, spec §2 Non-Goals). 따라서 **`NSPrivacyTracking = false`**, ATT 권한 프롬프트 불필요.
- **그러나 추적이 아니라는 이유로 `PrivacyInfo.xcprivacy` 제출을 생략하지 않는다.** Apple은 수집 데이터 타입 선언을 추적 여부와 무관하게 요구하며, 매니페스트 누락/오선언은 **App Store 심사 reject 사유**. 매니페스트는 1.0 **필수 산출물(floor)**.
- 즉 **"추적은 아니지만 선언은 한다"** 가 정확한 포지션.

---

## 3. 법무 / DPO 에스컬레이션 항목 (보안팀이 단정하지 않음)

| # | 항목 | 왜 법무인가 | 영향 | 데드라인 |
|---|---|---|---|---|
| L-1 | **elementID의 법적 PII 분류 최종 확정** | "개인정보 해당 여부"는 법적 판정. 보안팀은 위협 분류(잠재 PII)까지만 | A4 RICE Confidence·ElementIDPolicy 기본값 변경 가능성 | **1.0 수집 시작 전** (spec §12-4) |
| L-2 | **해시 elementID의 가명정보 vs 익명정보 판정** (PIPA/GDPR) | 가명정보면 여전히 개인정보 규율 대상 → 동의·보존·삭제 의무 달라짐 | `.hashed` 기본값의 컴플라이언스 충분성 | 1.0 전 |
| L-3 | **PrivacyManifest 수집목적에 Analytics 병행 선언 여부** | App Functionality 외 Analytics 목적 추가 선언이 법적으로 필요/적절한지 | 매니페스트 정확성·심사 리스크 | 1.0 매니페스트 확정 전 |
| L-4 | **"Linked to user = No" 확정** (특히 allowlist 사용 시) | 식별 가능 원문 보존 시 연결성 법적 판단 필요 | 매니페스트 Linked 플래그 | 1.0 전 |
| L-5 | **국외 이전 / EU 사용자 시 GDPR DPIA 필요 여부** | 데이터 국외 이전·DPIA는 법무/DPO 영역 | 호스트앱별 컴플라이언스 | 호스트 통합 시 |

> 보안팀 입장: 위 항목들은 보안 엔지니어링 권고(기본 `.hashed`+salt, manifest 필수, tracking=false)와 **독립적으로** 법적 확인이 필요. 권고 자체는 법무 확인을 기다리지 않고 1.0 구현 가능하나, **최종 PII 분류 결과에 따라 기본값 상향(`.hashed`→`.drop`) 여지**는 열어둔다.

---

## 4. A4 Confidence에 영향을 주는 부수 통제 (한 줄)

동의 기본 OFF(fail-safe, "OFF⇒이벤트 0건" 릴리즈 게이트) + 민감 화면 제외(수집·배경 캡처 양쪽) + 수집 콘텐츠 불변식(좌표·요소ID만, 텍스트/입력값 절대 미수집)이 이미 스펙·테스트로 강제되어 있어, elementID 정책은 **여러 통제 중 마지막 한 겹**일 뿐 — 단일 실패점이 아니므로 A4 Confidence를 **상향**시킨다(Defense in Depth).

---

## 📊 RICE 입력 요약 — A4

| 항목 | 값 |
|---|---|
| **백로그 아이템** | A4 — elementID PII 처리 (hashed 기본 / drop / allowlist) |
| **Confidence 등급** | **High (80%)** |
| **권장 ElementIDPolicy 기본값** | **`.hashed`** (SHA-256 **+ 앱/빌드별 salt**), 민감 화면 `.drop`, 정적 비PII 식별자는 `.allowlist` 옵트인 |
| **근거** | (1) 위협(T-1 평문 PII 유출)→통제(`.hashed`+salt) 매핑 명확. (2) `.hashed`가 PII 노출 차단과 element 인사이트 보존의 균형점 — drop은 가치 과손실, 평문은 위협. (3) 동의 OFF·민감화면 제외·콘텐츠 불변식이 이미 강제되어 Defense in Depth로 Confidence 상향. (4) salt·백그라운드 큐로 <0.5ms 성능 예산 무침해. (5) PrivacyManifest는 tracking=false·Product Interaction·App Functionality로 선언 항목 확정적 |
| **Confidence를 100%로 못 올리는 이유 (법무 확인 대기)** | elementID 법적 PII 분류(L-1)·해시의 가명/익명 판정(L-2) 미확정 → 최악의 경우 기본값을 `.drop`으로 상향해야 할 잔여 불확실성 |
| **법무 확인 대기 항목** | L-1 elementID 법적 PII 분류 / L-2 해시=가명 vs 익명 / L-3 Analytics 목적 병행 선언 / L-4 Linked-to-user 확정 / L-5 GDPR DPIA·국외이전 |

---

작성: Security Team (🔴 한시니어 · 🟡 이미드 · 🟢 박주니어)
원칙 준수: 모든 통제에 막는 위협 명시 / 컴플라이언스 floor 처리 / 법적 분류는 법무 escalation 분리
