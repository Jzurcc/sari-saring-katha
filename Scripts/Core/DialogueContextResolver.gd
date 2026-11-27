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
const P1_WEB_RULES: Array[Dictionary] = [
	{
		"id": "p1_kap_saw_ana_refused",
		"char_id": "kuyakap",
		"flag": "ana_utang_refused_early",
		"line": "Ana's been pulling extra shifts down the road, nak. Rough stretch for her.",
	},
	{
		"id": "p1_ana_saw_kap_candy",
		"char_id": "manangana",
		"flag": "kap_sub_candy",
		"line": "Saw Kap unwrapping candy under the acacia. Your doing, anak?",
	},
	{
		"id": "p1_buboy_saw_kap_candy",
		"char_id": "buboy",
		"flag": "kap_sub_candy",
		"line": "Kuya! Manong Kap smells like candy instead of smoke now!",
	},
]

# P2 Voice-Differentiated Gameplay Memory Openers (char_id -> outcome -> line).
# Falls back to "_default" if a character doesn't have a custom voice line yet.
const P2_OUTCOME_LINES: Dictionary = {
	"price_walkout": {
		"kuyakap": "Uy, nak, checking the price tag first. Last visit nearly gave me a cough.",
		"manangana": "Before I pick anything, anak, did the prices cool down?",
		"buboy": "Kuya, please tell me it's cheaper now. Mama counted my coins.",
		"lolopilo": "Let's see if your numbers are friendlier now, apo.",
		"danilo": "Brave pricing last time, boss. Let's see how it looks now.",
		"brahim": "Let us hope the scales are gentler this visit.",
		"rosalyn": "I brought exact change this time. Just in case.",
		"tk": "Yo, tell me the VIP markup is over.",
		"rodel": "I expect fairer rates than last time.",
		"sarimanok": "Gold is abundant, yet I still dislike being overcharged.",
		"_default": "Checking the price first, last time was a bit steep.",
	},
	"out_of_stock": {
		"kuyakap": "Aba, shelves look fuller now, apo. Mario passed through?",
		"manangana": "Please tell me Mario dropped off stock, anak.",
		"buboy": "Meron na po ba? I ran all the way here!",
		"lolopilo": "Empty shelves last visit, apo. Let's try again.",
		"danilo": "Looks like you restocked, boss. Good timing.",
		"brahim": "Hopefully what I need has arrived.",
		"rosalyn": "You were out last time. Is it here now?",
		"tk": "Restock day? Tell me we're back in business.",
		"rodel": "I came back hoping your shelves are no longer bare.",
		"sarimanok": "A proper shop keeps its offerings ready. Let us see.",
		"_default": "Hoping you're stocked up now.",
	},
	"story_out_of_stock": {
		"kuyakap": "O, apo, walked back across the road. Meron na ba this time?",
		"manangana": "Anak, I came back, please tell me you have it now.",
		"buboy": "Kuya! Do you have it now? I waited!",
		"lolopilo": "Round two, apo. Don't send an old man away empty again.",
		"brahim": "I returned when the shelves looked fuller.",
		"rosalyn": "I came back... hoping you found one for me.",
		"tk": "Take two! Tell me you restocked what I needed.",
		"rodel": "I'm giving your counter a second chance.",
		"sarimanok": "I have returned. Surely you are prepared now.",
		"_default": "Back again, do you have what I needed last time?",
	},
	"partial_order": {
		"manangana": "Hoping you have the whole list this time, anak.",
		"kuyakap": "Only got half my run last pass, nak. Let's finish clean.",
		"buboy": "No missing snacks this time, ha Kuya?",
		"_default": "Hopefully you've got everything on my list now.",
	},
	"utang_refused": {
		"manangana": "Don't worry, anak. Cash in hand this time.",
		"kuyakap": "Brought my coin pouch this time, apo. No lista needed.",
		"danilo": "Relax, boss, checked my pockets before walking over.",
		"_default": "Brought cash this time, don't worry.",
	},
	"gouged_in_story": {
		"manangana": "My wallet still remembers that markup, anak.",
		"kuyakap": "Heh. Easy on the neighbor pricing this time, ha apo?",
		"lolopilo": "Your lola never gouged me like that, apo.",
		"_default": "Still remembering what you charged me last time.",
	},
	"minigame_won": {
		"lolopilo": "Still bragging about that sipa win, apo? Don't get cocky.",
		"brahim": "Your hand was steady on that last talisman. Good work.",
		"_default": "Not bad on that last round!",
	},
	"minigame_lost": {
		"lolopilo": "Heh, still sore from losing at sipa, apo?",
		"brahim": "A shaky brush still teaches the hand. We'll try again.",
		"_default": "Tough luck last time, you'll get it next round.",
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
			return "Everyone's a bit restless out on the road, let's make this quick."
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_QUIET_ECLIPSE):
			return "Awfully quiet on the radio right now. Gives me the chills."
	if is_instance_valid(StoreEventManager) and StoreEventManager.has_method("get_active_events"):
		var evs: Array = StoreEventManager.get_active_events()
		if not evs.is_empty() and randf() < 0.35:
			return "Papa Ulap wasn't kidding about the rush."
	return ""
