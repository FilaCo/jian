// expect-error: unknown JianOption setting 'other'
package fixture

import jian.*

@JianCommand
func example(value!: Bool = JianOption(other: true)) {}
