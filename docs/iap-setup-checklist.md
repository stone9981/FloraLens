# FloraLens 内购（IAP）上架清单 · App Store Connect

> 适用：iOS 端 `com.floralens.pro.monthly` / `com.floralens.pro.yearly` / `com.floralens.remove_ads`
> 配套代码：`lib/config/app_config.dart`（`IapProducts`）与 `lib/services/iap_service.dart`
> 目标：让「升级 Pro / 去广告 / 恢复购买」在真机与审核环境都能正常走通

---

## App Store 命名与元数据（商店展示名：PetalLens）

### 命名决策
- 商店展示名定为 **`PetalLens`**（已逐个核实 `VerdeLens` / `PetalLens` / `GardenLens` 均未被占用，最终选 PetalLens）。
- **为什么不用 FloraLens**：App Store 已有一个正经的 iPad app 就叫 `FloraLens`（他人品牌）。直接用会触发 **Guideline 4.1 品牌混淆**被拒；"FloraLens AI" 只是在他人品牌词后追加，风险仍为中/高，故改用明显区分、但保留 `Lens` 调性的 `PetalLens`（Petal=花瓣 + Lens=识别，最贴「拍照识花」核心功能）。
- **品牌资产保留**：开发者名（Developer / Artist Name）仍可填 `FloraLens`（这是账号名，不受 app 名唯一性限制，商店页底部照常显示 FloraLens）；副标题/描述可写 "from FloraLens"。代码内 `CFBundleDisplayName`、logo、域名维持 FloraLens 不变。

### 创建 New App 时填写
- [ ] Platforms：勾 **iOS**
- [ ] App Name：`PetalLens`
- [ ] Primary Language：简体中文 或 English（二选一，另一种语言靠下方元数据补）
- [ ] Bundle ID：必须与该 App 的 **Explicit App ID 完全一致**（如 `com.floralens.<suffix>`），且之前已在 Developer 后台建好、已勾 In-App Purchase
- [ ] SKU：内部代号，字母数字串，**用户不可见**
- [ ] ⚠️ Bundle ID 一旦关联并提交即**固定**，改需重建 App 记录、丢失审核历史；App Name 后续可作元数据修改，风险低

### 双语言元数据（按设备系统语言展示）
路径：App Store Connect → 你的 App → **App Information → Localizable Information**，分别添加 **简体中文**、**繁體中文**、**English (U.S.)** 三套；同一 App 在不同国家商店显示对应语言（简体中文→中国大陆；繁體中文→中国台湾/中国香港/中国澳门；英文→美国及默认英文区）。

| 字段 | 简体中文 | English (U.S.) |
| --- | --- | --- |
| 商店名 | `PetalLens`（可加「PetalLens 识花」） | `PetalLens` |
| 副标题 Subtitle | 拍照识别植物与花卉 | Identify plants by photo（24 字符，<30 上限；flowers 由关键词覆盖） |
| 关键词 Keywords（逗号分隔、无空格、≤100 字符） | `植物识别,识花,花草,拍照识图,园艺,盆栽,树叶,养护` | `plant identifier,flower identifier,garden,botany,leaf,plant care` |
| 描述 Description | 见下方「三语描述文案」 | 见下方「三语描述文案」 |
| 截图/预览 | 可选本地化；展示真实界面 | 可选本地化；展示真实界面 |

- [ ] 两套关键词/描述均为**原创**，不包含竞品 app 名或商标词（避免 4.1 / 元数据违规）
- [ ] 描述与 app 实际功能一致（写了去广告，付费后确有去广告）

### 繁體中文文案（中国台湾 / 中国香港 / 中国澳门）⭐ 必须纯繁体，勿简繁混排

> 这一套文案整体喂给繁體中文商店，所有字必须转繁体（识→識、别→別、与→與、图→圖、园→園、树→樹、叶→葉、养→養、护→護）。

| 字段 | 繁體中文（直转） | 台湾地道写法（备选） |
| --- | --- | --- |
| 商店名 | `PetalLens`（可加「PetalLens 識花」） | 同左 |
| 副标题 Subtitle | `拍照識別植物與花卉`（9 字，<30） | `拍照辨識植物與花卉` |
| 关键词 Keywords | `植物識別,識花,花草,拍照識圖,園藝,盆栽,樹葉,養護` | `植物辨識,花草辨識,植物圖鑑,拍照識花,園藝,盆栽,樹葉,養護` |
| 描述 Description | 见下方「三语描述文案」 | 同左 |
| 截图/预览 | 可选本地化；展示真实界面 | 同左 |

