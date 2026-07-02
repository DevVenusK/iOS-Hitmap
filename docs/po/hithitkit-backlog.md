# 백로그/우선순위: HitHitKit 1.0

> 작성: po-team (🔴김PO·🟡이PO·🟢박PO) | 2026-07-01
> 인풋: `docs/sdk-spec/hithitkit.md`(CTO 컨펌 스펙) + 의뢰 회신 3건(`docs/po/consults/`)
> 아웃컴 축: **채택(Adoption) · 인사이트(Insight) · 신뢰(Trust)** — 신뢰 깨지면 채택 0, 채택 0이면 인사이트 0

## 통합 RICE 입력 (출처 명시)

| 아이템 | R | I | C | E | **RICE** | 순위 | 출처 | API/schema 영향 |
|---|---|---|---|---|---|---|---|---|
| A2 동의OFF+회귀테스트 | 10 | 3 | 1.0 | S(1) | **30.0** | 1 | spec, CTO | 없음 |
| A1 성능예산+CI벤치 | 10 | 3 | 1.0 | L(4) | **7.5** | 2 | ios-team | 없음 |
| A6 schema 동결점검 | 6 | 2 | 0.5 | S(1) | **6.0** | 3 | designer | **schema 영구동결(critical-timing)** |
| A3 PrivacyManifest(권장) | 5 | 1 | 1.0 | S(1) | **5.0** | 4 | 정정 2026-07-01 | 없음 |
| A5 QuickStart+비스위즐 | 8 | 2 | 0.9 | M(3) | **4.8** | 5 | spec§10 | 없음 |
| A8 reference uploader | 7 | 1 | 0.7 | M(2) | **2.45** | 6 | po PHASE1 | 없음(샘플) |
| A7 HitHitViz 렌더러 | 5 | 2.5 | 0.7 | L(5) | **1.75** | 7 | designer | 없음(옵셔널 타겟) |
| A9 CocoaPods | 3 | 1 | 0.5 | M(2) | **0.75** | 8 | ios-team | 없음 |
| ~~A4 elementID PII~~ | — | — | — | — | **삭제** | — | v1 스코프 | elementID 미수집으로 소멸 |

> RICE는 상대 스케일(Reach 1–10, Impact 0.25–3, Confidence 0.5–1.0, Effort 가중). 절대수치 아님.

> **정정 (2026-07-01)**: A3(PrivacyManifest)를 "1.0 필수 블로커"에서 **"권장(선택)"으로 강등**.
> 이유: 현재 코드가 Required Reason API(UserDefaults/파일 타임스탬프/부팅시간/디스크용량 등)를
> **사용하지 않아** App Store 자동 리젝 대상이 아니다. 데이터 수집 신고는 매니페스트 없이도
> **호스트 앱의 App Privacy 라벨** 책임으로 처리 가능. Impact 3→1로 하향, 자동리젝 근거 철회.
> ⚠️ 단, 향후 캐시를 `UserDefaults`로 바꾸거나 파일 타임스탬프를 읽으면 그때는 required-reason 선언 필요.
> 또한 A4(elementID PII)는 v1이 elementID를 아예 미수집하므로 **소멸**.

## 임팩트 시나리오 (Top 아이템)

- **A1 성능예산**: 보수(jank 잡아도 채택 그대로) / 기본(jank 0 → 호스트앱이 켬) / 낙관(성능 신뢰가 레퍼런스 사례로 타 앱 채택 견인). E는 미결#1(window 후킹) 확정 시 L→M.
- **A4 elementID**: 보수(법무가 .drop 강제 → 인사이트 손실) / 기본(.hashed+salt+allowlist로 균형) / 낙관(allowlist 운영 정착 → 분석가 만족).

## 로드맵 (Now / Next / Later)

