package de.robv.android.xposed;

/** 编译期占位：运行时由 LSPosed 框架提供真实实现，本类不会被打进 dex。 */
public final class XposedHelpers {

    private XposedHelpers() {
    }

    public static Class<?> findClass(String className, ClassLoader classLoader) {
        return null;
    }

    public static Object getObjectField(Object obj, String fieldName) {
        return null;
    }

    public static void setObjectField(Object obj, String fieldName, Object value) {
    }
}
