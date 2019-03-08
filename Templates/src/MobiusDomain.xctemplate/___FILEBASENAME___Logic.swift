// ___FILEHEADER___

import MobiusCore

enum ___VARIABLE_productName___Logic {
    static func initiator(_ model: ___VARIABLE_productName___Model) -> First<___VARIABLE_productName___Model, ___VARIABLE_productName___Effect> {
        let model = ___VARIABLE_productName___Model()
        let effects = Set<___VARIABLE_productName___Effect>()
        return First(model: model, effects: effects)
    }

    static func update(model: ___VARIABLE_productName___Model, event: ___VARIABLE_productName___Event) -> Next<___VARIABLE_productName___Model, ___VARIABLE_productName___Effect> {

        // Switch should not have default in order to ensure all events are handled
        switch event {
        case .<#event#>:
            return on<#Event#>(model)
        }
    }

    static func on<#Event#>(_ model: ___VARIABLE_productName___Model) -> Next<___VARIABLE_productName___Model, ___VARIABLE_productName___Effect> {

    }
}
