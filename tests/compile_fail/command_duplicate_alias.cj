// expect-error: duplicate CLI command name 'r'
package fixture
import jian.*
@JianCommand[aliases: ["r", "r"]]
func run(): Unit {}
