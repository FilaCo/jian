package custom_type_example

import jian.*

enum Color <: JianArgValue<Color> {
    | Red | Blue

    public static func takesValue(): Bool { true }
    public static func metavar(): String { "COLOR" }
    public static func whenAbsent(): ?Color { None }

    public static func accept(_: ?Color, raw: ?String): Color {
        let text = raw ?? throw JianUsageException("missing color value")
        match (text) {
            case "red" => Red
            case "blue" => Blue
            case _ => throw JianInvalidValueException(text, "red or blue")
        }
    }
}

@JianCommand[help: "Choose a paint color."]
func paint(color!: Color = JianOption(short: 'c', help: "red or blue")): Unit {
    match (color) {
        case Red => println("Painting red")
        case Blue => println("Painting blue")
    }
}

main(args: Array<String>): Int64 {
    JianApp<Unit>(name: "demo").add(PaintCommand()).run(args)
}
