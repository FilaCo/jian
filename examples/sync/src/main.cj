package sync_example

import jian.*
import std.fs.Path

@JianCommand[help: "Preview a sync plan without changing files."]
func sync(
    paths!: Array<Path> = JianArgument(help: "Paths to sync"),
    jobs!: ?Int64 = JianOption(short: 'j', help: "Worker count"),
    exclude!: Array<String> = JianOption(short: 'x', help: "Excluded patterns", default: []),
    dryRun!: Bool = JianOption(short: 'n', help: "Mark as a dry run", default: false)
): Unit {
    println("jobs=${jobs ?? 1}, dry-run=${dryRun}")
    for (path in paths) { println("path=${path}") }
    for (pattern in exclude) { println("exclude=${pattern}") }
}

main(args: Array<String>): Int64 {
    JianApp<JianNoContext>(name: "demo").add(SyncCommand()).run(args)
}
