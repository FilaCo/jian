// expect-error: unknown Param setting 'other'
package fixture

import jian.*

@Command
func example(@Param[other: true] value!: Bool) {}
