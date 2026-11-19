extends SceneTree
# Снимки знаков босса на первой арене: по одному на каждый знак, с подсказкой у курсора.
#   xvfb-run godot --path . --resolution 1280x720 --rendering-driver opengl3 -s tests/shot_boss_signs.gd
# ONLY=sign_ogre_print — один знак.
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var only: String = OS.get_environment("ONLY")
	var arenas: Array[String] = ["gat", "reeds", "grove", "thicket", "camp", "sanctum", "ruins", "hollow", "windfall"]
	var k: int = 0
	for boss_id: String in run.BOSS_SIGNS:
		for sign: Array in run.BOSS_SIGNS[boss_id]:
			if only != "" and only != sign[0]: continue
			run.start_new_run(21)
			run.current = run.row_nodes(0)[0]
			run.pending_enemies = run._make_encounter(0, false)
			run.pending_arena = arenas[k % arenas.size()]
			k += 1
			change_scene_to_file(run.BATTLE_SCENE)
			while current_scene == null or not current_scene.has_method("_check_boss_sign"):
				await process_frame
			var b = current_scene
			b._boss_sign_hint = ""
			for i in 40: await process_frame
			while b._mode == 0: await process_frame
			if b.board.has_node("Decorations/BossSign"):
				b.board.get_node("Decorations/BossSign").free()
			var node: Node3D = (load("res://assets/models/%s.glb" % sign[0]) as PackedScene).instantiate()
			node.scale = Vector3(1.4, 1.4, 1.4)
			node.position = b.board.boss_sign_pos if b.board.boss_sign_pos != Vector3.INF else Vector3(-1.2, 0.0, b.board.height * b.board.ROW_STEP * 0.5)
			node.rotation.y = 0.6
			b.board.get_node("Decorations").add_child(node)
			var screen: Vector2 = b.camera.unproject_position(node.position + Vector3(0, 0.3, 0))
			b.hud.show_tip(sign[1], screen)
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/claude-0/shots/sign_%s.png" % sign[0])
			print("shot ", sign[0], " at ", screen)
	quit()
