class_name DialogueContextResolver
extends RefCounted

## Hades / Valve Priority-Bucket Opener Resolver (P1 -> P2 -> P3).
## Resolves a single crisp, voice-true 1-line reactive opener for everyday visits
## (and Story White-Check retries) without combinatorial branching or scope creep.
##
## Priority hierarchy:
##   P1 — Delayed Consequence / Cross-Character Web Payoff (one-shot, gated by world_flags)
##   P2 — Recent Gameplay Memory (one-shot, consumed on use: price_walkout, out_of_stock,
##        story_out_of_stock, partial_order, utang_refused, minigame_won, minigame_lost, gouged_in_story)
##   P3 — Live World / Market Event / Mayari Omen Flavor (once per day/event)

# P1 Cross-Character & Delayed-Consequence Rules (populated as each character arc is authored).
# Each entry: { "id": String, "char_id": String, "flag": String, "line": String }
const P1_WEB_RULES: Array[Dictionary] = []

# P2 Voice-Differentiated Gameplay Memory Openers (char_id -> outcome -> line).
# Falls back to "_default" if a character doesn't have a custom voice line yet.
const P2_OUTCOME_LINES: Dictionary = {
	"price_walkout": {
		"kuyakap": "Checking the tag first today, apo. Last time stung.",
		"manangana": "Before I pick anything—did the prices cool down?",
		"buboy": "Kuya, please tell me it's cheaper today. Mama counted my coins.",
		"lolopilo": "Let's see if your numbers are friendlier today, apo.",
		"danilo": "Brave pricing yesterday, boss. Let's see how today goes.",
		"brahim": "Let us hope the scales are gentler today.",
		"rosalyn": "I brought exact change this time. Just in case.",
		"tk": "Yo, tell me the VIP markup is over today.",
		"rodel": "I expect fairer rates than last time.",
		"sarimanok": "Gold is abundant, yet I still dislike being overcharged.",
		"_default": "Checking the price first today—last time was too steep.",
	},
	"out_of_stock": {
		"kuyakap": "Shelf looks fuller today. Good.",
		"manangana": "Please tell me Mario dropped off stock today, anak.",
		"buboy": "Meron na po ba? I ran all the way here!",
		"lolopilo": "Empty shelves yesterday, apo. Let's try again.",
		"danilo": "Looks like you restocked, boss. Good timing.",
		"brahim": "Hopefully what I need has arrived today.",
		"rosalyn": "You were out last time. Is it here now?",
		"tk": "Restock day? Tell me we're back in business.",
		"rodel": "I came back hoping your shelves are no longer bare.",
		"sarimanok": "A proper shop keeps its offerings ready. Let us see.",
		"_default": "Hoping you're stocked up today.",
	},
	"story_out_of_stock": {
		"kuyakap": "Back again, apo. Got what I asked for this time?",
		"manangana": "Anak, I came back—please tell me you have it now.",
		"buboy": "Kuya! Do you have it now? I waited!",
		"lolopilo": "Round two, apo. Don't send an old man away empty again.",
		"brahim": "I returned when the shelves looked fuller.",
		"rosalyn": "I came back... hoping you found one for me.",
		"tk": "Take two! Tell me you restocked what I needed.",
		"rodel": "I'm giving your counter a second chance today.",
		"sarimanok": "I have returned. Surely you are prepared now.",
		"_default": "Back again—do you have what I needed last time?",
	},
	"partial_order": {
		"manangana": "Hoping you have the whole list today, anak.",
		"kuyakap": "Only got half my run last time. Let's finish clean today.",
		"buboy": "No missing snacks this time, ha Kuya?",
		"_default": "Hopefully you've got everything on my list today.",
	},
	"utang_refused": {
		"manangana": "Don't worry, anak. Cash in hand today.",
		"kuyakap": "Exact coins today. No favors needed.",
		"danilo": "Relax, boss—checked my pockets before walking over.",
		"_default": "Brought cash this time, don't worry.",
	},
	"gouged_in_story": {
		"manangana": "My wallet still remembers that markup, anak.",
		"kuyakap": "Heh. Still charging tourist rates to neighbors, apo?",
		"lolopilo": "Your lola never gouged me like that, apo.",
		"_default": "Still remembering what you charged me last time.",
	},
	"minigame_won": {
		"lolopilo": "Still bragging about that sipa win, apo? Don't get cocky.",
		"brahim": "Your hand was steady on that last talisman. Good work.",
		"_default": "Not bad on that last round!",
	},
	"minigame_lost": {
		"lolopilo": "Heh—still sore from losing at sipa, apo?",
		"brahim": "A shaky brush still teaches the hand. We'll try again.",
		"_default": "Tough luck last time—you'll get it next round.",
	},
}


