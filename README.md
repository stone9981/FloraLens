# 花识 FloraLens

拍一朵花，认识它的全部 —— 并把它做成一张能发朋友圈的卡片。

跨端方案是 Flutter（一套 Dart 代码 → Android / iOS / Web / 桌面），当前交付 Android 版可安装 APK。

---

## 一、它能做什么

| 能力 | 说明 |
| --- | --- |
| 拍照识花 | 自研取景界面 + 构图引导框，拍完自动压缩上传，平均 2~4 秒出结果 |
| 相册识图 | 从相册选一张已有照片，流程完全相同 |
| 可插拔识别引擎 | Plant.id / Pl@ntNet / Kindwise / 自建服务，设置页随时切换 |
| 大模型生成档案 | 统一走 OpenAI 兼容协议，云端厂商与本地 Ollama / llama.cpp 通吃 |
| 精美分享卡片 | 4 套模板（杂志 / 极简 / 标本馆 / 夜色），3x 离屏渲染导出 1080px 高清 PNG |
| 一键分享 | 保存到系统相册 + 调起系统分享面板（微信、朋友圈、小红书、微博…） |
| 历史记录 | 本地保存原图与卡片，可随时重新出图，支持容量上限自动裁剪；拍照与相册选图都入册，并标注来源 |
| 配置备份与恢复 | 一键导出全部设置为 JSON，换设备时导入即可，不用再敲一遍 API Key |
| 离线兜底 | 内置 50 种常见花卉中文档案，没有网络也能给出可读内容 |

---

## 二、技术架构

```
lib/
├─ core/          主题、路由、统一 Result/异常、文案常量
├─ data/
│  ├─ models/     Plant / PlantProfile / AppSettings / HistoryItem
│  ├─ engine/     IdentificationEngine 抽象 + 各引擎实现 + 混合引擎 + 工厂
│  ├─ llm/        OpenAI 兼容客户端 + 植物档案生成器
│  ├─ local/      SharedPreferences 设置仓库、JSON 文件历史仓库
│  └─ offline/    内置常见花卉词典
├─ services/      图片压缩、卡片离屏导出、相册保存与系统分享
├─ providers/     Riverpod：设置、历史、识别主流程状态机
├─ widgets/       通用 UI 组件
└─ features/      splash / home / capture / result / history / settings / document
```

**识别主流程**（`providers/identification_provider.dart`）：

```
选图 → 压缩到长边 1600px → 引擎识别（返回候选列表）
     → [混合引擎] 置信度不足时追加一次复核请求（失败则静默跳过）
     → 图片落盘到受管目录 → 写入历史
     → 大模型生成中文档案（失败则降级内置词典）
     → 回写历史 → UI 渲染
```

任何一步失败都不会让页面白屏：识别失败给重试 + 手动选品种，大模型失败自动降级到内置词典，
复核引擎失败只降级为一条提示文案。

---

## 三、配置（首次打开必读）

### 1. 识别引擎（五选一）

| 引擎 | 特点 | 获取方式 |
| --- | --- | --- |
| Plant.id | 覆盖最广、字段最全，商业级首选 | 官网注册即送试用额度 |
| Pl@ntNet | 科研机构维护，免费额度友好 | my-api.plantnet.org 注册 |
| Kindwise | 企业级接口，独立额度与账单 | 控制台创建 key |
| **视觉大模型（VLM）** | 不用另配植物服务，一套 LLM 配置就能看图识花 | 见下方说明 |
| 自建服务 | 图片不出内网，可接自己的模型 | 见下方协议 |

#### 视觉大模型引擎

不想注册植物站点账号时，可以直接让能读图的大模型来认。识别与文案**共用**同一套
Base URL 与 API Key，只是模型名不同——设置页里分别叫「识别模型」和「文案模型」。

推荐搭配（识别用视觉模型，写文案用便宜的文本模型）：

| 服务商 | 识别模型 | 文案模型 |
| --- | --- | --- |
| 通义千问 | `qwen-vl-plus` / `qwen-vl-max` | `qwen-plus` |
| 智谱 GLM | `glm-4v-flash` / `glm-4.5v` | `glm-4-flash` |
| 火山方舟 | `doubao-vision-pro-32k` | `doubao-pro-32k` |
| OpenAI | `gpt-4o-mini` | `gpt-4o-mini` |
| Ollama | `qwen3-vl:8b` / `llava:latest` | `qwen2.5:7b` |

请求走 OpenAI 多模态格式（`content` 里同时带 `text` 与 `image_url`），
`temperature` 固定 0.15，模型只回一个 JSON：

```jsonc
{ "candidates": [
    { "scientificName": "Rosa chinensis", "commonName": "月季",
      "family": "蔷薇科", "genus": "蔷薇属", "confidence": 0.91 }
]}
```

注意：**DeepSeek 官方模型没有视觉能力**，不能当识别引擎用。
视觉引擎比专用植物模型慢（约 3~8 秒），遇到稀有品种时可能「硬编」一个近亲，
专业需求仍建议用 Plant.id。

