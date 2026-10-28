package context_example

import jian.*
import context_example.state.AppContext as Context
import context_example.services.Logger

@JianCallback
func configure(ctx!: Context = JianFromContext<Context>(), verbose!: Bool = false): Unit {
    ctx.logger.verbose = verbose
}

@JianCommand
func greet(name: String, logger!: Logger = JianFromContext<Context>()): Unit {
    logger.greet(name)
}

main(args: Array<String>): Int64 {
    let context = Context()
    JianApp<Context>(name: "demo")
        .callback(ConfigureCallback())
        .add(JianApp<Context>(name: "people").add(GreetCommand()))
        .run(args, context: context)
}