- [ ] 台湾用户更惯用「辨識」而非「識別」，植物类 app 也常用「植物圖鑑」；用右列写法更地道，香港/澳门两者皆接受
- [ ] 描述正文同样全繁体（含标点符号习惯），不要出现简体字
- [ ] 三套（简/繁/英）关键词各自独立、均原创，互不复制对方语言词

### 三语描述文案（可直接粘贴到对应本地化 Description 框）

> 均为原创、不含竞品名/商标词；付费后确有去广告，与功能一致。每个本地化框单独粘贴对应语言全文。

**① 简体中文（中国大陆）**
```
PetalLens 用照片识别植物与花卉。拍照或从相册选图，AI 即时生成植物档案——名称、科属、花期、养护要点、是否有毒等，适合园艺爱好者、徒步与自然观察。

【主要功能】
• 拍照或选图识别植物与花卉
• AI 生成植物档案：科属、花期、养护建议、毒性提示
• 识别历史本地保存，随时回看
• 分享卡片带拍摄地点水印

【升级 Pro】
• 去掉广告，体验更干净
• 解锁更详细的植物档案与无限次识别
• 支持按月或按年订阅（年付更划算），并支持恢复购买

去广告也可单独一次性购买，永久移除广告。
```

**② English (U.S.)**
```
PetalLens identifies plants and flowers from a photo. Snap or pick from your library, and AI instantly builds a plant profile — name, family, bloom season, care tips, toxicity, and more. Built for gardeners, hikers, and nature lovers.

Key features:
• Identify plants & flowers by camera or photo library
• AI-generated profiles: family, bloom season, care tips, toxicity notes
• Save identification history on device, revisit anytime
• Share cards with a location watermark

Go Pro:
• Ad-free, cleaner experience
• Unlock detailed profiles and unlimited identifications
• Monthly or yearly subscription (yearly saves more); restore purchases supported

Remove Ads is also available as a one-time purchase for permanent ad removal.
```

**③ 繁體中文（中国台湾 / 中国香港 / 中国澳门）**
```
PetalLens 用照片辨識植物與花卉。拍照或從相簿選圖，AI 即時生成植物檔案——名稱、科屬、花期、養護要點、是否有毒等，適合園藝愛好者、登山與自然觀察。

【主要功能】
• 拍照或選圖辨識植物與花卉
• AI 生成植物檔案：科屬、花期、養護建議、毒性提示
• 辨識紀錄本機保存，隨時回看
• 分享卡片帶拍攝地點浮水印

【升級 Pro】
• 去掉廣告，體驗更乾淨
• 解鎖更詳細的植物檔案與無限次辨識
• 支援按月或按年訂閱（年付更划算），並支援恢復購買

去廣告也可單次購買，永久移除廣告。
```

- [ ] 三套描述均为原创、与功能一致（写了去广告，付费后确有去广告）
- [ ] 繁体版全文繁体，无简体字

### App Information 其他合规字段（FloraLens = 拍照识植物工具 app，非游戏/非医疗/非社交）

> 路径：App Store Connect → 你的 App → **App Information / App Store** 标签页。以下逐项给出推荐填法。

