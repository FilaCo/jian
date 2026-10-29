package callback_exit_example

import jian.*

let app = JianApp(name: "demo", help: "A CLI with an informational option and a subcommand.")

@JianCallback[app]
func configure(configSchema!: Bool = JianOption(help: "Print the configuration schema and exit.", default: false)) {
    if (configSchema) {
        println("{\"type\":\"object\"}")
        return JianCallbackResult.Exit(0)
    }
    JianCallbackResult.Continue
}

@JianCommand[app, help: "Fetch source files."]
func fetchSrc(): Unit {
    println("Fetching source files")
}

main(args: Array<String>): Int64 { app.run(args) }
