class_name FolkloreCatalog
extends RefCounted

## Educational Philippine Folklore Field Notes for Lola's Scrapbook Journal.
## Each neighbor has progressive unlocks across Reputation Ranks 1–6:
##   Rank 1: Regional Origin & Local Rumor
##   Rank 2: Traditional Beliefs & Taboos
##   Rank 3: Real-Life Creature Depiction / Illustration + Caption & Source
##   Rank 4: Historical & Real-World Origins
##   Rank 5: Rare Folklore Trivia
##   Rank 6: Master Seal & Epilogue Note

const ENTRIES: Dictionary = {
	"kuyakap": {
		"creature": "Kapre",
		"region": "Luzon & Visayas (Widespread)",
		"portrait": "res://Assets/characters/portraits/Kuya_Kap Face.png",
		"rank1_origin": "Tagalog, Visayan, and Bicolano lowlands — tall, dark-skinned tree giants dwelling in ancient balete, acacia, and mango trees.",
		"rank2_taboos": "Always say 'Tabi-tabi po' when passing giant trees at dusk. If a kapre plays a prank and makes you walk in circles, turn your shirt inside-out to break the spell.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Traditional Illustration: Tree-Dwelling Kapre",
		"rank3_depiction_caption": "Historically depicted as a towering bearded giant perched in the boughs of a balete tree, smoking a glowing hand-rolled cigar whose scent drifts down to passersby.",
		"rank3_depiction_source": "Source: Maximo Ramos, 'Creatures of Philippine Lower Mythology' (1971) & Tagalog oral archives.",
		"rank4_history": "The word 'kapre' derives from the Arabic 'kaffir' via Spanish colonial trade. Naturalists also link the myth to nocturnal palm civets and giant fruit bats whose glowing eyes and musky scent emerge from old-growth canopy trees at night.",
		"rank5_trivia": "Unlike predatory aswang, kapres are largely solitary and playful—some folk tales say a kapre who befriends a mortal will gift them a glowing white pebble (mutya) that grants hidden wishes.",
		"rank6_epilogue": "A towering guardian of Karimlan's shade—quietly watching over the street long after the streetlights flicker on."
	},
	"manangana": {
		"creature": "Manananggal",
		"region": "Western Visayas (Capiz, Iloilo, Antique)",
		"portrait": "res://Assets/characters/portraits/ManangAna Face.png",
		"rank1_origin": "Rooted in Visayan folklore—a nocturnal creature said to sever its upper torso at the waist and take flight on leathery bat wings.",
		"rank2_taboos": "Households traditionally keep coarse rock salt, crushed garlic, vinegar, and a walis tingting (coconut-twig broom) by windows and doors at night.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Traditional Depiction: The Winged Visayan Manananggal",
		"rank3_depiction_caption": "Folk art portrays a woman parting from her lower torso beneath a crescent moon, soaring over nipa roofs while the faint ticking of a tiktik echoes in the distance.",
		"rank3_depiction_source": "Source: Visayan Folkloric Accounts & Aswang Project Historical Compendium.",
		"rank4_history": "Historians connect aswang and manananggal legends to pre-modern efforts to explain sudden infant loss and rare hereditary conditions in Panay, as well as Spanish-era demonization of respected female babaylan healers.",
		"rank5_trivia": "In classic lore, the manananggal's greatest vulnerability is sunrise: if she cannot reunite with her lower torso before dawn, the morning light turns her to ash.",
		"rank6_epilogue": "Behind every fierce rumor in Karimlan is a mother working double shifts just to keep her family fed."
	},
	"reynamayari": {
		"creature": "Mayari (Lunar Deity) & Biringan",
		"region": "Kapampangan / Tagalog Mythology & Samar (Biringan)",
		"portrait": "res://Assets/characters/portraits/ReynaMayari Face.png",
		"rank1_origin": "Mayari is the one-eyed Tagalog and Kapampangan goddess of the moon, while Biringan is the legendary hidden golden city of Samar.",
		"rank2_taboos": "Never accept black rice or lavish unpriced gifts from strangers of Biringan—folk wisdom says once you eat their food, you cannot leave the hidden city.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Mythic Depiction: Mayari, Lady of the Silver Moon",
		"rank3_depiction_caption": "Depicted with a luminous silver aura and one veiled eye—yielding a gentler, cooler radiance than her brother Apolaki, the sun god.",
		"rank3_depiction_source": "Source: F. Landa Jocano, 'Outline of Philippine Mythology' (1969) & Samar Biringan oral lore.",
		"rank4_history": "In Tagalog creation myths, Apolaki and Mayari fought over dominion of the earth after Bathala's passing; after Apolaki accidentally blinded one of Mayari's eyes, they agreed to share rule—day for the sun, night for the moon.",
		"rank5_trivia": "Locals in Samar still tell stories of delivery trucks and couriers receiving real orders addressed to 'Biringan City'—only to find dense forest where a glittering metropolis stood at dusk.",
		"rank6_epilogue": "Even the Silver Ledger of Biringan yields to honest work, steady kindness, and a well-kept neighborhood tindahan."
	},
	"rosalyn": {
		"creature": "White Lady (Multo / Aparisyon)",
		"region": "Metro Manila (Balete Drive) & Nationwide",
		"portrait": "res://Assets/characters/portraits/Rosalyn Face.png",
		"rank1_origin": "Urban and provincial Philippine ghost lore—most famously associated with Balete Drive in Quezon City during the mid-20th century.",
		"rank2_taboos": "Drivers passing lonely tree-lined roads at midnight avoid glancing in the rearview mirror or honking disrespectfully, and whisper a quiet prayer for restless souls.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Folklore Depiction: The Apparition of Balete Drive",
		"rank3_depiction_caption": "Traditionally pictured as a pale, translucent figure in a flowing white dress standing calmly beneath overhanging balete roots in the mist.",
		"rank3_depiction_source": "Source: Philippine Urban Legend Archives (1950s Quezon City oral accounts).",
		"rank4_history": "Many historians trace the Balete Drive White Lady to post-WWII trauma and 1950s newspaper stories—a cultural way of mourning unnamed victims whose stories were never properly told.",
		"rank5_trivia": "In traditional Filipino belief, ghosts linger not out of malice, but because of unfinished everyday routines or a longing to be remembered kindly by the living.",
		"rank6_epilogue": "Sometimes all a drifting spirit needs is a warm cup, a solid counter, and someone who remembers their name."
	},
	"tk": {
		"creature": "Tikbalang",
		"region": "Luzon Mountains & Forest Trails",
		"portrait": "res://Assets/characters/portraits/TK Face.png",
		"rank1_origin": "A tall, lanky woodland trickster with the head and hooves of a horse and impossibly long limbs whose knees rise above its head when squatting.",
		"rank2_taboos": "If you feel mysteriously lost on a familiar path (naligaw), turn your shirt inside-out—the tikbalang laughs at the absurdity and breaks its illusion.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Traditional Depiction: The Woodland Tikbalang",
		"rank3_depiction_caption": "Illustrated as a towering horse-headed figure perched beside rain-slick mountain paths, often said to hold weddings whenever rain falls under bright sunshine.",
		"rank3_depiction_source": "Source: Juan de Plasencia (1589) & Tagalog Highland Folklore.",
		"rank4_history": "Before horses arrived via Spanish galleons, early Tagalog accounts described the 'tigbalang' as a tall, slender forest phantom; its horse-like imagery merged over centuries of colonial storytelling.",
		"rank5_trivia": "When it rains while the sun is shining, Filipinos still joke: 'May ikinakasal na tikbalang!' (A tikbalang is getting married!).",
		"rank6_epilogue": "Once you learn to laugh at his detours, even the trickiest horse-headed sprinter becomes a loyal friend."
	},
	"buboy": {
		"creature": "Tiyanak / Barangay Kid Lore",
		"region": "Tagalog & Visayan Countryside",
		"portrait": "res://Assets/characters/portraits/Buboy Face.png",
		"rank1_origin": "Inspired by classic countryside tales of mysterious wandering children who lead travelers off forest trails with playful giggles.",
		"rank2_taboos": "Elders advise keeping a watchful, gentle eye on stray little ones at twilight and making sure every child makes it safely home before the Angelus bells.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Folklore Depiction: The Mischievous Forest Child",
		"rank3_depiction_caption": "Old provincial woodcuts contrast an innocent-looking child by the roadside with the shadowy silhouettes of dense mango groves behind them.",
		"rank3_depiction_source": "Source: Philippine Folk Literature Series (Damiana Eugenio).",
		"rank4_history": "Stories of uncanny children served as cautionary reminders in rural barrios about the dangers of wandering alone into unlit fields after dusk.",
		"rank5_trivia": "In modern neighborhood retellings, the classic 'utos' errand—a kid sprinting to the sari-sari store and forgetting what Mama asked for—is a universal Filipino childhood rite of passage!",
		"rank6_epilogue": "Full of mud, energy, and borrowed coins—the heartbeat of Karimlan's next generation."
	},
	"sarimanok": {
		"creature": "Sarimanok",
		"region": "Mindanao (Maranao People, Lanao del Sur)",
		"portrait": "res://Assets/characters/portraits/Sarimanok Face.png",
		"rank1_origin": "The legendary multicolored rooster-bird of the Maranao people of Mindanao, revered as a timeless emblem of good fortune, art, and nobility.",
		"rank2_taboos": "The Sarimanok is never treated as a mere barnyard bird—its likeness is honored in okir woodcarving, royal banners, and festive Maranao ceremonies.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Cultural Depiction: The Maranao Sarimanok",
		"rank3_depiction_caption": "Traditionally carved in vibrant okir scrolls with swirling rainbow plumage, clutching a gleaming fish in its beak or talons as a sign of abundance.",
		"rank3_depiction_source": "Source: Maranao Oral Epic 'Darangen' & National Commission for Culture and the Arts (NCCA).",
		"rank4_history": "Linked to the Maranao legend of Sari and the rooster-spirit Raja Indarapatra, the Sarimanok bridges the mortal world and the sky-realm as a messenger of prosperity.",
		"rank5_trivia": "In Maranao art, the Sarimanok is almost never shown alone—its flowing tail feathers echo the sacred 'niaga' (serpent) and 'pako rabong' (growing fern) motifs.",
		"rank6_epilogue": "Where the Sarimanok struts with pride, color and good fortune follow close behind."
	},
	"danilo": {
		"creature": "Barangay Watcher / Local Rumor-Keeper",
		"region": "Provincial Towns Across the Philippines",
		"portrait": "res://Assets/characters/portraits/Danilo Face.png",
		"rank1_origin": "Rooted in the real-life heartbeat of every Filipino barangay—the watchful neighbor who knows every rumor, shortcut, and shifting wind in town.",
		"rank2_taboos": "Never dismiss a barangay elder's warning lightly; in small towns, word-of-mouth travels faster than any weather bulletin.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Barangay Sketch: The Corner Watchman",
		"rank3_depiction_caption": "A familiar silhouette leaning by the corner post at dusk, trading quiet updates with jeepney drivers, tanods, and sari-sari store owners.",
		"rank3_depiction_source": "Source: Everyday Filipino Barangay Oral Tradition.",
		"rank4_history": "Before smartphones, the neighborhood sari-sari store and its regular watchers functioned as the barangay's living bulletin board—connecting families, warnings, and mutual aid.",
		"rank5_trivia": "Tagalog 'bayanihan' begins with small neighborhood check-ins: noticing who hasn't opened their shutters yet and sharing word when a storm is rolling in.",
		"rank6_epilogue": "Every town needs someone who pays attention—and someone behind the counter who listens."
	},
	"brahim": {
		"creature": "Albularyo / Anting-Anting Keeper",
		"region": "Mount Banahaw, Siquijor & Southern Luzon",
		"portrait": "res://Assets/characters/portraits/Brahim Face.png",
		"rank1_origin": "Draws from the tradition of Filipino folk healers (albularyo) and keepers of sacred chalk wards, Latin-Tagalog orasyon, and brass anting-anting amulets.",
		"rank2_taboos": "An anting-anting or chalk ward only holds its strength if carried with humility; boasting of its power is said to crack its protection.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Archival Depiction: Traditional Anting-Anting Medallion",
		"rank3_depiction_caption": "Cast brass talismans inscribed with geometric stars, crescent seals, and protective folk phrases—worn for safe passage through unseen realms.",
		"rank3_depiction_source": "Source: Philippine Folk Amulet Collections & Mount Banahaw Ethnographic Notes.",
		"rank4_history": "Philippine anting-anting blended pre-colonial animist protective charms with folk-Latin prayers during the 18th–19th centuries, becoming symbols of resilience among travelers and revolutionaries alike.",
		"rank5_trivia": "Folk healers traditionally test wards during Holy Week or under a full moon, believing the quiet hours between dusk and midnight thin the veil between worlds.",
		"rank6_epilogue": "Protection isn't just chalk on wood—it's the steady hand of a neighbor who chooses to shield others."
	},
	"rodel": {
		"creature": "Sireno / Siyokoy (Water-Folk)",
		"region": "Visayan & Bikol Coastal Lore",
		"portrait": "res://Assets/characters/portraits/Rodel Face.png",
		"rank1_origin": "Coastal Philippine folklore tells of the Bantay Tubig—merfolk and scaled water spirits guarding rivers, reefs, and fishing coves.",
		"rank2_taboos": "Fishermen toss a small offering or whisper gratitude before casting nets into unfamiliar waters, respecting the unseen stewards beneath the tide.",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Coastal Depiction: The Siyokoy of the Deep",
		"rank3_depiction_caption": "Traditional illustrations depict web-fingered, gill-crested water guardians draped in sea-green scales, watching fishing boats from the mist.",
		"rank3_depiction_source": "Source: Visayan Maritime Folklore & Maximo Ramos (1971).",
		"rank4_history": "Like land spirits, Bantay Tubig myths taught coastal communities sustainable respect for rivers and reefs—discouraging overfishing or polluting sacred waterways.",
		"rank5_trivia": "In some Visayan tales, water-folk secretly trade pearls and dried fish at coastal markets in disguise, recognizable only by the faint scent of brine and damp hems.",
		"rank6_epilogue": "Even far from the shore, the tide always finds its way back to a welcoming doorstep."
	},
	"lolopilo": {
		"creature": "Duwende (Nuno sa Punso)",
		"region": "Luzon & Visayas (Nationwide Earth Spirits)",
		"portrait": "res://Assets/characters/portraits/LoloPilo Face.png",
		"rank1_origin": "Small, ancient earth elementals—'old men of the mound' (Nuno sa Punso)—living beneath anthills, mango roots, and quiet corners of old yards.",
		"rank2_taboos": "Always murmur 'Tabi-tabi po' when stepping near earthen mounds or dark garden corners. Respect a duwende and luck follows; mock their home and sudden fevers or rashes (na-nuno) strike!",
		"rank3_depiction_path": "",
		"rank3_depiction_title": "Folk Depiction: The Nuno sa Punso",
		"rank3_depiction_caption": "Classic illustrations portray a tiny, bearded elder in a wide pointed hat perched atop a termite mound, peering mischievously at passing children.",
		"rank3_depiction_source": "Source: Tagalog & Visayan Oral Folklore & NCCA Cultural Heritage Archives.",
		"rank4_history": "Ecologically, Nuno sa Punso beliefs protected children and farmers from disturbing termite mounds and stinging ant colonies, whose venomous bites caused mysterious fevers and swelling.",
		"rank5_trivia": "In Filipino lore, 'duwendeng puti' (white/good duwende) love playful games and often bless hospitable households with unexpected coins or good business!",
		"rank6_epilogue": "As long as someone still plays sipa and teks on the street, Lolo Pilo's punso will never go quiet."
	}
}

static func get_entry(clean_id: String) -> Dictionary:
	return ENTRIES.get(clean_id.to_lower(), {})
