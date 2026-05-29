extends RefCounted

static func all() -> Dictionary:
	var defs := {}
	_add(defs, _tile("T000", "空地", "空地", "普通", 0, "empty", ["empty"], false, false, "空地", "empty", [0.16, 0.17, 0.19, 1.0], [0.55, 0.58, 0.65, 1.0]))
	_add(defs, _tile("T001", "铜币", "硬币", "普通", 3, "获得3金币", ["coin"], true, false, "铜币", "coin", [0.83, 0.44, 0.19, 1.0], [1.0, 0.82, 0.22, 1.0]))
	_add(defs, _tile("T002", "银币", "硬币", "稀有", 5, "获得5金币", ["coin"], true, false, "银币", "coin", [0.67, 0.76, 0.84, 1.0], [0.95, 0.98, 1.0, 1.0]))
	_add(defs, _tile("T003", "存钱罐", "硬币", "稀有", 0, "每经过一次硬币块金币+1，踩中后获得储蓄并归0", ["coin", "counter"], true, false, "存钱罐", "piggy_bank", [0.96, 0.42, 0.54, 1.0], [1.0, 0.86, 0.20, 1.0], {"stored": 0}, {}, ["piggy_bank"]))
	_add(defs, _tile("T004", "金币", "硬币", "非凡", 8, "获得8金币", ["coin"], true, false, "金币", "coin", [1.0, 0.70, 0.13, 1.0], [1.0, 0.95, 0.45, 1.0]))
	_add(defs, _tile("T006", "铜矿", "矿山", "普通", 2, "踩中3次后变为铜山", ["mine"], true, false, "铜矿", "mine", [0.57, 0.36, 0.24, 1.0], [0.96, 0.52, 0.22, 1.0], {"hits_remaining": 3}, {"counterTarget": "T007"}, ["mine_transform"]))
	_add(defs, _tile("T007", "铜山", "矿山", "稀有", 5, "踩中5次后销毁", ["mine", "mountain"], false, false, "铜山", "mine", [0.64, 0.39, 0.24, 1.0], [1.0, 0.65, 0.26, 1.0], {"hits_remaining": 5}, {}, ["mine_destroy"]))
	_add(defs, _tile("T008", "金矿", "矿山", "稀有", 4, "踩中5次后变成金山", ["mine"], true, false, "金矿", "mine", [0.58, 0.47, 0.18, 1.0], [1.0, 0.88, 0.20, 1.0], {"hits_remaining": 5}, {"counterTarget": "T009"}, ["mine_transform"]))
	_add(defs, _tile("T009", "金山", "矿山", "稀有", 8, "踩中8次后销毁", ["mine", "mountain"], false, false, "金山", "mine", [0.84, 0.60, 0.12, 1.0], [1.0, 0.96, 0.38, 1.0], {"hits_remaining": 8}, {}, ["mine_destroy"]))
	_add(defs, _tile("T012", "赌场（奇数）", "赌场", "普通", 6, "判定骰一次，奇数踩中时金币+7，偶数+0", ["casino"], true, false, "赌场", "casino", [0.62, 0.18, 0.26, 1.0], [1.0, 0.86, 0.22, 1.0], {}, {"parity": "odd", "winCoin": 7}, ["casino_parity"], false))
	_add(defs, _tile("T013", "赌场（偶数）", "赌场", "普通", 6, "判定骰一次，偶数踩中时金币+7，奇数+0", ["casino"], true, false, "赌场", "casino", [0.20, 0.26, 0.64, 1.0], [1.0, 0.86, 0.22, 1.0], {}, {"parity": "even", "winCoin": 7}, ["casino_parity"], false))
	for suit in [
		["T014", "红桃", "heart", [0.95, 0.22, 0.32, 1.0]],
		["T015", "黑桃", "spade", [0.10, 0.11, 0.16, 1.0]],
		["T016", "方块", "diamond", [0.93, 0.16, 0.22, 1.0]],
		["T017", "梅花", "club", [0.10, 0.12, 0.15, 1.0]]
	]:
		_add(defs, _tile(suit[0], suit[1], "卡牌", "普通", 1, "若本轮踩中任意另一种花色地块，额外+3金币", ["card", "suit", suit[2]], true, false, suit[1], suit[2], suit[3], [1.0, 0.88, 0.28, 1.0], {}, {}, ["suit_bonus"]))
	_add(defs, _tile("T018", "小丑", "卡牌", "非凡", 3, "本轮所有花色地块收益x2", ["card", "joker"], true, false, "小丑", "joker", [0.60, 0.24, 0.86, 1.0], [1.0, 0.88, 0.22, 1.0], {}, {}, ["joker_buff"]))
	_add(defs, _tile("T019", "牌鲨", "卡牌", "传说", 5, "若本轮踩中3个花色或卡牌类地块，额外获得50金币", ["card"], true, false, "牌鲨", "card_shark", [0.13, 0.55, 0.74, 1.0], [1.0, 0.86, 0.22, 1.0], {}, {}, ["card_shark"]))
	_add(defs, _tile("T020", "墓地", "墓地", "普通", 5, "踩中时随机生成一个鬼魂地块", ["graveyard"], true, false, "墓地", "graveyard", [0.28, 0.30, 0.37, 1.0], [0.68, 0.92, 1.0, 1.0], {}, {}, ["graveyard_spawn"]))
	_add(defs, _tile("T021", "鬼魂", "墓地", "普通", -1, "踩中后被销毁", ["graveyard", "ghost"], false, true, "鬼魂", "ghost", [0.52, 0.74, 0.92, 1.0], [0.92, 1.0, 1.0, 1.0], {}, {}, ["destroy_self"]))
	_add(defs, _tile("T022", "殡仪馆", "墓地", "稀有", 3, "每销毁一个鬼魂地块，金币永久+1", ["graveyard", "building"], true, false, "殡仪馆", "graveyard", [0.35, 0.28, 0.42, 1.0], [0.86, 0.66, 1.0, 1.0], {}, {}, [], true, ["mortuary_after_destroy"]))
	_add(defs, _tile("T024", "棺材", "墓地", "稀有", 10, "踩中生成一个吸血鬼地块", ["graveyard", "coffin"], true, true, "棺材", "coffin", [0.34, 0.19, 0.14, 1.0], [1.0, 0.25, 0.35, 1.0], {}, {}, ["coffin_spawn"]))
	_add(defs, _tile("T025", "吸血鬼", "墓地", "稀有", -3, "每次经过时扣除3金币，踩中被销毁", ["graveyard", "vampire"], false, true, "吸血鬼", "vampire", [0.42, 0.05, 0.12, 1.0], [1.0, 0.24, 0.35, 1.0], {}, {}, ["destroy_self"]))
	_add(defs, _tile("T027", "吸血鬼大君", "墓地", "传说", 8, "每销毁一个吸血鬼，永久+5金币", ["graveyard", "vampire_lord"], true, false, "吸血鬼大君", "vampire", [0.28, 0.02, 0.08, 1.0], [1.0, 0.78, 0.18, 1.0], {}, {}, [], true, ["vampire_lord_after_destroy"]))
	_add(defs, _tile("T029", "推土机", "特殊", "非凡", 3, "踩中后该棋子获得一轮销毁buff", ["special", "machine"], true, false, "推土机", "bulldozer", [0.94, 0.58, 0.16, 1.0], [0.16, 0.16, 0.18, 1.0], {}, {}, ["bulldozer_buff"]))
	_add(defs, _tile("T030", "浇水桶", "植物", "稀有", 3, "踩中后该棋子获得一轮浇水buff", ["plant", "water"], true, false, "浇水桶", "water", [0.19, 0.55, 0.92, 1.0], [0.58, 0.96, 1.0, 1.0], {}, {}, ["watering_buff"]))
	_add(defs, _tile("T031", "苹果树苗", "植物", "普通", 3, "被浇水过的棋子踩中会永久变成苹果树", ["plant", "sapling"], true, false, "苹果树苗", "sapling", [0.32, 0.68, 0.28, 1.0], [1.0, 0.25, 0.34, 1.0], {}, {"waterTarget": "T034"}))
	_add(defs, _tile("T032", "桃子树苗", "植物", "普通", 3, "被浇水过的棋子踩中会永久变成桃子树", ["plant", "sapling"], true, false, "桃子树苗", "sapling", [0.36, 0.70, 0.30, 1.0], [1.0, 0.56, 0.42, 1.0], {}, {"waterTarget": "T035"}))
	_add(defs, _tile("T033", "橙子树苗", "植物", "稀有", 3, "被浇水过的棋子踩中会永久变成橙子树", ["plant", "sapling"], true, false, "橙子树苗", "sapling", [0.38, 0.72, 0.28, 1.0], [1.0, 0.64, 0.18, 1.0], {}, {"waterTarget": "T036"}))
	_add(defs, _tile("T034", "苹果树", "植物", "稀有", 7, "获得7金币，苹果计数+1", ["plant", "fruit", "apple"], false, false, "苹果树", "tree", [0.24, 0.62, 0.25, 1.0], [1.0, 0.25, 0.34, 1.0], {}, {"fruit": "apple"}, ["fruit_tree"]))
	_add(defs, _tile("T035", "桃子树", "植物", "稀有", 7, "获得7金币，桃子计数+1", ["plant", "fruit", "peach"], false, false, "桃子树", "tree", [0.25, 0.64, 0.27, 1.0], [1.0, 0.56, 0.42, 1.0], {}, {"fruit": "peach"}, ["fruit_tree"]))
	_add(defs, _tile("T036", "橙子树", "植物", "稀有", 7, "获得7金币，橙子计数+1", ["plant", "fruit", "orange"], false, false, "橙子树", "tree", [0.26, 0.66, 0.25, 1.0], [1.0, 0.64, 0.18, 1.0], {}, {"fruit": "orange"}, ["fruit_tree"]))
	_add(defs, _tile("T037", "果园", "植物", "非凡", 4, "踩中时清空水果计数，每个水果值5金币", ["plant", "orchard"], true, false, "果园", "orchard", [0.24, 0.58, 0.28, 1.0], [1.0, 0.77, 0.24, 1.0], {}, {}, ["orchard_cashout"]))
	_add(defs, _tile("T038", "果酱", "植物", "非凡", 3, "每清空一次水果，果酱价值永久+5", ["plant", "jam"], true, false, "果酱", "jam", [0.72, 0.16, 0.42, 1.0], [1.0, 0.70, 0.82, 1.0], {}, {}, [], true, ["jam_after_fruit_clear"]))
	return defs

static func _add(defs: Dictionary, definition: Dictionary) -> void:
	defs[definition["id"]] = definition

static func _tile(id: String, name: String, type: String, rarity: String, base_coin: int, description: String, tags: Array, selectable: bool, temporary: bool, display_name: String, icon_kind: String, color: Array, accent: Array, counters: Dictionary = {}, state: Dictionary = {}, custom_handlers: Array = [], auto_add_base_coin: bool = true, event_hooks: Array = []) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": type,
		"rarity": rarity,
		"baseCoin": base_coin,
		"description": description,
		"tags": tags,
		"selectable": selectable,
		"temporary": temporary,
		"tile_name": display_name,
		"tile_rare": rarity,
		"tile_describe": description,
		"icon_kind": icon_kind,
		"color": color,
		"accent": accent,
		"counters": counters,
		"state": state,
		"customHandlers": custom_handlers,
		"autoAddBaseCoin": auto_add_base_coin,
		"eventHooks": event_hooks
	}
