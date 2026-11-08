import Carbon

/// Carbon hot keys work without Accessibility or keyboard-monitoring permission.
final class EscapeHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onEscape: (() -> Void)?

    func register() throws {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            Unmanaged<EscapeHotKey>.fromOpaque(context).takeUnretainedValue().onEscape?()
            return noErr
        }
        let status = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &event,
                                         Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw FlipError.escapeUnavailable }
        let id = EventHotKeyID(signature: 0x464C5048, id: 1)
        guard RegisterEventHotKey(UInt32(kVK_Escape), 0, id, GetApplicationEventTarget(),
                                  0, &hotKey) == noErr else {
            unregister()
            throw FlipError.escapeUnavailable
        }
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }

    deinit { unregister() }
}