## Resolves the highest-priority reactive opener for this customer right now.
## If consume == true, one-shot P1/P2 entries are marked consumed so they never repeat.
static func resolve_opener(
	customer_data: CustomerData,
	is_story_chapter: bool = false,
	consume: bool = true
) -> String:
	if customer_data == null or not is_instance_valid(CharacterProgressionManager):
		return ""
	var cid := customer_data.get_clean_id()
	if cid.is_empty():
		return ""

	# On Story Chapters, ONLY allow the White-Check retry callback ("story_out_of_stock")
	# so story openings stay razor-focused and never get derailed by random weather barks.
	if is_story_chapter:
		var last_out := CharacterProgressionManager.get_last_visit_outcome(cid)
		if last_out == "story_out_of_stock":
			if consume:
				CharacterProgressionManager.consume_last_visit_outcome(cid)
			return _lookup_p2_line(cid, "story_out_of_stock")
		return ""

	# --- P1: Delayed Consequence / Cross-Character Web Payoff ---
	for rule in P1_WEB_RULES:
		if str(rule.get("char_id", "")) != cid:
			continue
		var rule_id := str(rule.get("id", ""))
		if CharacterProgressionManager.is_reactive_line_consumed(rule_id):
			continue
		var flag_key := str(rule.get("flag", ""))
		if flag_key != "" and bool(CharacterProgressionManager.get_world_flag(flag_key, false)):
			if consume:
				CharacterProgressionManager.mark_reactive_line_consumed(rule_id)
			return str(rule.get("line", ""))

	# --- P2: Recent Gameplay Memory (last visit outcome) ---
	var outcome := CharacterProgressionManager.get_last_visit_outcome(cid)
	if outcome != "" and P2_OUTCOME_LINES.has(outcome):
		if consume:
			CharacterProgressionManager.consume_last_visit_outcome(cid)
		return _lookup_p2_line(cid, outcome)

	# --- P3: Active Mayari Omen / Market Event Flavor (lightweight, once per day per character) ---
	if is_instance_valid(StoryManager):
		var day_tag := "p3_d%d_%s" % [StoryManager.day, cid]
		if not CharacterProgressionManager.is_reactive_line_consumed(day_tag):
			var p3_line := _resolve_p3_world_line()
			if p3_line != "":
				if consume:
					CharacterProgressionManager.mark_reactive_line_consumed(day_tag)
				return p3_line

	return ""


static func _lookup_p2_line(cid: String, outcome: String) -> String:
	var table: Dictionary = P2_OUTCOME_LINES.get(outcome, {})
	if table.has(cid):
		return str(table[cid])
	return str(table.get("_default", ""))


static func _resolve_p3_world_line() -> String:
	if is_instance_valid(StoryManager):
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
			return "Everyone's on edge tonight—let's make this quick."
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_QUIET_ECLIPSE):
			return "Too quiet on the radio today. Gives me the chills."
	if is_instance_valid(StoreEventManager) and StoreEventManager.has_method("get_active_events"):
		var evs: Array = StoreEventManager.get_active_events()
		if not evs.is_empty() and randf() < 0.35:
			return "Papa Ulap wasn't kidding about the rush today."
	return ""
