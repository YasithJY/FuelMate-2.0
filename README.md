# ⛽ FuelMate 2.0 — Vehicle Fuel & Expense Tracker

[![iOS 17.2+](https://img.shields.io/badge/iOS-17.2%2B-blue.svg?logo=apple&style=flat-square)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg?logo=swift&style=flat-square)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple.svg?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![Core Data](https://img.shields.io/badge/Storage-Core%20Data-green.svg?style=flat-square)](https://developer.apple.com/documentation/coredata)
[![Swift Charts](https://img.shields.io/badge/Analytics-Swift%20Charts-indigo.svg?style=flat-square)](https://developer.apple.com/documentation/charts)
[![Apple Vision OCR](https://img.shields.io/badge/Vision-On--Device%20OCR-red.svg?style=flat-square)](https://developer.apple.com/documentation/vision)
[![MapKit](https://img.shields.io/badge/Maps-MapKit-teal.svg?style=flat-square)](https://developer.apple.com/documentation/mapkit)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square)](LICENSE)

**FuelMate 2.0** is a production-grade iOS vehicle expense and fuel efficiency tracker. Engineered with **SwiftUI, Swift Charts, Core Data, MapKit, and Apple's Vision framework**, FuelMate gives drivers real-time insight into operating costs, fuel economy (km/L / MPG), multi-vehicle fleets, station GPS locations, and on-device receipt scanning.

---

## 🌟 Key Features

### 🚘 1. Multi-Vehicle Fleet Management
* **Fleet Support**: Track and manage multiple vehicles (*Cars, Motorcycles, SUVs, Vans, Three-Wheelers*).
* **One-Tap Switcher**: Switch between vehicles from the navigation bar dropdown on Dashboard, History, and Analytics.
* **Vehicle Profiles**: Set vehicle names, license plate numbers (*e.g., WP CAB-2045*), tank capacity, and initial odometer baseline.
* **Independent Statistics**: Distance, economy, and expenditures calculated per vehicle with Core Data cascade delete rules.

### 🧾 2. On-Device Receipt OCR Scanner (Apple Vision)
* **Native Vision Framework (`VNRecognizeTextRequest`)**: 100% on-device text recognition with zero third-party or cloud dependencies.
* **Intelligent Sri Lankan Parsing**: Automatically extracts:
  * **Total Amount / Cost**: Detects `TOTAL`, `NET AMOUNT`, `AMOUNT`, `RS.`, `LKR`, and currency amounts.
  * **Fuel Volume**: Detects `QTY`, `VOL`, `LTR`, `LITERS`, `L` values.
  * **Station Brand**: Classifies **Ceypetco**, **Lanka IOC**, **Sinopec**, and **Shell / RM Parks**.
  * **Fuel Grade**: Recognizes Petrol 92, Petrol 95, Auto Diesel, Super Diesel, Kerosene.
* **Animated HUD**: Laser beam scanline animation and progressive status indicators.
* **Direct Verification Transition**: Prepopulates `AddLogView` directly from the scanned receipt for review before saving.

### 🗺️ 3. Native MapKit Station Locator & Interactive Map
* **MapKit Natural Language Search (`MKLocalSearch`)**: Search for fuel sheds and petrol stations near your GPS coordinates or anywhere in Sri Lanka.
* **Interactive Map Sheet**: Tap station markers or drop custom pins to capture station names, localities, and GPS coordinates automatically.
* **Sri Lankan Brand Pins**: Stations visualised with distinct brand colors (*Ceypetco Blue, Lanka IOC Orange, Sinopec Crimson, Shell Gold*).

### 📊 4. Executive Dashboard
* **Animated Efficiency Gauge**: Circular SVG-style progress ring tracking actual fuel economy against target goals with spring animations.
* **Responsive 2x2 KPI Grid**:
  * **Total Spent**: Cumulative fuel expenditure in your active currency (*e.g., Rs. 24,500.00*).
  * **Tracked Distance**: Net odometer span accumulated for the active vehicle.
  * **Average Fuel Price**: Unit fuel price per liter or gallon.
  * **Operating Cost / Distance**: Operating cost per kilometer or mile.
* **Sparkline Trajectory**: Catmull-Rom smoothed spline displaying recent fuel economy directly on the dashboard.
* **Quick Action Bar**: One-tap buttons for `"Scan Receipt"` and `"+ Add Fill-Up"`.

### ⛽ 5. Smart Fill-Up Logging (`AddLogView`)
* **Real-Time Calculation Pill**: Instant feedback badge computing trip distance, unit price (Rs./L), and estimated trip economy before saving.
* **Sri Lankan Fuel Grades**: Petrol 92 Octane, Petrol 95 Octane, Auto Diesel, Super Diesel (Euro 4), and Kerosene.
* **One-Tap Station Pills**: Instant brand buttons for *Ceypetco, Lanka IOC, Sinopec, Shell / RM Parks, Other* + Map search.
* **Strict Validation Engine**: Disables saving on empty/invalid inputs and displays inline error warnings if entered odometer $\le$ previous log odometer.
* **Persistent Keyboard Accessory**: Built-in `"Done"` button and interactive scroll dismissal.

### 📈 6. Deep Analytics & Swift Charts
* **Interactive Scrubbing**: Touch-and-drag across charts with live data tooltips and tactile haptic feedback.
* **Fuel Economy Spline**: Catmull-Rom smoothed trajectory with area fill and dynamic target goal lines.
* **Monthly Spending Bar Chart**: Visualizes month-over-month fuel spending trends with rounded gradient bars.
* **Time-Range Filters**: `30 Days`, `6 Months`, `1 Year`, and `All Time`.
* **Vehicle Insights Grid**: Peak economy, lowest economy, average fill-up cost, and cruise cost per 100 km.

### 🗂️ 7. Searchable History & Log Detail View
* **Monthly Chronological Grouping**: Logs grouped by month and year with total expense and volume headers.
* **Brand Filter Carousel**: Filter by Sri Lankan station brands.
* **Full-Text Search**: Search by station name, city/locality, fuel grade, or driving notes.
* **Swipe-to-Delete**: Swipe action with haptic confirmation.
* **Detailed Station Pin**: Embedded MapKit view showing the exact filling station coordinate.

### ⚙️ 8. Localization, Units & CSV Export
* **Sri Lankan Localization Default**:
  * Currency: **LKR (`Rs.`)** with instant toggle to USD (`$`), EUR (`€`), GBP (`£`), INR (`₹`), etc.
  * Units: **Metric (km, Liters, km/L, Rs/L)** with toggle to Imperial (Miles, Gallons, MPG).
* **RFC-4180 CSV Export**: One-tap export via `ShareLink` for Excel, Numbers, and Google Sheets.
* **Light & Dark Mode App Icons**: Uses `logolight.png` in Light Mode and `logodark.png` in Dark Mode.

---

## 🛠️ Architecture & Technology Stack

```
FuelMate/
├── FuelMateApp.swift                    # App Entry Point & Core Data injection
├── MainTabView.swift                    # 4-Tab Navigation (Dashboard, History, Analytics, Settings)
├── Theme.swift                          # Design System Tokens, Sri Lankan Ecosystem Constants, Haptics
├── Services & Persistence/
│   ├── PersistenceController.swift      # Programmatic Core Data (Vehicle <-> FuelLog)
│   ├── ReceiptScannerService.swift      # Apple Vision Framework OCR & Regex Parser
│   ├── StationSearchService.swift       # MapKit MKLocalSearch Station Locator
│   ├── LocationManager.swift            # CoreLocation GPS Geocoding Provider
│   └── UnitSettings.swift               # Localization, Currency, and RFC-4180 CSV Export
├── ViewModels/
│   └── FuelLogViewModel.swift           # @MainActor State, Validations, and Fleet Calculations
└── Views/
    ├── DashboardView.swift              # Executive Gauge, KPI Grid, Quick Actions
    ├── AddLogView.swift                 # Fill-Up Entry Form, Brand Pills, Inline Validation
    ├── ReceiptScannerView.swift         # PhotosPicker, Laser Scanning HUD, OCR Auto-fill
    ├── StationPickerMapView.swift       # Interactive MapKit Station Search & Pin Selector
    ├── AnalyticsView.swift              # Interactive Swift Charts with Touch Scrubbing
    ├── HistoryView.swift                # Searchable Monthly Log List & LogDetailView
    └── VehicleManagementView.swift      # Fleet CRUD & Active Vehicle Switcher
```

---

## 🧪 Unit Test Suite

The test suite covers Core Data relationships, multi-vehicle management, odometer regression guards, input validations, and station brand classification:

```bash
DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer xcrun xcodebuild test \
  -project FuelMate.xcodeproj \
  -scheme FuelMate \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:FuelMateTests
```

**Results**:
```
Test suite 'FuelMateTests' started
Test case 'FuelMateTests.testMultiVehicleManagement()' passed
Test case 'FuelMateTests.testNegativeOrZeroMetricsThrowError()' passed
Test case 'FuelMateTests.testOdometerRegressionThrowsError()' passed
Test case 'FuelMateTests.testSeedSriLankanDemoData()' passed
Test case 'FuelMateTests.testStationBrandDetection()' passed
Test case 'FuelMateTests.testVehicleAndFuelLogRelationship()' passed

** TEST SUCCEEDED **
```

---

## 📱 System Requirements
- **iOS 17.2+**
- **Xcode 15.2+**
- **Swift 5.9+**
- Architecture: 100% Native Apple frameworks (`SwiftUI`, `Core Data`, `Swift Charts`, `Vision`, `MapKit`).
