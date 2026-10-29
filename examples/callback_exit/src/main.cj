package callback_exit_example

import jian.*

let app = JianApp(name: "demo", help: "A CLI with a default action, an informational option and a subcommand.")

@JianCallback[app, help: "Run the server over stdio when no command is requested."]
func configure(invocation!: JianInvocation = JianCurrentInvocation(),
    configSchema!: Bool = JianOption(help: "Print the configuration schema and exit.", default: false)) {
    if (configSchema) {
        println("{\"type\":\"object\"}")
        return JianCallbackResult.Exit(0)
    }
    if (invocation.requestedSubcommand.isNone()) {
        return JianCallbackResult.Exit(runServer())
    }
    JianCallbackResult.Continue
}

// This example only prints the selected action; an application would run its server here.
func runServer(): Int64 {
    println("Running server over stdio")
    0
}

@JianCommand[app, help: "Fetch source files."]
func fetchSrc(): Unit {
    println("Fetching source files")
}

main(args: Array<String>): Int64 { app.run(args) }
