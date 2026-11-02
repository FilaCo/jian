package custom_type_example

import jian.*

@JianEnumArgValue
enum Color {
    | Red | Blue
}

let app = JianApp(name: "demo")

@JianCommand[app, help: "Choose a paint color."]
func paint(color!: Color = JianOption(short: 'c', help: "red or blue")): Unit {
    match (color) {
        case Red => println("Painting red")
        case Blue => println("Painting blue")
    }
}

main(args: Array<String>): Int64 { app.run(args) }
