package de.robv.android.xposed.callbacks;

/**
 * 编译期占位：运行时由 LSPosed 框架提供真实实现，本类不会被打进 dex。
 *
 * 注意包名：真实的 XC_LoadPackage 位于 de.robv.android.xposed.callbacks，
 * 不是 de.robv.android.xposed。放错包会导致 handleLoadPackage 无法覆盖接口方法，
 * 运行时抛 AbstractMethodError（已踩过一次）。
 *
 * 这里只声明实际用到的字段，避免占位类依赖 android.jar，保持编译步骤零外部依赖。
 */
public class XC_LoadPackage {

    public static class LoadPackageParam {
        public String packageName;
        public String processName;
        public ClassLoader classLoader;
        public boolean isFirstApplication;
    }
}
