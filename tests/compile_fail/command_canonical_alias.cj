// expect-error: duplicate CLI command name 'r'
package fixture
import jian.*
@JianCommand[name: "r", aliases: ["r"]]
func run(): Unit {}
