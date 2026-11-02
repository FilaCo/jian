package input_hooks_example

import jian.*
import std.fs.Path

func nonblankPath(raw: String): String {
    let text = raw.trimAscii()
    if (text.isEmpty()) { throw JianInputException("path must not be blank") }
    text
}

func validPort(port: Int64): Unit {
    if (port < 1 || port > 65535) { throw JianInputException("port must be between 1 and 65535") }
}

let app = JianApp(name: "demo")

@JianCommand[app, help: "Generate from a model, trimming surrounding ASCII whitespace."]
func generate(model!: Path = JianArgument(preprocess: nonblankPath),
    port!: Int64 = JianOption(default: 8080, validate: validPort),
    name!: String = JianOption(default: "MODEL", normalize: { value: String => value.toAsciiLower() })): Unit {
    println("${model}:${port}:${name}")
}

main(args: Array<String>): Int64 { app.run(args) }
