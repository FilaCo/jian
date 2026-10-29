// expect-error: defaultAction is only supported by @JianCallback
package fixture

import jian.*

@JianCommand[defaultAction: "default"]
func invalid(): Unit {}
