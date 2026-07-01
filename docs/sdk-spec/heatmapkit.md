# SDK Spec: HeatmapKit (iOS UX Heatmap Analytics SDK)

> Status: APPROVED by CTO (2026-07-01) — PHASE 3 ready
> CTO 조건 3건 반영 완료: (1) HeatmapError struct+code, (2) 성능 예산, (3) 프라이버시 기본 OFF + elementID PII 처리
> Obj-C 지원은 1.0 scope 제외(미래 과제)

## 1. 개요
- 한 줄 요약: 호스트 iOS 앱의 탭·스크롤 상호작용을 디바이스 무관하게 수집·정규화하고, 화면별 UX 히트맵으로 렌더링하는 드롭인 1st-party 분석 SDK.
- 해결하는 문제: "유저가 화면 어디를 많이 누르는가 / 얼마나 깊이 스크롤하는가"를 프라이버시를 지키며 1st-party로 측정.
- 대상 사용자: Finda 등 iOS 앱 개발팀(수집), 사내 UX/데이터 분석가(렌더 뷰어).

## 2. 목표 및 비목표
### Goals
- 전역 탭 수집 + 디바이스 간 비교 가능한 좌표 정규화
- 스크롤 dwell(체류시간) + 최대 깊이 수집
- 민감 화면/요소 제외(금융 프라이버시), 동의 기본 OFF
- 서드파티 0 의존성, iOS 14+ 드롭인
- 로컬 배치 저장(JSONL) + 주입 가능한 업로더
- Core Image 히트맵 렌더(옵셔널 타겟)
- **성능 예산 준수**: 터치당 메인스레드 < 0.5ms, 인코딩/IO 100% 백그라운드

### Non-Goals
- 실제 입력값/콘텐츠/스크린 텍스트 캡처 (좌표·요소 식별자만)
- 세션 리플레이(화면 녹화)
- ATT(IDFA) 기반 크로스앱 추적 — 1st-party 분석만
- 서버/대시보드 백엔드 — 업로더 인터페이스만 제공
- **Obj-C 전용 지원 (1.0 scope 제외)**

## 3. 지원 매트릭스
| 소비자 언어 | 패키지 | 최소 버전 | 우선순위 |
|---|---|---|---|
| Swift | SwiftPM `HeatmapKit` | iOS 14 / Swift 5.9 | P0 |
| Swift | CocoaPods `HeatmapKit.podspec` | iOS 14 | P1 |

| 플랫폼 | 지원 | 비고 |
|---|---|---|
| iOS | ✅ | 14.0+ |
| iPadOS | ✅ | 14.0+, orientation 버킷 필수 |
| macOS(Catalyst) | ⚠️ | best-effort, 비검증 |
| tvOS/watchOS | ❌ | 터치 모델 상이 |

## 4. Public API 설계

### 4.1 핵심 진입점 (HeatmapKit)
```swift
public final class HeatmapTracker {
    public static let shared: HeatmapTracker

    public func start(config: HeatmapConfig) throws
    public func stop()
    public var isRunning: Bool { get }

    // 동의 — 기본 OFF, 호스트가 명시적으로 켜야 수집 시작 (fail-safe)
    public func setConsent(_ granted: Bool)
    public var hasConsent: Bool { get }

    // 화면 컨텍스트
    public func beginScreen(_ screenID: String)
    public func endScreen(_ screenID: String)

    // 스크롤 명시 등록 (기본 경로, 비스위즐)
    public func track(scrollView: UIScrollView, screenID: String? = nil)
    public func untrack(scrollView: UIScrollView)

    // 배치 강제 flush
    public func flush(completion: ((Result<Void, HeatmapError>) -> Void)?)
}
```

### 4.2 설정
```swift
public struct HeatmapConfig {
    public var excludedScreenIDs: Set<String>
    public var excludedElementIDs: Set<String>
    public var elementIDPolicy: ElementIDPolicy   // PII 처리 (CTO 조건 3)
    public var samplingRate: Double               // 0.0...1.0, 기본 1.0
    public var scrollSampleHz: Int                // 기본 10
    public var autoTrackScrollViews: Bool         // 기본 false (스위즐 옵트인)
    public var maxBatchSize: Int                  // 기본 500
    public var storageDirectory: URL?
    public var uploader: HeatmapUploader?
    public init()
}

/// elementID(accessibilityIdentifier)가 PII를 담을 수 있어 처리 정책을 강제.
public enum ElementIDPolicy: Sendable {
    case drop                       // elementID 미수집 (가장 보수적)
    case allowlist(Set<String>)     // 허용된 식별자만 원문 보존, 나머지 drop
    case hashed                     // SHA256 해싱 후 저장 (기본값)
}
```

