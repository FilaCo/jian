package sub_apps_example.project

import jian.*

@JianCommand[app, help: "Show a deployment plan."]
public func deploy(target: String): Unit {
    println("Deploy to ${target}")
}