| 字段 | 推荐填法 | 说明 |
| --- | --- | --- |
| **Category（类别）** | Primary=`Reference`（参考）+ Secondary=`Education`（教育） | 识花识植物属工具型图鉴，Reference 最贴切；次类别可选 Education 或 Lifestyle，提升对应分区曝光 |
| **Content Rights（内容版权）** | **No**（不包含第三方内容） | app 仅展示 AI 生成的植物档案（你签的 LLM API 输出）+ 用户自己的照片，未内置/抓取维基图库、PlantNet 等第三方版权素材；若以后接入外部图库再改 Yes 并确认已获授权 |
| **License Agreement（许可协议）** | **Standard EULA（Apple 标准许可协议）** | 零成本、覆盖基本条款，绝大多数独立 app 用之；产品页甚至不显示许可链接。除非有特定法律条款，否则不要写 Custom EULA |
| **Age Ratings（年龄分级）** | 问卷全选 None/No → 结果 **4+** | 无暴力/色情/赌博/医疗建议；User-Generated Content 也选 None（用户照片仅本地处理、不形成公开社交流）；位置只写水印不分享他人 → 不影响分级。植物类工具标准档 |
| **Learn More About Age Ratings** | 帮助链接，不用填 | 点开看说明即可 |
| **App Encryption Documentation（加密文档）** | 不提交（标准豁免） | app 仅用标准 HTTPS/TLS 联网，属加密出口合规**豁免类**；提审遇「Does your app use encryption?」选标准豁免项即可。省事做法：在 Agreements, Tax, and Banking 底部做一次年度 Export Compliance 认证，之后各版本免重复答 |
| **App Store Regulations & Permits（监管许可）** | 留空 / N/A | 受监管行业（金融/新闻/医药等）许可区，FloraLens 不沾 |
| **China Mainland ICP Filing Number（中国大陆 ICP 备案号）** | ⚠️ 初期建议**排除中国大陆区**，不填 | 仅当勾选中国大陆为可售地区时才强制要求。**不进中国区 → 此字段留空、不影响全球上架**。若想进中国区，门槛极高：①基础 ICP 备案通常要求 app 后端托管在中国大陆 + 中国境内主体，外国/个人开发者一般无法直接备案，需借中国实体或代理/出版商代办；②FloraLens 含 IAP+广告=经营性 app，按中国规定不止基础备案，还需 **ICP 经营许可证（B25）**（企业主体、注册资本等门槛）；③配套独立隐私政策网页 + PIPL 首次弹窗同意。初期在 Pricing & Availability 把「中国大陆」移出可售地区，先全球上线 |
| **Vietnam Game License（越南游戏许可）** | 忽略 | 仅针对游戏在越南分发，FloraLens 非游戏 |
| **Regulated Medical Devices（受监管医疗设备）** | 不适用 / No | 只有自称医疗设备/做医疗诊断才相关，识植物不沾 |
| **App Store Server Notifications（服务器通知）** | 留空（可选） | 把购买/订阅事件推到你自己的服务器；FloraLens 走客户端本地处理 IAP（`purchaseStream` + `isPro` 持久化），无后端，不需配 |
| **App-Specific Shared Secret（App 专用共享密钥）** | 留空（可选） | 用于在你服务器校验 IAP 收据；同样走客户端本地校验、无后端服务器，不需要 |

- [ ] 分级问卷做完后确认结果 = **4+**（与「适合 4 岁以上」一致）
- [ ] 初期 Pricing & Availability 暂不包含「中国大陆」，避免 ICP 许可前置卡上架；**是否进中国区是二选一**：进→必须备（且经营性 app 要 B25 许可证），不进→此字段留空、全球照常上架
- [ ] 加密合规走标准豁免，不提交任何加密文档

---

## 0. 前置：协议与税务（不上架一定会失败）

App Store 的内购依赖**账户级协议**，必须在创建商品前完成，否则 `InAppPurchase.isAvailable()` 返回 false、商品查询为空。

- [ ] **签署《Paid Apps Agreement》**
  - 路径：App Store Connect → 商务 → 协议、税务和银行业务（Agreements, Tax, and Banking）
  - 找到「Paid Apps」协议，状态变为 **Active**
- [ ] **填税务（Tax Forms）**
  - 美国税务表（W-9，个人开发者通常填这个）或对应地区表单
  - 状态变为 **Active**
- [ ] **填银行账户（Bank）**
  - 添加收款银行账户并设为「用于付费 App」
  - 状态变为 **Active**
- [ ] **填联系人信息**（法务 / 财务联系人）
- [ ] 等待苹果处理（通常几分钟到 1 个工作日，状态变 Active 即可）

> 三者（Agreement + Tax + Bank）全部 Active 后，真机/沙盒才能查到商品。

---

## 1. 商品 ID 与代码侧核对

代码里已写定以下 ID（`lib/config/app_config.dart`），**App Store Connect 里创建的商品 ID 必须逐一完全一致**（大小写、点号都不能错）：

| 商品 ID | 类型 | 说明 |
| --- | --- | --- |
| `com.floralens.pro.monthly` | 自动续期订阅（Auto-Renewable Subscription） | Pro 会员·月付 |
| `com.floralens.pro.yearly` | 自动续期订阅（Auto-Renewable Subscription） | Pro 会员·年付 |
| `com.floralens.remove_ads` | 非消耗型（Non-Consumable） | 永久去广告 |

- [ ] 三个 ID 与 `IapProducts.all` 完全一致
- [ ] 若需改名/增删，改 `IapProducts` 后**重新构建**再提审

---

## 2. 创建订阅（pro.monthly / pro.yearly）

订阅必须放进一个**订阅组（Subscription Group）**。

- [ ] App Store Connect → 你的 App → **功能 → 内购项目（In-App Purchases）**
- [ ] 点击「+」→ 选择 **自动续期订阅（Auto-Renewable Subscription）**
- [ ] **订阅组**：新建组，名称如 `FloraLens Pro`
- [ ] 在组内创建两个等级（Level）：
  - 等级 1：`com.floralens.pro.monthly`
  - 等级 1：`com.floralens.pro.yearly`（同组可并列，年付建议设为更高「价值」档）
