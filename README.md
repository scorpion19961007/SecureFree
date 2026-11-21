# SecureFree

**在 Android 17 上恢复被 `FLAG_SECURE` 保护的界面截图能力。**

一个约 12 KB 的 LSPosed 模块。装上并重启后，系统不再把带 `FLAG_SECURE` 的窗口当作"受保护内容"，
所有原本截图后只能得到黑屏、或者截图直接失败的界面，都可以正常截图、录屏、投屏。

> An ultra-small LSPosed module that re-enables screenshots of `FLAG_SECURE` windows on
> **Android 17 (API 37)**. Verified on ColorOS 17 / OnePlus 12.

---

## 支持的版本

| 项目 | 要求 |
|---|---|
| Android | 8.0+ 可安装，**核心目标与实测平台是 Android 17 / API 37** |
| Root | KernelSU / Magisk（需启用 Zygisk） |
| 框架 | LSPosed（官方版 1.9.2+ / 2.x），需开启 Zygisk |
| 实测机型 | OnePlus 12 (PJD110)，ColorOS `PJD110_17.0.0.100(CN01)`，Android 17 / API 37 |

### 实机验证记录

被测页面是「某相机」`com.xxx.xxx` 的去水印结果页
`com.xxx.xxx/.ui.edit.RevertWaterMarkActivity`——它只在**这一个页面**给窗口加了 `FLAG_SECURE`，
同 App 的 `EditActivity` / `GeneralActivity` / `PreviewActivity` 都没有。

修复前：

```
# 窗口确实带保护
fl=LAYOUT_IN_SCREEN FULLSCREEN SECURE LAYOUT_INSET_DECOR ...

# SurfaceFlinger 图层被标记为安全
Layer [1988] (Secure) ff2095c com.xxx.xxx/...RevertWaterMarkActivity#1988
      isSecure=true

# 系统截图 App 拿到空 bitmap，截图直接中止、不落盘
[Longshot][SurfaceControlCompat::screenshot]: spend:13ms.
[Longshot][ImplCapture]: ImplCapture ERROR : bitmap is null
[Longshot][TaskCapture]: Capture bitmap=null
```

修复后：

```
# 图层不再带 (Secure)
Layer [209] fd24389 com.xxx.xxx/...RevertWaterMarkActivity#209

# 系统截图正常落盘，整页真实内容，无黑块
Screenshot_2026-11-21-19-25-24-82_....jpg
```

---

## 为什么不用 Enable Screenshot / DisableFlagSecure

