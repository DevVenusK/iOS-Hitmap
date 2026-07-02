# iOS팀 → PO팀 데이터 회신: RICE 입력 (A1, A9)

> 요청자: po-team (SDK 백로그 RICE 산정용 엔지니어링 데이터 요청)
> 회신자: iOS팀 (Senior 이시니어 · Mid 박미드 · Junior 최주니어)
> 근거 문서: `docs/sdk-spec/hithitkit.md` (v1.0, CTO APPROVED 2026-07-01)
> 작성일: 2026-07-01

---

## 0. 팀 토론 요약

- **Senior(이시니어)**: A1의 성능 예산(<0.5ms) 자체는 구현 난도가 높지 않으나, ① CI에서 0.5ms 같은 타이트한 임계값을 flaky 없이 gate로 거는 인프라, ② `sendEvent` 핫패스 인터셉트 방식(스위즐 vs 비스위즐)이 스펙 11번 미결사항(Open Question #1: "Window 후킹 최종형 미정")으로 아직 미확정이라는 점이 Effort를 끌어올리는 핵심 변수.
- **Mid(박미드)**: A9는 SwiftPM 3타겟(Core/Kit/Viz) 구조가 이미 깔끔해 podspec 매핑 자체는 어렵지 않으나, `pod lib lint` CI 매트릭스 추가 + 양쪽 패키지 매니저 버전 동기화 운영 부채가 숨은 비용. Reach는 "Finda 외 호스트앱이 몇 개이고 그중 CocoaPods 전용 비중이 얼마인가"라는 호스트앱 인벤토리 데이터가 필요한데, 이는 iOS팀이 보유한 정보가 아니라 PO팀/호스트앱 측 데이터로 채워야 함.
- **Junior(최주니어)**: 0.5ms는 60fps 프레임(16.67ms)의 3% 미만이라 측정 자체가 까다로움. `XCTClockMetric`/`XCTCPUMetric` 같은 XCTest 성능 API로 측정은 가능하나 디바이스 편차 없는 재현은 별도 과제. Finda min iOS 버전은 스펙에도 "가정"으로만 명시돼 있어 실제 확인된 적 없음.

---

## 1. A1 — 성능 예산 + CI 마이크로벤치

### Effort: **L** (Large)

**근거**
1. **성능 예산 구현 자체는 가벼움**: 메인스레드 작업을 `touch.phase == .began` 좌표 정규화 + 큐 enqueue로 한정하는 설계는 스펙 5번에 이미 명시돼 있고, 인코딩/IO를 전용 serial `DispatchQueue`로 미루는 구조도 스펙 4.7/4.9에 확정. 이 부분만 보면 M.
2. **CI 마이크로벤치 인프라가 Effort를 L로 끌어올리는 주된 요인**:
   - 0.5ms급 임계값은 CI 러너(GitHub Actions macOS runner)의 노이즈 대비 신호비가 낮아, 단순 wall-clock 측정으로는 flaky test가 거의 확정적으로 발생. `XCTClockMetric`/`XCTCPUMetric` 기반 통계적 측정(반복 횟수, baseline 비교, 허용 분산) 설계가 필요.
   - 스펙 8번 CI 매트릭스(Xcode 15/16 × iOS 14/15/17)에 마이크로벤치가 포함돼 있어, 버전별 성능 특성 차이까지 고려한 게이트 설계가 필요.
3. **`sendEvent` 핫패스 인터셉트 방식 미확정**: 스펙 12번 미결사항 #1 "Window 후킹 최종형(교체 vs 런타임 옵저버) — PHASE 3 프로토타입 필요"가 그대로 살아있음. 현재 스펙은 "기본은 비스위즐"(즉 `track(scrollView:)` 명시 등록 경로)이지만, `autoTrackScrollViews` 옵트인 스위즐 경로까지 구현 범위에 포함되면 Effort가 한 단계 더 올라갈 수 있음(L→XL 경계).

### 기술 리스크
- **CI 노이즈로 인한 거짓 양성/음성**: 공유 러너에서 0.5ms 임계값이 환경 변동(다른 job과의 리소스 경합)에 취약. self-hosted runner 또는 통계적 허용 범위(예: p95 기준) 설계 필요.
- **스위즐 경로 채택 시 Apple 정책/안정성 리스크**: `autoTrackScrollViews`가 런타임 스위즐을 쓴다면 향후 OS 버전업에서 깨질 가능성, 디버깅 난이도 상승. 스펙은 비스위즐을 기본으로 못박아 두었으나 옵트인 기능으로 들어오면 추가 리스크.
- **할당(allocation) 최소화 검증의 어려움**: "객체할당 최소" 요구(스펙 5번)는 코드 리뷰 + 벤치 외에 allocation 카운트 자동화가 필요한데, 이 자동화 자체가 별도 작업.

### 의존성
- Open Question #1(윈도우 후킹 최종형) 확정이 선행돼야 정확한 재추정 가능 — 현재는 "비스위즐 명시 등록"만 범위로 가정.
- CI 인프라(self-hosted runner 여부)는 DevOps팀 협의 필요.

---

## 2. A9 — CocoaPods podspec (SwiftPM 병행)

### Effort: **M** (Medium)

**근거**
- SwiftPM 구조가 이미 3타겟(HitHitCore/HitHitKit/HitHitViz) + 2프로덕트로 명확히 분리돼 있어(스펙 8번), podspec은 이를 subspec(Core/Collection/Viz)으로 매핑하면 됨 — 구조 설계 비용은 거의 없음.
- 서드파티 의존성이 0이라(스펙 7번) podspec 의존성 선언이 단순함.
- 다만 `pod lib lint` CI 매트릭스 추가, 두 패키지 매니저 동시 릴리즈 프로세스(태그 푸시 시 SwiftPM/CocoaPods 버전 동기화) 자동화까지 포함하면 일회성 구현보다 운영 설계 비용이 더 큼 → S가 아니라 M.

### Reach
- **확인 필요(→PO팀/호스트앱 인벤토리)**: iOS팀은 Finda 외 호스트앱 목록이나 각 앱의 패키지 매니저 채택 현황 데이터를 보유하고 있지 않음. "CocoaPods가 몇 개 통합 경로를 추가로 커버하는가"는 PO팀이 보유한 호스트앱 인벤토리 데이터로 채워야 하는 영역 — iOS팀이 추측해서 숫자를 만들지 않음.
- 참고로 줄 수 있는 정성적 판단: CocoaPods는 SPM이 등장하기 전부터 쓰이던 레거시 프로젝트, 또는 Tuist 등 일부 빌드 시스템과의 호환성 문제로 SPM 전환이 늦은 프로젝트에서 주로 필요. 즉 Reach는 "신규/최신 프로젝트"가 아니라 "레거시 통합 경로"에 집중될 가능성이 높음(가정).

### 기술 리스크
- 낮음. `pod lib lint` 통과가 가장 흔한 마찰 지점(라이선스/소스 경로/모듈 맵 설정 오류) — 통상 1~2회 반복 수정으로 해결되는 수준.
- 리소스 0(컬러맵 코드 생성, 스펙 8번)이라 리소스 번들링 관련 CocoaPods 특유의 이슈(리소스 번들 타겟 분리 등)는 없음.

### 의존성
- SwiftPM 패키지 구조(3타겟)가 먼저 안정화돼 있어야 podspec subspec 매핑이 의미 있음 — 현재 스펙 기준으로는 이미 충족.
- 동시 릴리즈 자동화는 CI/릴리즈 파이프라인(DevOps 영역)과 맞물림.

---

## 3. PO팀 요청 3가지 사실 확인

### 3-1. Finda min iOS 버전
**가정**: iOS 14+ (스펙 3번 지원 매트릭스에 명시된 값을 그대로 차용)
**확인 필요(→Finda iOS팀)**: 이 값은 HitHitKit 스펙 작성 시점의 가정이며, Finda 앱의 실제 Deployment Target을 iOS팀이 직접 확인한 적은 없음. RICE의 Reach/Effort 계산에 실제 값을 반영하려면 Finda iOS팀에 현재 Xcode 프로젝트의 `IPHONEOS_DEPLOYMENT_TARGET` 값을 직접 확인 요청해야 함.

### 3-2. 패키지 매니저 1차 선택
**1차: SwiftPM(P0), CocoaPods는 병행(P1)** — 스펙 3번 지원 매트릭스 기준.
**이유**:
- Apple 공식 우선 채택 방향이며 Xcode 네이티브 통합(별도 도구 설치 불필요)으로 호스트앱 도입 마찰이 가장 낮음.
- 서드파티 의존성이 0인 SDK 특성상(스펙 7번) SwiftPM의 의존성 해석 한계(동적 라이브러리/리소스 번들 복잡도)가 거의 발목을 잡지 않음.
- CocoaPods는 레거시 프로젝트/구버전 빌드 체인 호환을 위한 병행 옵션으로 P1 — 신규 채택을 막지 않으면서 기존 CocoaPods 기반 호스트앱의 마찰을 없애기 위함.

### 3-3. 메인스레드 jank 허용치(<0.5ms) 현실성과 측정 방법
**현실성**: 60fps 기준 1프레임 16.67ms 중 0.5ms는 약 3%에 불과해 수치 자체는 합리적인 목표지만, **측정/검증 난이도가 높음**. 디바이스/시뮬레이터 노이즈가 0.5ms보다 클 수 있어 CI에서 안정적으로 gate를 거는 것이 기술적 도전 과제(Open Question은 아니지만 A1 Effort를 L로 끌어올리는 직접 원인).

**측정 방법**:
- 코드 레벨: 메인스레드 작업을 `touch.phase == .began` 좌표 계산 + 큐 enqueue로 한정(이미 스펙에 설계 반영, 5번/4.7).
- CI 마이크로벤치: `XCTClockMetric`(wall-clock) + `XCTCPUMetric`(CPU 점유) 조합, 단발 측정이 아닌 반복 측정 후 통계(평균/p95) 기준 gate.
- 수동/심층 검증: Instruments Time Profiler로 스크롤 10Hz 샘플링 메인 점유율(<1% 목표, 스펙 5번) 측정, allocation 카운트는 Instruments Allocations 도구 병행.
- **확인 필요**: 0.5ms 임계값을 CI에서 어느 정도 분산 허용치(예: ±20%, p95 등)로 운용할지는 아직 팀 내 미확정 — PHASE 3 구현 시 벤치마크 설계와 함께 확정 예정.

---

## 4. RICE 입력 요약 표

| 아이템 | Effort | Reach | Confidence | 비고 |
|---|---|---|---|---|
| A1 — 성능 예산 + CI 마이크로벤치 | **L** | 전체 호스트앱 공통(모든 통합 경로에 영향, SDK 코어 1급 요구사항) | **Medium** | Open Question #1(윈도우 후킹 방식 미확정)이 풀리면 L→XL 또는 L→M 재추정 가능. 스위즐 경로 포함 여부가 변동 요인. |
| A9 — CocoaPods podspec | **M** | **확인 필요(→PO팀 호스트앱 인벤토리)** — CocoaPods 채택 호스트앱 수/비중 데이터 없음 | **High**(Effort) / **Low**(Reach) | Effort는 SwiftPM 구조 기반으로 신뢰도 높음. Reach는 iOS팀이 보유하지 않은 외부 데이터라 PO팀 확인 필요. |

---

## 5. 가장 중요한 가정/확인 필요 항목 (재정리)

1. Finda min iOS 버전 = iOS 14+ 는 **가정**이며 실제 Finda iOS팀 확인 전까지 미검증.
2. A9의 Reach(CocoaPods 채택 호스트앱 수)는 iOS팀이 추정할 수 없는 영역 — PO팀 호스트앱 인벤토리 데이터 필요.
3. A1의 Effort(L)는 스펙 미결사항(Open Question #1: 윈도우 후킹 최종형 미정)에 의존 — 확정 전까지 범위 변동 가능.

---
작성: iOS Team (Senior 이시니어 · Mid 박미드 · Junior 최주니어)
버전: v1.0
