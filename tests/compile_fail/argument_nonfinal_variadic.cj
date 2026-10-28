// expect-error: variadic Array argument must be the last positional argument
package fixture

import jian.*

@JianCommand
func example(files!: Array<String> = JianArgument(), destination!: String = JianArgument()) {}