#### 混合策略：置信度不足时自动复核

为了兼顾「快」与「准」，选视觉大模型时可以设置一条回落规则：

> 视觉模型给出的最高置信度低于阈值时，自动改问 Plant.id / Pl@ntNet / Kindwise
> （默认优先 Plant.id），并用它的结果作为最终答案。

- **阈值**默认 65%，可在 30%~95% 之间调。调低＝少被打断、快一些；调高＝更严谨。
- **复核方**默认「自动」，即按 Plant.id → Pl@ntNet → Kindwise → 自建服务的顺序，
  跳过没填 Key 的那家。也可以手动指定只问某一家。
- 复核引擎**没配 Key、网络失败或超过 15 秒**都不会让识别失败，只会保留视觉模型的
  原结果并在结果页给出提示。
- 复核不是无脑覆盖：只有复核方把握**高于**视觉模型时才改判；否则仍以视觉模型为准，
  但会把复核方的候选一起列进「可能相近的品种」，方便手动核对。
- 结果页顶部会显示一条提示，说明这次为什么改判、最终采信了谁。

**自建服务协议**（POST JSON）：

```jsonc
// 请求
{ "image": "<base64 jpeg>", "topk": 6 }

// 响应
{ "results": [
    { "scientificName": "Rosa chinensis", "commonName": "月季",
      "family": "蔷薇科", "genus": "蔷薇属", "confidence": 0.93, "aliases": [] }
]}
```

### 2. 大模型（生成花语 / 植物志 / 养护要点）

全部走 `/chat/completions` 兼容协议，设置页内置以下预设，可直接选：

| 预设 | Base URL | 默认模型 |
| --- | --- | --- |
| DeepSeek | `https://api.deepseek.com/v1` | deepseek-chat |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | qwen-plus |
| 智谱 GLM | `https://open.bigmodel.cn/api/paas/v4` | glm-4-flash |
| Kimi | `https://api.moonshot.cn/v1` | moonshot-v1-8k |
| 火山方舟 | `https://ark.cn-beijing.volces.com/api/v3` | doubao-pro-32k |
| OpenAI | `https://api.openai.com/v1` | gpt-4o-mini |
| **Ollama（本地）** | `http://192.168.x.x:11434/v1` | qwen2.5:7b |
| **llama.cpp / LM Studio** | `http://192.168.x.x:8080/v1` | local-model |
| 自定义 | 任意 OpenAI 兼容端点 | — |

> 手机上使用本机模型：**把 `localhost` 换成电脑的局域网 IP**，并保证手机与电脑在同一 WiFi。
> 应用已在 `network_security_config.xml` 中放行明文 HTTP，就是为这个场景准备的。

#### 3. Agnes AI（注册即免费，可选）

Agnes 是 OpenAI 兼容的多模态模型服务商，文本、识图、生图、生视频都免费开放、无需绑卡。
设置页里选中「Agnes AI（注册即免费）」后，会出现一个引导块：

- **打开注册页** —— 直接跳到 `platform.agnes-ai.com`，省掉手动输网址；
- **粘贴 Key** —— 在 Agnes 控制台复制 `sk-` 开头的 Key 后，在 App 里一键粘进来并保存；
- 需要识图识别时，可顺手把识别引擎切到「视觉大模型」，用 `agnes-2.5-flash`。

> **关于"自动注册"**：Agnes 没有开放程序化注册接口 —— 账号必须在网页上用邮箱/GitHub 注册，
> API Key 也必须人工在控制台点出来，任何声称能自动注册的服务都要求你把密码或验证码交出去，
> 不要做。所以这里的自动化止步于"帮你打开注册页 + 帮你粘贴保存 Key"，
> 剩下的两步仍然需要你亲自点一下。Key 只存在本机，不会上传到任何第三方服务器。

关闭「启用大模型」后，App 会退化为内置词典模式，依然可以识别与出图。

### 4. 配置备份与恢复

设置在「设置 → 配置备份与恢复」里可以导出成一个 `floralens-config-<时间>.json`：

- **导出**：生成文件后调起系统分享面板，可以存到微信文件传输助手、邮件、网盘；
- **导入**：在新设备上选这个 JSON 文件，确认后即可恢复全部设置（含各引擎 Key、混合策略、卡片水印、主题）；
- **恢复默认**：清空所有 Key 与外观设置。

> 备份文件里是**明文 API Key**。导出后请自行决定发到哪里，不要丢进公开群或公开仓库。
> 文件结构：`{"format":"floralens.config","version":1,"appVersion":"…","settings":{…}}`。

---

## 四、构建与运行

### 环境

```bash
flutter --version   # 本项目基于 Flutter 3.47.5 / Dart 3.13.4
java -version       # JDK 17
```

Android SDK 侧需要：

| 组件 | 版本 | 说明 |
| --- | --- | --- |
| platforms | android-36 / android-37 | 部分插件（permission_handler_android 14.x）硬编码 `compileSdk = 37` |
| build-tools | 36.0.0 / 37.0.0 | 与 compileSdk 对齐 |
| NDK | 28.2.13676358 | 由 `flutter.ndkVersion` 自动拉取 |
| cmdline-tools | latest | `sdkmanager` 用 |

