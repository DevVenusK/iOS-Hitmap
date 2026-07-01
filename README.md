# HeatmapKit

호스트 iOS 앱의 **탭·스크롤 이벤트를 정규화 좌표로 수집해 서버로 직접 전송**하는 1st-party 분석 SDK.
히트맵 렌더링은 하지 않는다 — 수집된 데이터로 **당신이 나중에 직접** 히트맵을 만든다.

- 서드파티 의존성 **0** (Foundation/UIKit만)
- iOS 14+ · Swift 5.9+ · SwiftPM
- 좌표·화면이름·시간만 수집 (텍스트/입력값/요소식별자 **미수집**)
- 동의 기본 **OFF** (fail-safe) · 민감화면 제외 · 성능 예산(터치당 <0.5ms)

## 설치 (SwiftPM)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/<org>/HeatmapKit.git", from: "1.0.0")
]
```

## Quick Start (5줄)

```swift
// 1) SceneDelegate — window를 TrackingWindow로 교체
window = TrackingWindow(windowScene: windowScene)

// 2) 앱 시작 시
let config = HeatmapConfig(endpoint: URL(string: "https://your.server/heatmap")!)
try? HeatmapCollector.shared.start(config: config)

// 3) 개인정보 동의를 받은 뒤 (기본 OFF)
HeatmapCollector.shared.setConsent(true)
```

화면마다:

```swift
// 각 ViewController의 viewWillAppear 등에서
HeatmapCollector.shared.setScreen("loan_detail")

// 스크롤 깊이를 추적할 스크롤뷰 등록 (스위즐 없음)
HeatmapCollector.shared.track(scrollView: tableView)

// 앱이 백그라운드로 갈 때 남은 배치 전송
HeatmapCollector.shared.flush()
```

## 수집되는 데이터 (서버로 전송되는 이벤트)

탭·스크롤을 하나의 flat 스키마로 통일. `screenW/H`+`device`+`orientation`을 함께 보내
어떤 기기든 합쳐 히트맵을 그릴 수 있다.

```json
// 탭
{ "schemaVersion": 1, "type": "tap", "screen": "loan_detail",
  "x": 0.42, "y": 0.73, "screenW": 390, "screenH": 844,
  "device": "iPhone15,3", "orientation": "portrait", "ts": 1719800000000 }

// 스크롤
{ "schemaVersion": 1, "type": "scroll", "screen": "loan_detail",
  "scrollDepth": 0.65, "scrollOffsetY": 1240,
  "screenW": 390, "screenH": 844,
  "device": "iPhone15,3", "orientation": "portrait", "ts": 1719800000000 }
```

배치는 JSON 배열로 `endpoint`에 `POST`된다(내장 전송기, 지수 백오프 재시도, 실패 시 로컬 보존).

## 설정 (HeatmapConfig)

| 필드 | 기본값 | 설명 |
|---|---|---|
| `endpoint` | (필수) | 배치 전송 대상 URL |
| `headers` | `[:]` | 인증 등 요청 헤더 |
| `excludedScreens` | `[]` | 수집 제외 화면(민감화면). 탭·스크롤 모두 차단 |
| `samplingRate` | `1.0` | 0~1, 확률적 샘플링 |
| `scrollSampleHz` | `10` | 스크롤 샘플링 주파수 |
| `maxBatchSize` | `500` | 한 배치 최대 이벤트 수 |
| `flushInterval` | `30` | 자동 flush 주기(초) |
| `storageDirectory` | caches | 로컬 저장 위치 |
| `uploader` | nil | 커스텀 전송기(주입 시 내장 전송기 대체) |

### 커스텀 전송기

인증/포맷/재시도를 완전히 통제하려면 `HeatmapUploader`를 구현해 주입한다.

```swift
final class MyUploader: HeatmapUploader {
    func upload(batch: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        // 직접 전송...
    }
}
var config = HeatmapConfig(endpoint: url)
config.uploader = MyUploader()
```

## 프라이버시

- **동의 기본 OFF.** `setConsent(true)` 전에는 단 한 건도 수집·저장되지 않는다(회귀테스트로 강제).
- **좌표만 수집.** 화면 콘텐츠/입력값/요소 식별자는 절대 담기지 않는다.
- **민감화면 제외.** 로그인·계좌·금액 화면 등은 `excludedScreens`에 등록.
- **`screen` 이름에 PII를 넣지 말 것** (서버로 전송됨). 고정 심볼릭 이름을 쓴다.
- ATT/IDFA 추적이 **아니다**(1st-party 분석). 자세한 신고 의무는 [docs/sdk-spec/heatmapkit-v1-collection.md](docs/sdk-spec/heatmapkit-v1-collection.md) §6 참고.

## 아키텍처

```
HeatmapCore   이벤트 스키마 · 에러 · 좌표 정규화(순수 함수)
HeatmapKit    HeatmapCollector(공개 API) · TrackingWindow · ScrollTracker
              EventPipeline(게이팅/저장/전송) · EventStore(JSONL) · DefaultHTTPUploader
```

- 메인 스레드는 **좌표 정규화 + enqueue만** 수행(성능 예산 <0.5ms). 인코딩/IO/네트워크는 100% 백그라운드.
- `HeatmapUploader` weak 보관, 추적 `UIScrollView` weak — retain cycle 없음.

## 개발 / 테스트

```bash
swift build
swift test        # 27 tests (동의OFF=0건 게이트, 전송 재시도, 정규화, 저장 등)
```

## 라이선스

Proprietary — Finda 1st-party.
