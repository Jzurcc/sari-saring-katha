class_name EpilogueCatalog
extends RefCounted

## Data-driven New Vegas-style Epilogue Registry for Sari-Saring Katha.
## Reads every character's saved `outcome:<id>` enum from CharacterProgressionManager
## and builds a curated chronicle of Karimlan when the Silver Ledger seals.

const CAST_ORDER: Array[Dictionary] = [
	{"id": "kuyakap", "name": "Kuya Kap", "res": "res://Resources/customers/KuyaKap.tres", "cluster": "Triangle A · The Street"},
	{"id": "manangana", "name": "Manang Ana", "res": "res://Resources/customers/ManangAna.tres", "cluster": "Triangle A · The Street"},
	{"id": "buboy", "name": "Buboy", "res": "res://Resources/customers/Buboy.tres", "cluster": "Triangle A · The Street"},
	{"id": "lolopilo", "name": "Lolo Pilo", "res": "res://Resources/customers/LoloPilo.tres", "cluster": "Pair 1 · Old Tricks & New Trails"},
	{"id": "tk", "name": "T.K.", "res": "res://Resources/customers/TK.tres", "cluster": "Pair 1 · Old Tricks & New Trails"},
	{"id": "rodel", "name": "Rodel", "res": "res://Resources/customers/Rodel.tres", "cluster": "Pair 2 · Tide & Crown"},
	{"id": "sarimanok", "name": "Sarimanok", "res": "res://Resources/customers/Sarimanok.tres", "cluster": "Pair 2 · Tide & Crown"},
	{"id": "brahim", "name": "Brahim", "res": "res://Resources/customers/Brahim.tres", "cluster": "Triangle B · Sight & Healing"},
	{"id": "danilo", "name": "Danilo", "res": "res://Resources/customers/Danilo.tres", "cluster": "Triangle B · Sight & Healing"},
	{"id": "rosalyn", "name": "Rosalyn", "res": "res://Resources/customers/Rosalyn.tres", "cluster": "Triangle B · Sight & Healing"},
	{"id": "reynamayari", "name": "Reyna Mayari", "res": "res://Resources/customers/ReynaMayari.tres", "cluster": "Biringan · The Pale Moon"},
]

const BEST_OUTCOMES: Dictionary = {
	"kuyakap": "quit_smoking",
	"manangana": "flew_again",
	"buboy": "trusted_runner",
	"lolopilo": "grand_champion",
	"tk": "trail_warden",
	"rodel": "remembered_anito",
	"sarimanok": "living_emblem",
	"brahim": "true_albularyo",
	"danilo": "watchful_ally",
	"rosalyn": "peaceful_anchor",
	"reynamayari": "queen_at_the_counter",
}

