// expect-error: duplicate CLI input name '--sync-all'
package fixture

import jian.*

@JianCommand
func example(sync_all!: Bool, syncAll!: Bool): Unit {}