上游 [LSPosed/DisableFlagSecure](https://github.com/LSPosed/DisableFlagSecure) 最新仍是 **v5.0.1（2026-04-04）**，
`v5.0.0` 才升到 Xposed API 101（对应 Android 16），**没有 Android 17 / API 102 的版本**。

把它的 APK 解开看钩子，有一半挂在 Android 17 上已经不存在的成员上：

| 上游钩的成员 | Android 17 `services.jar` |
|---|---|
| `com.android.server.wm.WmScreenshotController` | 不存在 |
| `mSecureContentPolicy` | 不存在 |
| `mCaptureSecureLayers` | 不存在 |
| `notAllowCaptureDisplay` | 不存在 |
| `canBeScreenshotTarget` | 不存在 |
| `WindowState.isSecureLocked` | 存在 |
| `SurfaceControl$Transaction.setInitialSurfaceControlProperties` | 存在 |

所以本模块换了思路：**不去追 ColorOS 截图 App 的内部实现**，而是从源头让系统不再把窗口判定为 secure，
这样无论走哪条抓屏路径（系统截图、`screencap`、录屏、投屏）都自然放行。

---

## 原理

只注入 `system_server`（`packageName == "android"`）。三个钩子全部包在 `try/catch` 里，
任何一个失败只记日志、不影响其余，也绝不向系统进程抛异常：

| 钩子 | 作用 | Android 17 实测 |
|---|---|---|
| `com.android.server.wm.WindowState#isSecureLocked()` → `false` | 核心。系统不再认为该窗口是受保护内容 | `hooked=1` |
| `android.view.SurfaceControl$Transaction#setSecure(...)` → 末位 boolean 钳成 `false` | 兜底。写图层 secure 位时强制关闭 | `hooked=1` |
| `com.android.server.wm.WindowStateAnimator#setSecure(...)` → 同上 | 兼容旧路径 | `hooked=0`（17 已无此方法，可忽略） |

不改任何 App 的逻辑，不改系统设置项。

---

## ⚠️ 全局生效

**装上之后，所有 App 的 `FLAG_SECURE` 都会失效**，包括但不限于：银行/证券 App 的余额与交易页、
微信/支付宝的支付页、无痕浏览、私密聊天、Netflix / B 站漫画特典这类 DRM 内容。

这是这类模块的设计本意，但等于把手机的截图防护整体拆掉。介意的话：

- 不用时在 LSPosed 里关掉开关并重启；
- 或者按 `WindowState.mAttrs.packageName` 自己加白名单（见「二次开发」）。

请自行评估风险，不要用于侵犯他人隐私或规避付费内容保护。

---

## 安装

1. 安装 APK
2. LSPosed 管理器 → 模块 → 勾选 **SecureFree**
3. 作用域只勾 **系统**（System Framework），**不要**勾任何普通 App
4. 重启手机

重启后确认生效：

```bash
# 模块是否注入 system_server 并挂上钩子
adb shell su -c "grep -i securefree /data/adb/lspd/log/modules_*.log | tail -5"
# 期望看到：
# [SecureFree] attached to system_server, sdk=37
# [SecureFree] WindowState.isSecureLocked hooked=1
# [SecureFree] SurfaceControl$Transaction.setSecure hooked=1
# [SecureFree] init done

# 目标界面图层是否还有 Secure 标记
adb shell "dumpsys SurfaceFlinger | grep 'YourActivityName#'"
```

---

## 编译

不需要 Gradle / Android Studio，用本机 JDK + Android SDK 即可：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

流程就是：`javac(占位类) → javac(模块) → jar → d8 → aapt2 link → 注入 dex 与 assets/xposed_init → zipalign → apksigner`。
在 Linux / macOS 上把这 8 步手工执行一遍效果相同。

依赖：JDK 17、Android SDK build-tools（`aapt2` / `d8` / `zipalign` / `apksigner`）、platform `android.jar`。
脚本会依次尝试 `JAVA_HOME`、`ANDROID_HOME`、`ANDROID_SDK_ROOT` 及常见安装路径。

产物：`out/SecureFree-signed.apk`。首次运行会自动生成 `securefree.keystore`（口令 `securefree`），
**发布自己的构建前请换成你自己的密钥。**

`stubs/` 是 Xposed API 的编译占位类，**只参与编译、不会进 dex**——运行时由 LSPosed 框架提供真实实现。

---

## 二次开发：改成白名单

只想对自己指定的 App 放开，在 `WindowState` 那个钩子里读一下所属包名即可：

```java
protected void beforeHookedMethod(MethodHookParam param) {
    String pkg = null;
    try {
        Object attrs = XposedHelpers.getObjectField(param.thisObject, "mAttrs");
        pkg = (String) XposedHelpers.getObjectField(attrs, "packageName");
    } catch (Throwable ignored) { }
    if (pkg != null && ALLOWLIST.contains(pkg)) {
        param.setResult(Boolean.FALSE);
    }
}
```

注意：`Transaction#setSecure` 只能拿到 `SurfaceControl`、拿不到包名，白名单模式下需要把那个钩子去掉，
只留 `isSecureLocked` 生效，并重新验证目标界面图层是否已变非 secure。

---

## 已知限制

- 只处理"窗口 secure 标记"这一层。App 用 `MediaProjection` 自行拒绝、或内容走硬件 DRM 通道的情况无效。
- 已经存在且之后不再重绘的窗口，secure 位要等下一次 relayout 才刷新；表现为装完重启后需要重进一次目标页。
- 系统截图文件写入相册目录有几秒延迟，截图后立刻查看容易误判为"没保存"。
- 仅在 ColorOS 17 / OnePlus 12 实测。其他 OEM ROM 理论上同样有效（钩的是 AOSP 层的
  `WindowState` / `SurfaceControl`），但未验证。

## 踩坑记录（二次开发会用到）

1. `<meta-data android:name="xposedmodule">` 必须写在 `<application>` 里。放在 `<manifest>` 根节点下
   LSPosed 扫不到，配置库里连 `modules` 行都不会有。
2. `XC_LoadPackage` 位于 **`de.robv.android.xposed.callbacks`** 子包，不是根包。写错会得到
   `AbstractMethodError: abstract method handleLoadPackage(...) on receiver Class<...>`。
3. 判断"模块有没有被加载"不能看 `/proc/<pid>/maps`——已经在 `system_server` 里正常工作的模块，
   它的 APK 也可能不出现在 maps 里。要看 LSPosed 的 `modules_*.log`。

## License

MIT
