package command_names_example

import jian.*

@JianCommand[name: "fmt", aliases: ["format"], help: "Format a path."]
func formatPaths(path: String, check!: Bool = false): Unit {
    println("${path}: check=${check}")
}

@JianCommand[help: "Call the implementation directly."]
func direct(): Unit { formatPaths("src", check: true) }

let app = JianApp(name: "demo").add(formatPaths).add(direct)
main(args: Array<String>): Int64 { app.run(args) }
