package sub_apps_example

import jian.*
import sub_apps_example.project.app as project

let app = JianApp(name: "demo", help: "A CLI with a nested app.")
    .add(project, name: "project")

@JianCallback[app: app]
func configure(verbose!: Bool = JianOption(short: 'v', help: "Verbose output", default: false)): Unit {
    if (verbose) { println("Verbose mode enabled") }
}

@JianCommand[app: project, help: "Show a deployment plan."]
func deploy(target: String): Unit {
    println("Deploy to ${target}")
}

main(args: Array<String>): Int64 { app.run(args) }
