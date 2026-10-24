/// The extension only shows the button; iOS runs the intent in the app, whose
/// TimerIntentHandler does the work.
enum TimerIntentHandler {
    static func toggle() async {}
}