### 4.3 업로더 (전송 책임 분리)
```swift
public protocol HeatmapUploader: AnyObject {
    func upload(batch: Data, schemaVersion: Int,
                completion: @escaping (Result<Void, Error>) -> Void)
}
```

### 4.4 에러 모델 — struct + Int code (CTO 조건 1)
```swift
/// 향후 case 추가가 breaking change가 되지 않도록 enum 대신 struct + code.
public struct HeatmapError: Error, Equatable, Sendable {
    public struct Code: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let notConfigured      = Code(rawValue: 1)
        public static let alreadyRunning     = Code(rawValue: 2)
        public static let consentNotGranted  = Code(rawValue: 3)
        public static let storageUnavailable = Code(rawValue: 4)
        public static let encodingFailed     = Code(rawValue: 5)
        // 신규 코드는 새 rawValue 추가만 — non-breaking
    }
    public let code: Code
    public let message: String
    public let underlying: Error?
}
```
> 소비자는 `error.code == .storageUnavailable` 형태로 비교. 미지 코드는 default 처리.

### 4.5 렌더링 API (HeatmapViz 타겟, 옵셔널)
```swift
public struct HeatmapRenderRequest {
    public var screenID: String
    public var deviceClass: DeviceClass
    public var orientation: HeatmapOrientation
    public var background: CGImage?      // 기준 스크린샷(민감화면 제외)
    public var size: CGSize
    public var radius: CGFloat           // 기본 24
    public var intensity: CGFloat        // 기본 0.6
    public init(screenID: String, deviceClass: DeviceClass,
                orientation: HeatmapOrientation, size: CGSize)
}

public struct HeatmapRenderer {
    public init()
    public func renderTaps(_ request: HeatmapRenderRequest,
                           from events: [TouchEvent]) throws -> CGImage
    public func renderScroll(_ request: HeatmapRenderRequest,
                             from events: [ScrollEvent]) throws -> CGImage
}
```

### 4.6 공유 스키마 (HeatmapCore — wire format, semver 핵심 계약)
```swift
public struct DeviceClass: Hashable, Codable, Sendable {
    public let shortSide: Int
    public let longSide: Int
}
public enum HeatmapOrientation: String, Codable, Sendable { case portrait, landscape }

public struct TouchEvent: Codable, Sendable {
    public let schemaVersion: Int        // 현재 1
    public let screenID: String
    public let elementID: String?        // policy 적용 후 값
    public let nx: Double                 // 0...1 정규화 X
    public let ny: Double                 // 0...1 정규화 Y
    public let deviceClass: DeviceClass
    public let orientation: HeatmapOrientation
    public let timestamp: TimeInterval
}

public struct ScrollEvent: Codable, Sendable {
    public let schemaVersion: Int
    public let screenID: String
    public let scrollID: String?
    public let maxDepth: Double          // 0...1 최대 도달 깊이
    public let dwellByBucket: [Double]   // 깊이 버킷별 체류 초
    public let deviceClass: DeviceClass
    public let orientation: HeatmapOrientation
    public let timestamp: TimeInterval
}
```

## 4.7 비동기/동기 정책
- 동기 + 콜백 기본. `async/await`는 `@available(iOS 15.0, *)` extension.
- 수집은 fire-and-forget. 내부 저장/인코딩은 전용 serial `DispatchQueue`.

## 4.8 스레드 안전성
- `HeatmapTracker.shared`: thread-safe(내부 직렬 큐). `track`/`beginScreen`은 메인 스레드 권장.
- `HeatmapRenderer`: stateless, 인스턴스별 사용. 메인 밖 호출 권장.
- 이벤트 값 타입: `Sendable`.