const OUTCOME_ENTRIES: Dictionary = {
	"kuyakap": {
		"quit_smoking": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "The Acacia Holds",
			"body": "Kuya Kap never asked for his old lighter back. Neighbors passing the corner acacia now smell sharp menthol candy instead of tobacco smoke, and his deep laugh still anchors the whole street.",
		},
		"cutting_back": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Cooler Shade",
			"body": "Kuya Kap cut his old habit down to a rare stick and kept a pocket full of mints from your counter. His cough eased, and he never misses a chance to check if you have eaten.",
		},
		"kept_the_smoke": {
			"tier": "distant", "seal": "EXACT CHANGE", "title": "Behind the Haze",
			"body": "Kuya Kap kept his quiet distance beneath the acacia, counting exact coins for his usual pack and vanishing back into the smoke before the street grew crowded.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "Under the Acacia",
			"body": "Kuya Kap still leans against the corner tree across the road, watching over Karimlan with a quiet nod whenever your storefront bulb clicks on.",
		},
	},
	"manangana": {
		"flew_again": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "Open Sky Above the Roofs",
			"body": "Once a week, Manang Ana's teens kick her out of the karinderya kitchen so she can stretch her wings above the river breeze. She still slides warm adobo containers across your wood and reminds you to wash the lid.",
		},
		"steady_kitchen": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Balanced Lista",
			"body": "Manang Ana cleared her kitchen tab and finally caught her breath between shifts. Her four teens still raid the pots, though they carry the heavy grocery bags home for her now.",
		},
		"closed_ledger": {
			"tier": "distant", "seal": "CASH ONLY", "title": "Brisk Business",
			"body": "Manang Ana pays strictly in exact cash, nods politely across the counter, and hurries straight back to her stove before anyone can ask how she is holding up.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "Garlic Rice Down the Block",
			"body": "The warm scent of Manang Ana's karinderya still drifts up the road, and her wooden counter spot stays waiting whenever she needs quick kitchen staples.",
		},
	},
	"buboy": {
		"trusted_runner": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "Official Street Runner",
			"body": "Buboy proudly appointed himself Karimlan's fastest errand scout. He still forgets one item out of every four, yet no neighbor hesitates to trust him with a real mission anymore.",
		},
		"teks_buddy": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Teks Under the Awning",
			"body": "Buboy still sprints up with crumpled notes and wild snack riddles, always ready to challenge your reflexes to a quick round of Teks between deliveries.",
		},
		"still_goofing": {
			"tier": "distant", "seal": "PASSING BY", "title": "Coins in Fist",
			"body": "Buboy drops by for quick candies, laughs at his own jokes, and dashes back down the road before his mom can call him home.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "Crumpled Grocery Lists",
			"body": "Buboy's loud grin still echoes from the half-court, one forgotten errand away from sprinting straight back to your candy jars.",
		},
	},
	"lolopilo": {
		"grand_champion": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "1968 Lives Again",
			"body": "Lolo Pilo's shiny 1968 plaza coin still glints beside your register. Down at the basketball half-court, kids and spirits line up to watch the tiny champion coach a seven-foot rookie at Sipa.",
		},
		"happy_trickster": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Sweet Offerings",
			"body": "Lolo Pilo keeps his mango mound spotless and his pockets lined with candy wrappers from your shop, saving his shoelace tricks only for folks who forget Tabi-tabi po.",
		},
		"quiet_mound": {
			"tier": "distant", "seal": "QUIET MOUND", "title": "Old Games Put Away",
			"body": "Lolo Pilo buys his sweets quickly and slips back toward the half-court mango mound, keeping his lead Sipa washer tucked safely inside his vest.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "By the Half-Court",
			"body": "A familiar twinkle still lingers near the mango mound past the three-point line, waiting for the next passerby willing to play a two-minute game.",
		},
	},
	"tk": {
		"trail_warden": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "Base Camp Karimlan",
			"body": "Tiburcio Kalumpang hung his woven bandana by your counter and stopped staring at his Nokia arrow. He now guides lost delivery riders back to the main road by wind, moss, and Lolo Pilo's landmarks.",
		},
		"modern_strider": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Five Bars & Cold Bottles",
			"body": "T.K. calls out a booming Tabi-tabi po at every corner and keeps your refrigerator humming with daily cold-drink runs after his ridge cardio.",
		},
		"restless_wanderer": {
			"tier": "distant", "seal": "PASSING THROUGH", "title": "Eyes on the Map",
			"body": "T.K. grabs his trail supplies fast with eyes glued to his keypad screen, carrying two spare batteries just in case the Kalumpang ridge goes dark.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "Scenic Turns",
			"body": "T.K. still treats your storefront as Home Pin Number One, jogging up with a grin whenever he needs cold hydration after a detour.",
		},
	},
	"rodel": {
		"remembered_anito": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "The Tide Remembers",
			"body": "A sea-smoothed river stone rests behind your register. Down by the creekside bamboo clump, neighborhood kids call out Dayu-dayu, Litao, giving the forgotten northern anito his name back at last.",
		},
		"coastal_envoy": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Cool Creek Shade",
			"body": "Rodel settled comfortably beside Karimlan's bamboo bank, still politely fascinated by cold rain sealed inside plastic bottles and silver fish packed in neat tin drums.",
		},
		"drifting_tide": {
			"tier": "distant", "seal": "DRIFTING", "title": "Far From Shore",
			"body": "Rodel gathers his inland supplies with quiet courtesy before drifting back toward the creek, still wondering if anyone inland remembers the northern sea.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "Bamboo by the Creek",
			"body": "Rodel continues tending the cool bamboo grove at the edge of town, dropping by your awning with old-world coastal manners.",
		},
	},
	"sarimanok": {
		"living_emblem": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "The Crown's Word",
			"body": "A single golden okir feather gleams beside your register. Sarimanok still struts under your awning with dramatic squawks, resting peacefully in Rodel's bamboo shade with zero feathers plucked.",
		},
		"proud_patron": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Royal Inspection",
			"body": "Sarimanok inspects your canned-fish shelf with approving crest tilts, dropping shiny coins neatly on the wood and accepting zero requests for souvenir photos.",
		},
		"passing_spectacle": {
			"tier": "distant", "seal": "ALOOF", "title": "Painted Banner",
			"body": "Sarimanok swoops in only for brisk, haughty snack runs before gliding back above the painted welcome arch.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "Glittering Plumes",
			"body": "A flash of gold and crimson still passes over Karimlan's welcome arch, eyeing your shelves from above like a traveling royal critic.",
		},
	},
	"brahim": {
		"true_albularyo": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "Tatay's Brass Bell",
			"body": "Brahim rings Tatay's worn brass bell across Karimlan, pairing warm folk prayers with neat Baguio margin notes. The Grand Agimat you inscribed together still hums quietly behind your counter.",
		},
		"steady_apprentice": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Chalk and Herbs",
			"body": "Brahim learns at Tatay's unhurried pace by the creek bridge, trading boiled lagundi remedies for humble alay and stopping by your counter whenever his wrist needs a break.",
		},
		"textbook_herbalist": {
			"tier": "distant", "seal": "PRACTICAL", "title": "Neat Margin Notes",
			"body": "Brahim keeps Tatay's herbal recipes cataloged with academic precision, handling neighborhood aches cleanly while keeping the deeper spirit work at arm's length.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "Porch Past the Creek",
			"body": "The warm scent of boiled lagundi and kamangyan still drifts from Tatay's porch, where Brahim practices his brushwork between coffee breaks.",
		},
	},
	"danilo": {
		"watchful_ally": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "Eyes on Your Corner",
			"body": "Danilo finally slept five straight hours without a single glare migraine. He still claims the shady corner under your awning for snacks, quietly watching over every soul who walks down Karimlan's road.",
		},
		"bench_regular": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Front-Row Shade",
			"body": "Danilo keeps his favorite spot under your eaves, trading dry street observations for cold bottles and crunchy snacks while staying mostly off the clock.",
		},
		"distant_eyes": {
			"tier": "distant", "seal": "OFF THE CLOCK", "title": "Quiet Observer",
			"body": "Danilo pays exact coins, keeps his secrets to himself, and watches Karimlan's traffic from a safe, uninvolved distance.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "The Shady Corner",
			"body": "Danilo still lounges under your awning with a bag of snacks, spotting tiny details two blocks down the road before anyone else notices.",
		},
	},
	"rosalyn": {
		"peaceful_anchor": {
			"tier": "ally", "seal": "TRUE ALLY", "title": "Errand Finished",
			"body": "A bundle of dried sampaguita rests beside your register. Free from the highway's cold loop, Rosalyn holds real coins and menthol candy with steady hands whenever she visits your warm bulb.",
		},
		"lingering_guest": {
			"tier": "steady", "seal": "WARM REGULAR", "title": "Warm Under the Bulb",
			"body": "Rosalyn no longer fades at the guardrail. She steps into your light without apologizing, buying small sweets across Lola's wood in quiet peace.",
		},
		"faint_echo": {
			"tier": "distant", "seal": "QUIET ECHO", "title": "Soft Footsteps",
			"body": "Rosalyn took her single candy across the counter and drifted quietly back toward the misty bend, leaving the road gentler than before.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "STILL UNFOLDING", "title": "By the Waiting Shed",
			"body": "A shy pale figure still lingers near the edge of your warm storefront light, searching for the memory tied to Lola's wooden counter.",
		},
	},
	"reynamayari": {
		"queen_at_the_counter": {
			"tier": "ally", "seal": "PATRON OF THE MOON", "title": "Embassy of Karimlan",
			"body": "Reyna Mayari declared your sari-sari store an official Embassy of Karimlan, placing your street forever beyond the Silver Council's reach. She still sneaks in during daylight as Maria with real mortal pesos for candy.",
		},
		"honored_charter": {
			"tier": "steady", "seal": "CHARTER HONORED", "title": "Daylight Errands",
			"body": "With Lola's Silver Pact honored in full, Biringan's Council withdrew its audit. Mayari remains a dignified patron who still insists her daytime visits for sweets are strictly official.",
		},
		"clean_ledger": {
			"tier": "distant", "seal": "LEDGER SEALED", "title": "By the Letter",
			"body": "Every peso recorded cleanly and every seal closed on schedule. Reyna Mayari bowed once in formal respect and left Karimlan open under the letter of Lola's pact.",
		},
		"unfinished": {
			"tier": "unfolding", "seal": "PACT SEALED", "title": "Beneath the Silver Spires",
			"body": "The Silver Ledger rests sealed in Biringan, yet the Pale Queen still drops by your counter to deal lunar Favors and eye your stocked candy jars.",
		},
	},
}