首次运行前：

```bash
flutter pub get
```

### 出包

```bash
# 调试包
flutter build apk --debug

# 发布包（按 ABI 拆分，体积更小）
flutter build apk --release --split-per-abi

# 上架 Google Play 用 AAB
flutter build appbundle --release
```

产物在 `build/app/outputs/flutter-apk/` 与 `build/app/outputs/bundle/release/`。

一键脚本：

```bash
./scripts/build_android.sh          # 默认 release + 拆包
./scripts/build_android.sh debug    # 调试包
```

### 签名

仓库已内置一份开发用签名：`android/keystore/floralens.jks` + `android/key.properties`。

**上架前请务必换成自己的签名**：

```bash
keytool -genkeypair -v -keystore android/keystore/floralens.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias floralens \
  -dname "CN=YourName, OU=..., O=..., L=..., ST=..., C=CN"
```

然后按 `android/key.properties.example` 更新 `android/key.properties`。
两个文件都已在 `.gitignore` 中排除，请勿提交到公开仓库。

### 国内网络构建排错

如果 `flutter build apk` 卡在 Gradle 阶段，多半是依赖源或 SDK 版本问题。已验证的处理方式：

**1. Maven 源走国内镜像。** Gradle 不读 `HTTPS_PROXY` 环境变量，代理要用 JVM 系统属性：

```
~/.gradle/gradle.properties
    systemProp.http.proxyHost=127.0.0.1
    systemProp.http.proxyPort=<端口>
    systemProp.https.proxyHost=127.0.0.1
    systemProp.https.proxyPort=<端口>
```

配合 `~/.gradle/init.d/mirrors.gradle` 把 `repo.maven.apache.org` / `dl.google.com` / `plugins.gradle.org`
统一换成阿里云与腾讯镜像（实测 1.4~4.5MB/s，而 Maven Central 只有 ~35KB/s）。

**2. 不要在 `settings.gradle.kts` 里用 `RepositoriesMode.PREFER_SETTINGS`。**
Flutter Gradle 插件是通过 `rootProject.allprojects { repositories.maven { url ".../download.flutter.io" } }`
在**项目级**注册引擎仓库的，PREFER_SETTINGS 会把它整体忽略，报
`Could not find io.flutter:arm64_v8a_release:1.0.0-<hash>`。

**3. 不要手写 `splits { abi { ... } }`。**
Flutter 插件按 `target-platform` 写 `ndk.abiFilters`，两者同时存在会报
`Conflicting configuration ... ndk abiFilters cannot be present when splits abi filters are set`。
拆包交给 `--split-per-abi` 即可。

**4. SDK 平台目录名带扩展级别。**
新版 SDK 把 API 37 装成 `platforms/android-37.0`，而 AGP 找的是 `android-37`，会报
`Failed to find target with hash string 'android-37'`。建一个符号链接即可：

```bash
ln -s android-37.0 $ANDROID_HOME/platforms/android-37
```

**5. 8GB 内存机器上让 Kotlin 走进程内编译**，避免 Kotlin 编译守护进程额外占一个 JVM 并挂起：

```
kotlin.compiler.execution.strategy=in-process
```

---

## 五、分享到朋友圈 / 小红书

1. 识别成功后点「生成分享卡片」；
2. 选择模板，点「保存到相册」；
3. 打开微信 → 朋友圈 → 从相册选这张图，直接发。

也可以直接点「分享到」，系统会弹出微信 / 小红书 / 微博 / 蓝牙等全部接收方。

> 说明：微信朋友圈的官方分享 SDK 需要开放平台账号 + 应用审核，个人开发者基本过不了审；
> 系统分享面板本来就能到微信，还能覆盖更多平台，因此这里走系统面板 + 相册保存的组合。

---

## 六、上架前检查清单

- [ ] 换成自己的签名 keystore，并妥善备份
- [ ] `android/app/build.gradle.kts` 里确认 `applicationId` 与 `versionCode`
- [ ] 确认隐私政策文本（`settings_page.dart` 内的 `_privacyText`）与实际行为一致
- [ ] 如需收紧安全策略：把 `network_security_config.xml` 的明文开关关掉
- [ ] 稳定后把 `build.gradle.kts` 的 `isMinifyEnabled` 改为 `true`（proguard 规则已备好）
- [ ] 国内应用市场通常要求软著 + 备案，提前准备

---

## 七、后续路线

- **iOS**：同一套 Dart 代码，`flutter build ios` 即可，只需补 `ios/Runner/Info.plist` 的权限描述
- **Web / 桌面**：`flutter build web` / `flutter build macos`，UI 已是自适应
- 批量导出、长按识别、植物养护提醒、识别结果导出为 PDF 图鉴

---

## 八、许可

代码可自由使用与修改；内置花卉文本资料来自公开常识整理，引用时请自行核对。
