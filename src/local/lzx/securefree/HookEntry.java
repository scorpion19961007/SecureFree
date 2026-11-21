package local.lzx.securefree;

import java.util.Set;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * SecureFree —— Android 17 / ColorOS 17 上恢复截图能力的最小实现。
 *
 * 设计约束（都是踩过的坑）：
 * 1. 只挂在 system_server（packageName == "android"），不碰任何应用进程。
 * 2. 只用 Android 17 上仍然存在的成员，逐个 try/catch，任何一个失败都不影响其余，
 *    更不会把异常抛回 system_server（避免开机循环）。
 * 3. 不去 hook 上游 v5.0.1 依赖、但在 Android 17 已被移除的成员：
 *    WmScreenshotController / mSecureContentPolicy / mCaptureSecureLayers /
 *    notAllowCaptureDisplay / canBeScreenshotTarget。
 */
public final class HookEntry implements IXposedHookLoadPackage {

    private static final String TAG = "[SecureFree] ";

    /** 兜底开关：顺带钳住 SurfaceControl.Transaction.setSecure 的入参。 */
    private static final boolean HOOK_SURFACE_TRANSACTION = true;

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) {
        try {
            if (lpparam == null || !"android".equals(lpparam.packageName)) {
                return;
            }
            log("attached to system_server, sdk=" + android.os.Build.VERSION.SDK_INT);
            hookWindowState(lpparam.classLoader);
            hookWindowStateAnimator(lpparam.classLoader);
            if (HOOK_SURFACE_TRANSACTION) {
                hookSurfaceTransaction(lpparam.classLoader);
            }
            log("init done");
        } catch (Throwable t) {
            log("init aborted (ignored): " + t);
        }
    }

    /** 核心：让系统认为该窗口不是 secure，后续所有抓屏入口都会放行。 */
    private void hookWindowState(ClassLoader cl) {
        try {
            Class<?> cls = XposedHelpers.findClass("com.android.server.wm.WindowState", cl);
            Set<XC_MethodHook.Unhook> hooks =
                    XposedBridge.hookAllMethods(cls, "isSecureLocked", new XC_MethodHook() {
                        @Override
                        protected void beforeHookedMethod(MethodHookParam param) {
                            param.setResult(Boolean.FALSE);
                        }
                    });
            log("WindowState.isSecureLocked hooked=" + size(hooks));
        } catch (Throwable t) {
            log("WindowState.isSecureLocked FAILED: " + t);
        }
    }

    /** 次核心：surface 建立/刷新时写入的 secure 位，一并钳成 false。 */
    private void hookWindowStateAnimator(ClassLoader cl) {
        try {
            Class<?> cls = XposedHelpers.findClass("com.android.server.wm.WindowStateAnimator", cl);
            Set<XC_MethodHook.Unhook> hooks =
                    XposedBridge.hookAllMethods(cls, "setSecure", new XC_MethodHook() {
                        @Override
                        protected void beforeHookedMethod(MethodHookParam param) {
                            clampLastBoolean(param);
                        }
                    });
            log("WindowStateAnimator.setSecure hooked=" + size(hooks));
        } catch (Throwable t) {
            log("WindowStateAnimator.setSecure FAILED: " + t);
        }
    }

    /** 兜底：直接改 SurfaceControl.Transaction 的 secure 入参。 */
    private void hookSurfaceTransaction(ClassLoader cl) {
        try {
            Class<?> cls = XposedHelpers.findClass("android.view.SurfaceControl$Transaction", cl);
            Set<XC_MethodHook.Unhook> hooks =
                    XposedBridge.hookAllMethods(cls, "setSecure", new XC_MethodHook() {
                        @Override
                        protected void beforeHookedMethod(MethodHookParam param) {
                            clampLastBoolean(param);
                        }
                    });
            log("SurfaceControl$Transaction.setSecure hooked=" + size(hooks));
        } catch (Throwable t) {
            log("SurfaceControl$Transaction.setSecure FAILED: " + t);
        }
    }

    private static void clampLastBoolean(XC_MethodHook.MethodHookParam param) {
        Object[] args = param.args;
        if (args == null || args.length == 0) {
            return;
        }
        for (int i = args.length - 1; i >= 0; i--) {
            Object v = args[i];
            if (v instanceof Boolean) {
                if (Boolean.TRUE.equals(v)) {
                    args[i] = Boolean.FALSE;
                }
                return;
            }
        }
    }

    private static int size(Set<?> set) {
        return set == null ? 0 : set.size();
    }

    private static void log(String msg) {
        try {
            XposedBridge.log(TAG + msg);
        } catch (Throwable ignored) {
            // 日志失败绝不能影响系统进程
        }
    }
}
