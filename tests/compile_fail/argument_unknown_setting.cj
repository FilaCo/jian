// expect-error: unknown Argument setting 'other'
package fixture

import jian.*

@Command
func example(value!: String = Argument(other: true)) {}
