# FloraLens 内购（IAP）上架清单 · App Store Connect

> 适用：iOS 端 `com.floralens.pro.monthly` / `com.floralens.pro.yearly` / `com.floralens.remove_ads`
> 配套代码：`lib/config/app_config.dart`（`IapProducts`）与 `lib/services/iap_service.dart`
> 目标：让「升级 Pro / 去广告 / 恢复购买」在真机与审核环境都能正常走通

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