- [ ] 每个商品填写：
  - [ ] **参考名称**（内部可见）：如 `FloraLens Pro 月付` / `FloraLens Pro 年付`
  - [ ] **产品 ID**：严格填 `com.floralens.pro.monthly` / `com.floralens.pro.yearly`
  - [ ] **订阅时长**：1 个月 / 1 年
  - [ ] **价格**：选档（月付建议低价、年付≈月付×10 更划算）
  - [ ] **可续期期限 / 试用**：可选 7 天免费试用（Optional，按需）
- [ ] **本地化（至少中、英，App 本身是双语）**
  - [ ] 中文（简体）：显示名称 + 描述
  - [ ] English (U.S.)：显示名称 + 描述
  - 名称示例：Pro 会员（月）/ Pro Membership (Monthly)
- [ ] 上传**审核截图**（展示订阅权益的界面，如付费墙）
- [ ] 提交订阅组供苹果审核（首次创建订阅组需审核通过）

---

## 3. 创建非消耗型（remove_ads）

- [ ] 内购项目 → 「+」→ 选择 **非消耗型项目（Non-Consumable）**
- [ ] **参考名称**：FloraLens 永久去广告
- [ ] **产品 ID**：`com.floralens.remove_ads`
- [ ] **价格**：单一定价
- [ ] **本地化**：中 / 英 显示名称 + 描述
- [ ] 上传审核截图
- [ ] 保存（非消耗型随 App 版本一起送审）

---

## 4. App 版本里「勾选」这些 IAP

商品创建后，必须在提审的 **App 版本**里关联，否则审核员看不到、会拒。

- [ ] App Store Connect → 你的 App → **App Store**（左侧）→ 选择要提审的版本
- [ ] 滚动到 **「App 内购买项目」** 区块
- [ ] 勾选三个商品：`pro.monthly` / `pro.yearly` / `remove_ads`
- [ ] 填写版本**审核备注（Notes）**：说明内购用途、恢复购买入口位置、测试账号（沙盒）

---

## 5. 沙盒测试（上线前必测）

- [ ] **创建沙盒测试员**
  - 路径：App Store Connect → 用户和访问 → 沙盒测试员（Sandbox Testers）
  - 用一个**未绑过真钱**的测试 Apple ID（邮箱格式即可）
- [ ] **真机登录沙盒**
  - 设置 → App Store → 沙盒账户，登录该测试员
  - 或在 App 内发起购买时按提示登录
- [ ] 验证：
  - [ ] `pro.monthly` / `pro.yearly` 能拉到价格并走购买流程
  - [ ] 购买成功后 `AppSettings.isPro` 被置真、广告消失
  - [ ] **恢复购买**（设置页入口）能找回已购状态
  - [ ] 订阅到期/取消逻辑（沙盒时间会加速，几分钟≈一个月）

> 模拟器通常 `isAvailable() == false`，务必用真机 + 沙盒测。

---

## 6. 代码侧上线前核对（ checklist 联动 `app_config.dart`）

- [ ] `AdsConfig.useTestAds` 在发布构建中改为 `false`（或按 flavor 区分）
- [ ] `AdsConfig` 全部 `production*` 占位 ID 替换为 AdMob 后台真实值
- [ ] `IapProducts` 三个 ID 与 App Store Connect **一字不差**
- [ ] 原生 App ID 同步替换：
  - [ ] `ios/Runner/Info.plist` → `GADApplicationIdentifier`
  - [ ] `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID`
- [ ] 设置页「恢复购买」入口可用（审核硬性要求）
- [ ] 付费墙文案中英文完整（用户走英文系统也看得懂）

---

## 7. 常见被拒点（提前规避）

- ❌ 没有「恢复购买」按钮 → 必拒。本 App 设置页已提供，保留。
- ❌ 内购商品未在 App 版本里勾选 → 审核员看不到商品。
- ❌ 协议/税务/Bank 未 Active → 商品查询为空，购买直接失败。
- ❌ 描述/截图与功能不符（如写了「去广告」却仍显示广告）→ 拒。
- ❌ 消耗型误设成非消耗型（去广告应是**非消耗型**，订阅是**自动续期**）。
- ❌ 锁定后未本地持久化 `isPro`（本 App 走 `AppSettings` 持久化，重装后可恢复购买找回）。

---

## 附：快速路径（最小可上线）

若想最快上线，可先只做 **`com.floralens.remove_ads`（非消耗型，永久去广告）**，
暂不上订阅；后续再加 `pro.monthly` / `pro.yearly`。代码已预留三个 ID，随时启用。
