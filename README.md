# 在日工作助手 / バイトログ / ShiftLog Japan

一个面向在日留学生和外国劳动者的本地优先 iOS 工时与工资管理 App。工程使用 Swift 6、SwiftUI、SwiftData、Charts、EventKit、UserNotifications 和 StoreKit 2，最低支持 iOS 18；iOS 26 使用系统 Liquid Glass，旧系统使用原生材质降级。

> App 中的工时、工资和许可提示仅用于记录、估算与风险提醒，不构成法律、税务或行政建议。

## 运行

1. 使用 Xcode 26 或更新版本打开 `ShiftLogJapan.xcodeproj`。
2. 选择 `ShiftLogJapan` scheme 和一个 iPhone 模拟器。
3. 直接运行。模拟器无需签名；真机运行前请在 Signing & Capabilities 中选择自己的 Team，并将示例 Bundle ID 替换为自己的标识。
4. 首次启动依次选择语言、用途和工时上限，并创建第一份工作。

命令行构建：

```sh
xcodebuild -project ShiftLogJapan.xcodeproj \
  -scheme ShiftLogJapan \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/ShiftLogDerived \
  CODE_SIGNING_ALLOWED=NO build
```

## 已实现的主要功能

- 首次设置：中、日、英语言，用途选择，可编辑周工时限制和免责声明确认。
- 多工作：工作资料、颜色、手动时薪输入、时薪历史、默认班次、交通费、时间取整、月/周/双周工资周期、工资日与深夜加薪模板。
- 班次：新增、编辑、复制、软删除、每周重复、重复系列范围编辑/删除、默认单日日期联动、显式跨日模式、计划/实际记录、可视化多段休息、奖金与扣减。
- 冲突与风险：跨工作时间冲突阻止保存；顶部错误摘要可跳转查看冲突记录；周合计超过用户上限时二次确认；计划与实际数据分开保留。
- 日历：首页摘要以及月、周、日、年轻量视图；月历日期可进入日详情并基于所选日期新增。
- 收入：日、周、月、工资周期、年、自定义范围，工作筛选，计划/实际来源，工资分项、工作图表，以及含税费、保险和关联班次的到账差额记录。
- 本地数据：SwiftData 离线保存；JSON 备份/恢复；恢复前自动创建受文件保护的本机备份；UTF-8 BOM CSV 导出。
- 系统服务：班次开始、班次结束确认和发薪日前本地通知；由 App 管理的独立系统日历单向同步；不会修改其他日历事件。
- 隐私：无开发者服务器、登录、分析、跟踪、广告 SDK 或第三方业务 API；附带 Privacy Manifest。
- 商业化边界：`AdProviding`、`NullAdProvider`、`LocalHouseAdProvider`、`SubscriptionProviding` 和 StoreKit 2 权益服务已隔离；默认总开关关闭。
- 演示数据：可从“我的 → 数据”一键加载便利店、餐厅、深夜班次、周工时与到账差额示例。

## 架构

```text
ShiftLogJapan
├── App                 启动、首次设置、主导航
├── CoreModels          SwiftData 本地模型
├── CalculationEngine   纯计算、冲突、风险和工资周期
├── Features            Calendar / Shifts / Jobs / Earnings / Settings
├── Persistence         JSON、CSV 和演示数据
├── SystemServices      EventKit 与 UserNotifications 协议封装
├── Monetization        广告与 StoreKit 2 可替换接口
└── DesignSystem        主题、格式与 Liquid Glass 降级
```

计算层不依赖界面。时间使用 `Date` 与明确日历按分钟累计，货币全程使用 `Decimal`；跨午夜加薪按每分钟边界计算，休息分钟不会获得基本工资或加薪。详细规则见 [计算规则](Docs/CalculationRules.md)。

## 测试

`ShiftLogJapanTests` 覆盖规格书中的 ¥5,325 深夜班次示例、跨日多段休息、休息重叠、加薪叠加与优先级、时间取整、跨工作冲突、多工作周工时、跨年工资周期、日期联动、手动时薪解析与历史时薪。

```sh
xcodebuild -project ShiftLogJapan.xcodeproj \
  -scheme ShiftLogJapan \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/ShiftLogDerived test
```

本次交付验证环境：Xcode 26.6、iPhone 17 Pro / iOS 26.5。App 和全部测试目标编译成功；20 项单元测试及 6 项 UI 测试通过。

## 权限用途

- 通知：用户主动开启后，在班次开始前、班次结束时和发薪日前发送本地提醒。
- 日历：用户为某份工作主动启用后，创建名为 `ShiftLog` 的独立日历并单向维护本 App 创建的事件。
- App 不请求定位、相册、通讯录、麦克风、跟踪或 IDFA 权限。

核心功能在通知或日历权限被拒绝时仍可使用。

## 配置与发布前事项

- 将 `com.example.shiftlogjapan` 替换为正式 Bundle ID。
- 商业化默认关闭。若将来启用，先在 App Store Connect 配置集中声明的月/季度/年产品，并补充 StoreKit Configuration 与完整购买 UI。
- iCloud 标识已集中在 `AppConfiguration`，但当前本地 MVP 未启用 CloudKit entitlement。启用前应完成双设备冲突、软删除和恢复测试。
- 官方链接随 App 打包；发布新版前应复核链接与制度说明日期。

## 当前未完成（P1 / 后续）

- CloudKit 私有数据库的跨设备同步、同步状态和冲突合并 UI。
- 合同、工资单、源泉征收票附件、Face ID、设备端 OCR。
- 最低工资版本数据、小组件、证件提醒和 PDF 月报。
- 完整 StoreKit 测试配置与订阅购买页面（接口与验证服务已预留，默认不可见）。
- 重复排班的双周/指定星期/结束日期规则；自定义工资周期、节假日调整和单次发薪日修改；接近工时上限的主动通知。

逐项完成情况见 [规格对照表](Docs/CompletionStatus.md)。
