// expect-error: duplicate JianOption setting 'help'
package fixture

import jian.*

@JianCommand
func example(value!: Bool = JianOption(help: "one", help: "two")) {}
