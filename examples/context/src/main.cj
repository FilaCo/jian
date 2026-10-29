package context_example

import jian.*
import context_example.state.*
import context_example.people.app as people

let app = JianContextApp<AppContext>(name: "demo")
    .add(people, name: "people")

@JianCallback[app]
func configure(ctx!: AppContext = JianFromContext<AppContext>(), verbose!: Bool = false): JianCallbackResult {
    ctx.people.logger.verbose = verbose
    JianCallbackResult.Continue
}

main(args: Array<String>): Int64 {
    app.run(args, context: AppContext())
}
