extends SceneTree
var failures := 0
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)
func _init() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		quit(2)
		return
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.is_loading_save = true
	main.set_process(false)
	main.game_manager.is_game_started = false
	main.startup_modal.hide()
	main.player.set_ui_open(false)
	main.player.set_physics_process(false)
	var shop = main.shop_ui
	var rig = main.player.hands.tablet_rig
	var original_fov: float = main.player.camera.fov
	shop.toggle_shop_modal()
	check(main.player.is_ui_open and not shop.tablet_view.panel.visible, "Input locked and market hidden during retrieval")
	await create_timer(0.75).timeout
	check(rig.visible and shop.tablet_view.panel.visible, "Market appears after tablet reaches reading position")
	check(main.player.hands.left_hand.visible and not main.player.hands.right_hand.visible and main.player.hands.left_hand.global_position.distance_to(rig.global_position) < 0.9, "Left hand grips tablet and right hand stays hidden")
	check(main.player.camera.fov < original_fov, "Camera focuses on tablet")
	print("LAYOUT: ", root.size, " / ", shop.tablet_view.panel.size, " rect=", rig.screen_rect())
	check(shop.tablet_view.panel.size.x <= root.size.x and shop.tablet_view.panel.size.y <= root.size.y, "Market fits viewport")
	shop.set_category_filter("devices")
	var fan_card = shop.upgrades_container.get_node("CardFan")
	check(shop.btn_tab_devices.visible and fan_card.visible and fan_card.get_node("Margin/VBox/BtnBuy").disabled and fan_card.get_node("Margin/VBox/Status").text.contains("Oda 2'de açılır"), "Automation stays visible but locked until entering room two")
	main.shop_manager.coins = 10000
	main.game_manager.total_pops = 1000
	shop.update_all_shop_cards()
	shop.update_all_shop_cards()
	var button = shop.upgrades_container.get_node("CardVentRate/Margin/VBox/BtnBuy")
	var before: int = main.shop_manager.upgrades.vent_rate.level
	var coins_before: int = main.shop_manager.coins
	var cost: int = main.shop_manager.upgrades.vent_rate.costs[before]
	button.pressed.emit()
	check(main.shop_manager.upgrades.vent_rate.level == before + 1 and main.shop_manager.coins == coins_before - cost, "One press purchases exactly one upgrade")
	shop.set_category_filter("rooms")
	var filtering := true
	for card in shop.upgrades_container.get_children():
		if card.visible and not card.has_meta("room_id"):
			filtering = false
	check(filtering, "Category filtering works")
	main.game_manager.total_pops = 5000
	shop.update_all_shop_cards()
	check(shop.btn_tab_rooms.text.contains("YENİ") and shop.btn_tab_rooms.modulate == Color("efc379"), "Ready room milestone highlights the Rooms tab")
	main.shop_manager.current_room = "medium_room"
	main.game_manager.total_pops = 10000
	shop.set_category_filter("devices")
	var crusher_card = shop.upgrades_container.get_node("CardSpikeWall")
	check(not crusher_card.get_node("Margin/VBox/BtnBuy").disabled and fan_card.get_node("Margin/VBox/BtnBuy").disabled and fan_card.get_node("Margin/VBox/Status").text.contains("Önce"), "Crusher opens first and fan visibly waits for the previous automation tier")
	check(main.shop_manager.buy_device_unit("spike_wall", 10000), "Crusher can be purchased as the first automation tier")
	shop.update_all_shop_cards()
	check(not fan_card.get_node("Margin/VBox/BtnBuy").disabled, "Buying the crusher unlocks the fan in the market")
	await create_timer(0.8).timeout
	shop.toggle_shop_modal()
	await create_timer(0.8).timeout
	check(main.shop_manager.buy_upgrade("athlete_training", 10000) and main.shop_manager.buy_upgrade("auto_pop", 10000) and main.shop_manager.buy_upgrade("splash_pop", 10000), "Needle skill branch opens through its prior tiers")
	shop.update_all_shop_cards()
	shop.set_category_filter("weapons")
	var visible_weapon_ids: Array = []
	for card in shop.upgrades_container.get_children():
		if card.visible: visible_weapon_ids.append(str(card.get_meta("upgrade_id", "")))
	check(visible_weapon_ids == ["auto_pop", "splash_pop", "dart_gun"], "Weapons tab groups needle upgrades and a single dart card")
	var dart_box = shop.upgrades_container.get_node("CardDartGun/Margin/VBox")
	check(dart_box.get_node("BtnBuy").text == "Dart Sv.1'i al" and dart_box.get_node("Desc").text.contains("sekme") and dart_box.get_node("Desc").text.contains("Şarjör 10"), "Dart card previews ricochet, magazine and automatic reload")
	dart_box.get_node("BtnBuy").pressed.emit()
	shop.update_all_shop_cards()
	check(main.shop_manager.upgrades.dart_gun.level == 1 and dart_box.get_node("Title").text.contains("Sv.1 → Sv.2") and dart_box.get_node("Desc").text.contains("Delme: 2 → 3") and dart_box.get_node("Desc").text.contains("Şarjör: 10 → 12"), "Dart upgrades show the next magazine and reload")
	shop.set_category_filter("upgrades")
	var weapons_hidden := true
	for card in shop.upgrades_container.get_children():
		if card.visible and shop.is_weapon_card(card): weapons_hidden = false
	check(weapons_hidden, "General upgrades exclude weapon-specific cards")
	if "--capture" in OS.get_cmdline_user_args():
		shop.set_category_filter("all")
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-tablet.png")
	shop.toggle_shop_modal()
	await create_timer(0.8).timeout
	check(not main.player.hands.left_hand.visible and main.player.hands.right_hand.visible and not rig.visible and not main.shop_modal.visible and not main.player.is_ui_open, "Closing stows tablet and restores gameplay")
	check(is_equal_approx(main.player.camera.fov, original_fov), "Camera FOV restored")
	shop.toggle_shop_modal()
	await create_timer(0.08).timeout
	shop.toggle_shop_modal()
	await create_timer(0.05).timeout
	shop.toggle_shop_modal()
	await create_timer(0.75).timeout
	check(shop.shop_is_open and shop.tablet_view.panel.visible, "Rapid Tab reversal settles in correct state")
	shop.toggle_shop_modal()
	await create_timer(0.4).timeout
	print("TABLET SHOP: ", failures, " failures")
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
