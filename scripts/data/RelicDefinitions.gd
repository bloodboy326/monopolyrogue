extends RefCounted

static func all() -> Dictionary:
	return {
		"Y001": {
			"id": "Y001",
			"name": "金闪闪",
			"rarity": "普通",
			"description": "所有硬币获得的金币+1，且非凡传说物品获得概率+10%",
			"tags": ["coin"],
			"hooks": ["beforeGainCoins"],
			"poolWeightBonus": {"非凡": 0.10, "传说": 0.10},
			"config": {"coinBonus": 1}
		},
		"Y002": {
			"id": "Y002",
			"name": "矿稿",
			"rarity": "普通",
			"description": "踩中矿山效率+1，矿山变化计数器额外-1",
			"tags": ["mine"],
			"hooks": ["beforeTileResolve"],
			"config": {"mineCounterBonus": -1}
		},
		"Y003": {
			"id": "Y003",
			"name": "开采手册",
			"rarity": "稀有",
			"description": "金山、铜山可开采次数+4，且收益+2",
			"tags": ["mine"],
			"hooks": ["onRelicAdded", "afterGenerateTile", "onTileTransform"],
			"config": {"targetTileIds": ["T007", "T009"], "counterBonus": 4, "baseCoinBonus": 2}
		},
		"Y004": {
			"id": "Y004",
			"name": "掘墓者",
			"rarity": "稀有",
			"description": "踩中墓地时会生成两个鬼魂",
			"tags": ["graveyard"],
			"hooks": ["afterTileResolve"],
			"config": {"spawnTileId": "T021", "count": 2}
		},
		"Y005": {
			"id": "Y005",
			"name": "大蒜",
			"rarity": "普通",
			"description": "吸血鬼扣除金币变为-2",
			"tags": ["graveyard", "vampire"],
			"hooks": ["beforeGainCoins"],
			"config": {"vampirePenalty": -2}
		},
		"Y006": {
			"id": "Y006",
			"name": "十字架",
			"rarity": "稀有",
			"description": "墓地系地块出现概率增加20%",
			"tags": ["graveyard"],
			"hooks": [],
			"poolWeightBonus": {"graveyard": 0.20},
			"config": {}
		}
	}
