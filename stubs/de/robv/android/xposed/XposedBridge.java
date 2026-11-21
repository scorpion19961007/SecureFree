package de.robv.android.xposed;

import java.util.Set;

/** 编译期占位：运行时由 LSPosed 框架提供真实实现，本类不会被打进 dex。 */
public final class XposedBridge {

    private XposedBridge() {
    }

    public static void log(String text) {
    }

    public static void log(Throwable t) {
    }

    public static Set<XC_MethodHook.Unhook> hookAllMethods(
            Class<?> hookClass, String methodName, XC_MethodHook callback) {
        return null;
    }

    public static XC_MethodHook.Unhook hookAllConstructors(
            Class<?> hookClass, XC_MethodHook callback) {
        return null;
    }
}
