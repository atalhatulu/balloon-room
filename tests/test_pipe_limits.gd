extends SceneTree
var failures := 0
func check(ok: bool, message: String):
 if not ok:
  failures += 1
  push_error(message)
func _init():
 if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
  quit(2)
  return
 run.call_deferred()
func run():
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 await process_frame
 paused = false
 main.is_loading_save = true
 main.set_process(false)
 var shop = main.shop_manager
 var limits = {"small_room": 2, "medium_room": 4, "hangar": 9}
 for id in limits:
  shop.current_room = id
  shop.upgrades.pipe_count.level = 8
  main.apply_room_layout(id)
  main.game_manager.recalculate_effective_stats()
  var limit: int = limits[id]
  check(shop.get_active_pipe_count() == limit, id + " effective limit")
  check(main.room_controller.active_vent_positions.size() == limit, id + " visible outlets")
  check(shop.upgrades.pipe_count.level == 8, "Legacy purchases preserved")
  var expected: float = shop.upgrades.vent_rate.rates[0] * limit * shop.rooms[id].flow_mult
  check(is_equal_approx(main.game_manager.balloons_per_second, expected), id + " bounded throughput")
  shop.upgrades.pipe_count.level = limit - 2
  shop.coins = 99999999
  check(shop.buy_upgrade("pipe_count", 99999999), id + " final allowed purchase")
  var before: int = shop.coins
  check(not shop.buy_upgrade("pipe_count", 99999999) and shop.coins == before, id + " rejects extra pipe without charge")
 print("PIPE LIMITS: 24 checks, ", failures, " failures")
 main.queue_free()
 await process_frame
 quit(1 if failures else 0)
