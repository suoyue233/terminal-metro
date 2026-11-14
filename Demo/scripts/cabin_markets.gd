extends RefCounted
## Quote entries contain the base price in kWh and the per-station daily limit.

const ESSENTIALS := {"aaa": [12.0, 5], "water": [6.0, 3], "ration": [8.0, 3]}
const CHARGERS := [
	"邮电新村", "四平路", "海伦路", "江浦路", "大连路", "上海火车站", "汉中路",
	"人民广场", "世纪大道", "西藏南路", "虹桥路", "龙阳路", "龙华中路", "宁国路",
]

const PROFILES := {
	"community": {
		"name": "社区供给站",
		"facility": "居民区 · 公共配给",
		"stock": {"book": [32.0, 3], "meds": [80.0, 2]},
		"demand": {"copper": [23.0, 4], "book": [24.0, 3]},
	},
	"workshop": {
		"name": "维修站",
		"facility": "维修间 · 设备修复",
		"stock": {"tools": [52.0, 3]},
		"demand": {
			"copper": [37.0, 4], "circuit": [119.0, 2], "powercore": [218.0, 1],
			"tire": [18.0, 3], "bolts": [8.0, 5], "steel_plate": [36.0, 3],
			"car_battery": [64.0, 2], "engine": [110.0, 1],
		},
	},
	"clinic": {
		"name": "医院物资窗口",
		"facility": "医院 · 医疗配给",
		"stock": {"meds": [118.0, 2]},
		"demand": {"meds": [108.0, 3], "powercore": [227.0, 1]},
	},
	"warehouse": {
		"name": "批发市场",
		"facility": "中转仓 · 批发补给",
		"stock": {"copper": [27.0, 4], "circuit": [82.0, 2], "powercore": [176.0, 1]},
		"demand": {"tools": [76.0, 3], "meds": [90.0, 2]},
	},
	"school": {
		"name": "学校物资站",
		"facility": "学校 · 教材与设备",
		"stock": {"tools": [56.0, 2], "circuit": [92.0, 1]},
		"demand": {"book": [44.0, 3], "relic": [122.0, 1]},
	},
	"central": {
		"name": "中心区商场",
		"facility": "商场 · 零售与寄售",
		"stock": {"book": [41.0, 2], "meds": [119.0, 2], "tools": [79.0, 2], "relic": [105.0, 1]},
		"demand": {"meds": [101.0, 3], "book": [34.0, 2], "circuit": [107.0, 2]},
	},
	"archive": {
		"name": "档案回收处",
		"facility": "图书馆 · 旧物登记",
		"stock": {"book": [37.0, 2]},
		"demand": {"book": [33.0, 2], "relic": [148.0, 2]},
	},
}

const STATION_GROUPS := {
	"workshop": ["四平路", "鲁班路", "宁国路", "杨树浦路", "平凉路", "丹阳路", "芳芯路", "北中路", "向城路"],
	"clinic": ["海伦路", "江浦公园", "蓝村路", "东安路", "杨高中路", "嘉善路", "南浦大桥", "延安西路"],
	"warehouse": ["江浦路", "大连路", "汉中路", "上海火车站", "国际客运中心", "宜山路", "龙阳路", "浦东大道", "西藏南路", "中潭路", "耀华路"],
	"school": ["同济大学", "交通大学", "国权路", "五角场", "抚顺路", "镇坪路"],
	"central": ["人民广场", "南京东路", "南京西路", "大世界", "世纪大道", "陕西南路", "一大会址·新天地", "中山公园", "虹桥路"],
	"archive": ["豫园", "上海图书馆", "中华艺术宫", "天潼路", "老西门", "龙华", "曲阜路"],
}

static func profile(station: String) -> Dictionary:
	for group in STATION_GROUPS:
		if station in STATION_GROUPS[group]:
			return PROFILES[group]
	return PROFILES.community
