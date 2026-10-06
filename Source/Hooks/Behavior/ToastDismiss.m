// ToastDismiss.m
// Prevents toxic hooking of native toast layoutSubviews and dismissAnimated,
// which previously caused infinite layout recursion and 100% main thread freeze
// whenever Instagram showed an error or confirmation banner.

void THRegisterToastDismissHooks(void) {
    // Native toasts are left untouched to prevent layout loops and UI unresponsiveness.
}