## Builds the full ordered array of epilogue slides from live progression state.
static func build_chronicle_slides() -> Array[Dictionary]:
	var slides: Array[Dictionary] = []

	var ally_count: int = 0
	var finished_count: int = 0
	var outcomes_map: Dictionary = {}

	for entry in CAST_ORDER:
		var cid: String = str(entry["id"])
		var out_id: String = CharacterProgressionManager.get_character_outcome(cid) if is_instance_valid(CharacterProgressionManager) else ""
		outcomes_map[cid] = out_id
		if out_id != "":
			finished_count += 1
			if out_id == str(BEST_OUTCOMES.get(cid, "")):
				ally_count += 1
			else:
				var char_table: Dictionary = OUTCOME_ENTRIES.get(cid, {})
				var o_dict: Dictionary = char_table.get(out_id, {})
				if str(o_dict.get("tier", "")) == "steady":
					ally_count += 1

	var day_n: int = StoryManager.day if is_instance_valid(StoryManager) else 1
	var paid: float = StoryManager.tally_total_paid if is_instance_valid(StoryManager) else 2000.0
	var goal: float = StoryManager.TALLY_GOAL if is_instance_valid(StoryManager) else 2000.0

	# Slide 1: Macro Karimlan Ending
	var macro_title := "Clean Ledger, Empty Bench"
	var macro_seal := "TRANSACTIONAL SEAL"
	var macro_tier := "distant"
	var macro_body := "Every last peso of Lola's Silver Ledger was paid cleanly and on time. Biringan honored the letter of the pact and kept Karimlan's border open, though the wooden bench outside your counter stayed quiet."

	if ally_count >= 6:
		macro_title = "The Warm Crossroads"
		macro_seal = "BARANGAY CONVERGENCE"
		macro_tier = "ally"
		macro_body = "When the Silver Ledger closed, it was not coin alone that answered Biringan's Council. From the corner acacia to the creek bamboo and highway bend, Karimlan's neighbors stood beside Lola's wood and proved both worlds belong under one warm bulb."
	elif ally_count >= 2:
		macro_title = "A Steadfast Street"
		macro_seal = "PACT HONORED"
		macro_tier = "steady"
		macro_body = "Lola's Silver Pact sealed in full, backed by a loyal circle of neighbors who found warmth across your counter. Karimlan's border stays open, and the street outside your awning feels brighter with every shift."

	slides.append({
		"kind": "macro",
		"portrait_key": "reynamayari",
		"eyebrow": "KARIMLAN CHRONICLE  ·  SILVER PACT SEALED",
		"name": "Lola's Sari-Sari Store",
		"title": macro_title,
		"seal": macro_seal,
		"tier": macro_tier,
		"body": macro_body,
		"stats_line": "Day %d   ·   Silver Ledger ₱%.0f / ₱%.0f   ·   %d Neighbors Stood By You" % [day_n, paid, goal, ally_count],
	})

	# Slides 2..N: Cast Chronicle (skip unmet characters so players aren't spoiled!)
	for entry in CAST_ORDER:
		var cid: String = str(entry["id"])
		var res_path: String = str(entry["res"])
		var out_id: String = str(outcomes_map.get(cid, ""))
		var met: bool = (cid == "reynamayari") or (out_id != "") or (is_instance_valid(CharacterProgressionManager) and CharacterProgressionManager.has_encountered(res_path))
		if not met:
			continue

		var char_table: Dictionary = OUTCOME_ENTRIES.get(cid, {})
		var key: String = out_id if (out_id != "" and char_table.has(out_id)) else "unfinished"
		var data: Dictionary = char_table.get(key, {})
		if data.is_empty():
			continue

		slides.append({
			"kind": "character",
			"portrait_key": cid,
			"eyebrow": str(entry["cluster"]).to_upper(),
			"name": str(entry["name"]),
			"title": str(data.get("title", "")),
			"seal": str(data.get("seal", "")),
			"tier": str(data.get("tier", "unfolding")),
			"body": str(data.get("body", "")),
			"stats_line": "",
		})

	# Uncle Mario & Lola's Legacy slide
	slides.append({
		"kind": "closing",
		"portrait_key": "unclemario",
		"eyebrow": "LOLA'S LEGACY  ·  ENDLESS SHIFT",
		"name": "Uncle Mario & The Counter",
		"title": "Shutters Up, Coffee Warm",
		"seal": "THE COUNTER STANDS",
		"tier": "ally",
		"body": "Uncle Mario unloaded one more crate by the doorway, wiped his brow, and grinned that Lola's old counter never looked livelier. The Silver Ledger is sealed, yet Karimlan still needs cold bottles, warm chats, and a steady hand behind the wood.",
		"stats_line": "",
	})

	# Compute live story chapter progress across all 11 cast members
	var total_chapters: int = 0
	var done_chapters: int = 0
	for entry in CAST_ORDER:
		var res_path: String = str(entry["res"])
		total_chapters += 6
		if is_instance_valid(CharacterProgressionManager):
			done_chapters += clampi(CharacterProgressionManager.get_chapter(res_path), 0, 6)
	var remaining_chapters: int = maxi(0, total_chapters - done_chapters)

	var teaser := ""
	if remaining_chapters > 0:
		teaser = "There are still %d story chapters waiting across Karimlan. Keep playing in Endless Mode to finish them, or start a new Save Slot to see how different choices reshape the street and its endings." % remaining_chapters
	else:
		teaser = "Every chapter in this run has unfolded, yet different choices behind the counter lead down other paths. Open a new Save Slot anytime to discover alternate endings."

	# Dedicated Final "Thank You for Playing" End Screen
	slides.append({
		"kind": "thank_you",
		"eyebrow": "SARI-SARING KATHA  ·  SILVER LEDGER SEALED",
		"name": "Thank You for Playing!",
		"title": "Lola's tindahan is forever yours.",
		"body": "Thank you for spending your shifts behind the counter, listening to Karimlan's neighbors, and keeping the lights warm under the pale moon.",
		"teaser": teaser,
		"day_n": day_n,
		"done_chapters": done_chapters,
		"total_chapters": total_chapters,
		"remaining_chapters": remaining_chapters,
		"finished_arcs": finished_count,
		"total_cast": CAST_ORDER.size(),
	})

	return slides
