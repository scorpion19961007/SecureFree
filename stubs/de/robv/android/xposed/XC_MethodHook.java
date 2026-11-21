package de.robv.android.xposed;

import java.lang.reflect.Member;

/** 编译期占位：运行时由 LSPosed 框架提供真实实现，本类不会被打进 dex。 */
public abstract class XC_MethodHook {

    protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
    }

    protected void afterHookedMethod(MethodHookParam param) throws Throwable {
    }

    public static class Unhook {
    }

    public static final class MethodHookParam {
        public Object thisObject;
        public Object[] args;
        public Member method;

        public Object getResult() {
            return null;
        }

        public void setResult(Object result) {
        }

        public Throwable getThrowable() {
            return null;
        }

        public void setThrowable(Throwable throwable) {
        }

        public boolean hasThrowable() {
            return false;
        }
    }
}