## 4.9 메모리 / 소유권
- `HeatmapUploader` weak 보관. 추적 `UIScrollView` weak — dealloc 시 자동 untrack.

## 5. 성능 예산 (CTO 조건 2 — 1급 항목)
| 항목 | 목표 | 검증 |
|---|---|---|
| 터치당 메인스레드 작업 | < 0.5ms | CI 마이크로벤치 |
| 인코딩/디스크 IO | 100% 백그라운드 큐 | 코드 리뷰 + 큐 assertion |
| 스크롤 10Hz 샘플링 메인 점유 | < 1% | Instruments Time Profiler |
| `sendEvent` 핫패스 | 정규화 좌표계산만, 객체할당 최소 | 벤치 + allocation 카운트 |
- 메인스레드에서는 `touch.phase == .began` 좌표 계산과 큐 enqueue만. 인코딩/IO/해싱은 백그라운드.

## 6. 버저닝 정책
- API semver: public 시그니처 변경=major, 추가=minor.
- Schema semver(별도 트랙): `schemaVersion` 정수. 필드 추가=옵셔널(backward-compatible). 의미변경/삭제=schemaVersion++ & SDK major.
- Forward/Backward: 렌더러는 아는 버전 이하만 처리, 상위는 skip+카운트. 디코더는 미지 필드 무시.
- pre-1.0: minor breaking 허용. Deprecation: 최소 2 마이너 유지 후 제거.

## 7. 의존성 정책
| 의존성 | 사유 | 필수/feature | 라이선스 |
|---|---|---|---|
| Foundation | 기본 | 필수 | Apple |
| UIKit | 터치/스크롤/뷰 | 필수(HeatmapKit) | Apple |
| CoreImage/CoreGraphics | 렌더 | 필수(HeatmapViz) | Apple |
| 서드파티 | — | **없음** | — |

## 8. 빌드 / 패키징
- SwiftPM: 1 패키지, 3 타겟(HeatmapCore/HeatmapKit/HeatmapViz), 2 프로덕트.
- CocoaPods: `HeatmapKit.podspec` subspec Core/Collection/Viz.
- 리소스 0(컬러맵 코드 생성).
- CI: GitHub Actions 매트릭스(Xcode 15/16 × iOS 14/15/17), `swift test`, DocC, `pod lib lint`, 마이크로벤치.

## 9. 테스트 전략
- HeatmapCore: 정규화, 버킷, Codable round-trip, schemaVersion forward-compat.
- HeatmapKit: 제외 리스트, 샘플링, 동의 게이트, scrollView weak untrack, elementID policy.
- **동의 OFF → 이벤트 0건 회귀 테스트 = 릴리즈 게이트.**
- HeatmapViz: 픽셀 스냅샷.
- 성능: 마이크로벤치(터치당 < 0.5ms).

## 10. 문서화
- DocC 전 public 심볼 + Getting Started.
- README Quick Start 5줄.
- 프라이버시 가이드 + PrivacyInfo.xcprivacy 템플릿.
- 샘플 앱(탭/스크롤 데모 + 인앱 뷰어 #Preview).

## 11. 보안 / 안전성 (CTO 조건 3)
- panic 금지: fatalError/강제 unwrap 없음. 모든 실패 = HeatmapError.
- **동의 기본 OFF, 수집 기본 차단**(fail-safe).
- 민감화면: 제외 스크린 수집·배경 캡처 모두 차단.
- **elementID PII 처리**: 기본 `.hashed`, `.drop`/`.allowlist` 선택.
- 텍스트/입력값 절대 미저장(테스트로 강제).
- **PrivacyInfo.xcprivacy 1.0 필수 산출물**: `NSPrivacyTracking=false`, 수집 타입 "Product Interaction".

## 12. 미결 사항 (Open Questions)
1. Window 후킹 최종형(교체 vs 런타임 옵저버) — PHASE 3 프로토타입. 기본은 비스위즐.
2. 저장 백엔드: 1.0 JSONL 고정. SQLite는 minor.
3. ~~Obj-C 지원~~ → 1.0 scope 제외(미래 과제, 추가는 non-breaking).
4. elementID PII 분류 법무 검토.

---
작성일: 2026-07-01
작성자: SDK Team (Senior · Mid · Junior) + CTO 컨펌
버전: v1.0
