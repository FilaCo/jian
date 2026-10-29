package sub_apps_example

import jian.*
import sub_apps_example.project.app as project
import sub_apps_example.project.deploy

let app = JianApp(name: "demo", help: "A CLI with a nested app.")
    .add(project, name: "project")
    .add(deploy)

@JianCallback[app]
func configure(verbose!: Bool = JianOption(short: 'v', help: "Verbose output", default: false)): JianCallbackResult {
    if (verbose) { println("Verbose mode enabled") }
    JianCallbackResult.Continue
}

main(args: Array<String>): Int64 { app.run(args) }
