import ComposableArchitecture

extension SharedKey where Self == AppStorageKey<Bool>.Default {
    public static var hasDismissedWelcome: Self {
        Self[.appStorage("hasDismissedWelcome"), default: false]
    }
}
