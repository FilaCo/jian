package greet_example

import jian.*

let app = JianApp(name: "demo", help: "A first jian CLI.")

@JianCommand[app: app, help: "Greet someone."]
func greet(
    name!: String = JianArgument(help: "Name to greet"),
    times!: Int64 = JianOption(short: 't', help: "Repetitions", default: 1),
    loud!: Bool = JianOption(short: 'l', help: "Use uppercase", default: false)
): Unit {
    let message = "Hello, ${name}!"
    for (_ in 0..times) {
        println(if (loud) { message.toAsciiUpper() } else { message })
    }
}

main(args: Array<String>): Int64 { app.run(args) }
