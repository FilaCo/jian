package sub_apps_example

import jian.*

@JianCallback
func configure(verbose!: Bool = JianOption(short: 'v', help: "Verbose output", default: false)): Unit {
    if (verbose) { println("Verbose mode enabled") }
}

@JianCommand[help: "Show a deployment plan."]
func deploy(target: String): Unit {
    println("Deploy to ${target}")
}

main(args: Array<String>): Int64 {
    let project = JianApp(name: "project", help: "Project commands.")
        .add(DeployCommand())
    JianApp(name: "demo", help: "A CLI with a nested app.")
        .callback(ConfigureCallback())
        .add(project)
        .run(args)
}
