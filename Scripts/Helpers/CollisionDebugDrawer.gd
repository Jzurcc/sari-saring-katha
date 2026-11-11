class_name CollisionDebugDrawer
extends RefCounted

## Utility for recursively drawing 3D collision shapes using DebugDraw3D.

static func draw_all_collision_shapes(node: Node) -> void:
	if not is_instance_valid(node):
		return

	if node is CollisionShape3D:
		var cs: CollisionShape3D = node
		if cs.shape != null and cs.visible:
			var xform: Transform3D = cs.global_transform
			var color := Color(0.0, 1.0, 0.3, 0.8)
			if cs.get_parent() is CharacterBody3D:
				color = Color(0.2, 0.6, 1.0, 0.9)  # Blue for player
			elif cs.get_parent() is Area3D:
				color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow for areas/items

			if cs.shape is BoxShape3D:
				var box: BoxShape3D = cs.shape
				DebugDraw3D.draw_box(xform.origin, xform.basis.get_rotation_quaternion(), box.size, color)
			elif cs.shape is CapsuleShape3D:
				var cap: CapsuleShape3D = cs.shape
				DebugDraw3D.draw_capsule(xform.origin, xform.basis.get_rotation_quaternion(), cap.radius, cap.height, color)
			elif cs.shape is SphereShape3D:
				var sph: SphereShape3D = cs.shape
				DebugDraw3D.draw_sphere(xform.origin, sph.radius, color)
			elif cs.shape is ConcavePolygonShape3D:
				var faces: PackedVector3Array = cs.shape.get_faces()
				var lines := PackedVector3Array()
				for i in range(0, faces.size(), 3):
					var a: Vector3 = xform * faces[i]
					var b: Vector3 = xform * faces[i+1]
					var c: Vector3 = xform * faces[i+2]
					lines.append(a)
					lines.append(b)
					lines.append(b)
					lines.append(c)
					lines.append(c)
					lines.append(a)
				if lines.size() > 0:
					DebugDraw3D.draw_lines(lines, color)
			elif cs.shape is WorldBoundaryShape3D:
				DebugDraw3D.draw_position(xform, color)
			elif cs.shape is ConvexPolygonShape3D:
				DebugDraw3D.draw_position(xform, color)

	for child in node.get_children():
		draw_all_collision_shapes(child)
