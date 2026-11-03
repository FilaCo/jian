package invocation_output_example

import jian.*
import std.env.{getStdOut, getStdErr}
import std.io.ByteBuffer

let app = JianApp(name: "demo", help: "Capture all invocation output without a context.")

@JianCallback[app]
func configure(output!: JianOutput = JianCurrentOutput(), version!: Bool = false) {
    if (version) {
        output.stdout.write("demo 1.0\n".toArray())
        return JianCallbackResult.Exit(0)
    }
    output.stdout.write("callback\n".toArray())
    JianCallbackResult.Continue
}

@JianCommand[app, help: "Greet through the selected invocation streams."]
func greet(name: String, output!: JianOutput = JianCurrentOutput()) {
    output.stdout.write("Hello, ${name}!\n".toArray())
}

main(args: Array<String>): Int64 {
    // A caller can capture help, usage errors and handler output with one stream selection.
    let out = ByteBuffer()
    let err = ByteBuffer()
    let code = app.run(args, stdout: out, stderr: err)
    getStdOut().write(out.bytes())
    getStdErr().write(err.bytes())
    code
}
