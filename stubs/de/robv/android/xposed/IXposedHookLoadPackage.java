package de.robv.android.xposed;

import de.robv.android.xposed.callbacks.XC_LoadPackage;

/** 编译期占位：运行时由 LSPosed 框架提供真实实现，本类不会被打进 dex。 */
public interface IXposedHookLoadPackage {
    void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) throws Throwable;
}
