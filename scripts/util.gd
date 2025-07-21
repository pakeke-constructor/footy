

class_name Util



# ENet channels for packet types.
# We want to use different channels for unreliable, reliable, and unordered
# since we don't want blocking.
const RELIABLE = 0
const UNRELIABLE = 1
const UNRELIABLE_ORDERED = 2
# We cant use an enum, because we get error: `Argument X of annotation @rpc isn't a constant expression`)
# (We also cant put it in Autoload NetworkManager, since godot 




# Waits until a node is ready.
# NOTE: this will implicitly turn the function into a coroutine.
# useful to use in on-ready
static func await_ready(node: Node):
	if not node.is_node_ready():
		await node.ready



static func disable_physics_clientside(node: Node):
	if not node.multiplayer.is_server():
		node.set_collision_layer(0)
		node.set_collision_mask(0)


static func lerp_quarternion(a: Quaternion, b: Quaternion, t: float):
	return a.slerp(b, t)


static func debug(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null):
	var lis = [a,b,c,d]
	while not lis.is_empty() and lis.back() == null:
		lis.pop_back()

	var args := OS.get_cmdline_args()
	var prefix = ""
	if "--server" in args:
		prefix = "[SERVER] "
	elif "--client" in args:
		prefix = "(client) "

	print(prefix, " ".join(lis))
