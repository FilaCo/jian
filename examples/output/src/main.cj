package output_example

import jian.*
import std.io.ByteBuffer

@JianCallback
func configure(output!: JianOutput = JianCurrentOutput(), schema!: Bool = false) {
    if (schema) {
        output.stdout.write("{\"type\":\"object\"}\n".toArray())
        return JianCallbackResult.Exit(0)
    }
    output.stdout.write("Preparing command\n".toArray())
    JianCallbackResult.Continue
}

@JianCommand
func greet(name: String, output!: JianOutput = JianCurrentOutput()) {
    output.stdout.write("Hello, ${name}!\n".toArray())
    output.stderr.write("Greeting complete\n".toArray())
}

// The run boundary selects streams once for help, diagnostics and handler output.
func capture(app: JianApp): Int64 {
    let output = ByteBuffer()
    let errors = ByteBuffer()
    let help = app.run(["--help"], stdout: output, stderr: errors)
    let command = app.run(["greet", "Alice"], stdout: output, stderr: errors)
    let usage = app.run(["greet"], stdout: output, stderr: errors)
    let schema = app.run(["--schema"], stdout: output, stderr: errors)
    if (help != 0 || command != 0 || usage != 2 || schema != 0) { return 1 }
    println("Captured stdout:")
    print(String.fromUtf8(output.bytes()))
    println("Captured stderr:")
    print(String.fromUtf8(errors.bytes()))
    0
}

main(args: Array<String>): Int64 {
    let app = JianApp(name: "demo").callback(configure).add(greet)
    if (args.isEmpty()) { capture(app) } else { app.run(args) }
}