### NOW — 1.0 (신뢰 + 최소 채택 게이트)
- A2 동의 OFF + "OFF=0건" 회귀테스트 **(릴리즈 게이트)** — ✅ 구현완료
- A1 성능 예산 + CI 마이크로벤치 (터치당 <0.5ms, 인코딩/IO 100% 백그라운드) — ✅ 벤치+CI 완료 (per-op ~0.15µs)
- A5 Quick Start + 비스위즐 명시 등록 — ✅ README 완료 (DocC 플러그인은 선택)
- **▸ NOW-EXIT 게이트**: A6 — 기존 필드 의미변경/삭제 필요성 1회 점검 → 없으면 schemaVersion=1 동결. (필드 *추가*는 1.0 이후 옵셔널로 non-breaking이므로 블로커 아님)

**권장/선택 (블로커 아님):**
- A3 PrivacyInfo.xcprivacy — **1.0 필수 아님**(정정 2026-07-01). 현재 required-reason API 미사용이라 자동리젝 대상 아님. 데이터수집 신고는 호스트앱 App Privacy 라벨 책임. 향후 UserDefaults/파일타임스탬프 도입 시 필요.

**소멸(제외):**
- ~~A4 elementID PII~~ — v1이 elementID를 아예 미수집하므로 소멸. 관련 법무 L-1~L-5도 대부분 불필요.

### NEXT — 1.0+ (인사이트)
- A7 HitHitViz 렌더러 (탭/스크롤, 디바이스 버킷 집계). 옵셔널 필드 추가는 non-breaking.
- A8 reference uploader 샘플 (통합 마찰 감소)
- (필요시) sessionID / sequenceIndex 옵셔널 필드 추가 — 분석가 퍼널/이탈 요구 확인 후

### LATER — 조건부
- A9 CocoaPods podspec → **host-app 인벤토리(CocoaPods 채택 비중) 확인 후**
- A10 SQLite 저장 옵션 / Obj-C 지원 → CTO 1.0 제외 결정, 추가는 non-breaking

## 핵심 텐션 해소 결정

1. ~~**elementID 보안 vs 인사이트**~~ — **무효화(2026-07-01)**: v1 스코프가 elementID를 아예 미수집하기로 확정되어 이 텐션 자체가 소멸. PII 경로 제거 = 프라이버시 최선.
2. **schema 동결 타이밍**: 필드 추가는 옵셔널=non-breaking(spec§6). A6의 임무는 "추가"가 아니라 "기존 필드 의미변경/삭제 점검". → A6를 블로커에서 가벼운 NOW-EXIT 점검으로 강등.

## 의도적 거절 (안 하는 것 + 이유)
- **Obj-C 전용 지원** — CTO 1.0 제외. Finda Swift 비중 확인 전 부채. 추가는 non-breaking이라 미래로.
- **SQLite 저장** — JSONL로 1.0 충분. 데이터 폭증 시 minor.
- **세션 리플레이/화면녹화** — Non-Goal(프라이버시).
- **스위즐 자동 스크롤 추적 기본 ON** — 호스트 충돌/심사 리스크. 영영 옵트인.

## 기회비용 (1순위 선택으로 미루는 것)
- A1~A5(신뢰·채택)를 NOW에 넣음으로써 **A7 렌더러가 Next로 밀림** — 단, 렌더러는 데이터가 쌓인 뒤 가치가 나므로 시점상 손해 없음. "데이터 안 쌓이는데 뷰어만 있는" 최악 상태를 회피.

## 다음 액션 분배
| 아이템 | 담당 | 액션 |
|---|---|---|
| A2/A1 | **ios-team** | 회귀테스트 게이트(완료) + 핫패스 벤치 CI + 비스위즐 확정(미결#1) |
| A5 | **ios-team** | Quick Start/DocC 온보딩 문서 |
| A3(권장) | **ios-team** | 필요 시 PrivacyInfo.xcprivacy 추가(블로커 아님) + 호스트앱 App Privacy 라벨 가이드 |
| A6 exit점검 / A7 검증 | **designer-team + 분석가** | 분석가 워크숍 1회(실제 쿼리 재현 + 필드 점검) |
| A9 Reach | **po-team** | host-app CocoaPods 인벤토리 확보 |
| ~~A3 카테고리 / A4 정책 / L-1~L-5~~ | ~~security/법무~~ | v1 elementID 미수집으로 대부분 불필요 |

---
버전: v1.0
