import MobiusCore
import MobiusExtras
#if !os(watchOS)
import MobiusNimble
import MobiusTest
import Nimble
#endif

typealias Model = String
typealias Event = Int
typealias Effect = UInt

public class MobiusSPMTest {
    public func verifyLinkage() {
        let update = Update<Model, Event, Effect> { _, _ in
            .noChange
        }
        let effectHandler = EffectRouter<Effect, Event>()
            .asConnectable

        let _ = Mobius.loop(update: update, effectHandler: effectHandler)
            .start(from: "")
    }
}
