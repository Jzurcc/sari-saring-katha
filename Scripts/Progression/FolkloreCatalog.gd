class_name FolkloreCatalog
extends RefCounted

## Educational Philippine Folklore Field Notes & Neighbor Dossiers for the Karimlan Archive.
## Each neighbor unlocks 6 progressive chapters across Reputation Ranks 1–6:
##   Rank 1: Regional Origin & First Sightings
##   Rank 2: Traditional Beliefs, Offerings & Taboos
##   Rank 3: Archival Depiction (Supports both Portrait & Landscape illustrations) + Field Study
##   Rank 4: Historical & Cultural Roots
##   Rank 5: Rare Folklore Trivia & Local Accounts
##   Rank 6: Confidant Epilogue & Personal Bond
##
## Note: Each rank entry includes extended placeholder field-note paragraphs to support
## long-form reading layout testing alongside core folklore notes.

const ENTRIES: Dictionary = {
	"kuyakap": {
		"creature": "Kapre",
		"region": "Luzon & Visayas Lowlands",
		"portrait": "res://Assets/characters/portraits/Kuya_Kap Face.png",
		"rank1_origin": "Across Tagalog, Visayan, and Bicolano lowlands, elders speak of tall, dark-skinned tree guardians dwelling high within ancient balete, acacia, and century-old mango trees. Unlike wandering night terrors, a kapre claims a single beloved tree as its lifelong perch, watching the barrio grow beneath its branches.\n\n[Field Note Placeholder — Extended Observation]: Neighbors along the southern corner of Karimlan often report the warm, sweet smell of hand-rolled native tobacco drifting down from the canopy long after midnight, even when not a single soul is walking the street below. Lola's margin notes mention that the streetlights near the old acacia flicker whenever Kuya Kap shifts his shoulders against the trunk.",
		"rank2_taboos": "Travelers passing beneath heavy boughs at dusk murmur 'Tabi-tabi po' out of quiet neighborly respect. If a playful kapre clouds your sense of direction and leaves you walking in circles along a familiar road, folk wisdom prescribes turning your shirt inside-out—the sheer absurdity makes the giant chuckle and lifts the enchantment.\n\n[Field Note Placeholder — Storefront Etiquette]: Never sweep fallen acacia leaves toward the base of a tree after sunset without excusing yourself first. Elders also advise leaving a small cup of black coffee or unlit tobacco leaf on flat boundary stones during humid nights when the cicadas suddenly fall silent.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "portrait",
		"rank3_depiction_title": "Vertical Plate: Tree-Dwelling Kapre of the Balete",
		"rank3_depiction_caption": "Traditionally rendered in tall vertical compositions to capture the sheer scale of a bearded giant resting among hanging aerial roots, his glowing cigar ember mistaken for a high firefly.",
		"rank3_depiction_source": "Maximo Ramos, 'Creatures of Philippine Lower Mythology' (1971) & Tagalog oral archives.",
		"rank3_body": "Traditional woodcuts emphasize height over ferocity: broad shoulders draped in woven bark or worn provincial cloth, eyes catching lantern light like warm brass, and legs long enough to reach from an upper bough nearly to the roadside ditch.\n\n[Field Note Placeholder — Archival Commentary]: Sketchbooks from nineteenth-century Laguna and Quezon consistently frame the kapre vertically alongside ancient fig trunks. Informants insisted the creature rarely descends unless its home tree is threatened by axes or careless fire.",
		"rank4_history": "Etymologists trace the word 'kapre' to the Arabic 'kaffir' filtered through centuries of Spanish galleon trade and colonial-era storytelling. Naturalists also point to giant golden-crowned flying foxes and nocturnal palm civets whose glowing eyes, rustling branches, and musky scent startled night travelers beneath old-growth canopy trees.\n\n[Field Note Placeholder — Historical Context]: During the nineteenth century, stories of towering tree spirits inadvertently served as early conservation taboos—protecting watershed balete and mango groves from clear-cutting because loggers refused to fell trees rumored to house a watchful giant.",
		"rank5_trivia": "Unlike predatory aswang, kapres are overwhelmingly solitary, sentimental, and territorial rather than cruel. Several Southern Luzon tales describe a kapre gifting a trusted mortal friend a smooth, faintly luminous white pebble—a 'mutya'—that brings quiet steadiness and protection from getting lost.\n\n[Field Note Placeholder — Local Anecdote]: Old-timers in Karimlan swear that during the great typhoon of '98, a massive fallen branch stopped inches short of Lola's tin awning, held back by deep handprints pressed into the wet bark.",
		"rank6_epilogue": "A towering guardian of Karimlan's shade—quietly watching over your shutters long after the last tricycle turns off its headlamp.\n\n[Confidant Placeholder — Final Reflection]: To everyone else, the rustle above the streetlamp is a reason to hurry home. From behind your counter, it is simply Kuya Kap making sure the neighborhood sleeps in peace before he heads back up into the leaves."
	},
	"manangana": {
		"creature": "Manananggal",
		"region": "Western Visayas (Capiz, Iloilo, Antique)",
		"portrait": "res://Assets/characters/portraits/ManangAna Face.png",
		"rank1_origin": "Rooted deeply in Western Visayan oral lore, the manananggal is a nocturnal figure said to part from its lower torso at the waist, unfurling wide leathery wings beneath the moon before returning home ahead of daybreak.\n\n[Field Note Placeholder — Extended Observation]: Rumors travel fast in small towns whenever someone works graveyard shifts and keeps their curtains drawn until noon. Lola wrote in her ledger margins to judge neighbors by how kindly they treat their children and pay their tab, never by whispered kitchen gossip.",
		"rank2_taboos": "Rural households traditionally line window sills with coarse sea salt, crushed native garlic, pungent cane vinegar, and an inverted walis tingting (coconut-midrib broom) to ward off nocturnal visitors.\n\n[Field Note Placeholder — Household Customs]: Expectant mothers in Panay and Negros still burn dried pomelo peel and calamansi leaves at twilight, while keeping a small night-lamp burning beside woven bamboo slats until the first rooster crows.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "landscape",
		"rank3_depiction_title": "Panoramic Woodcut: Flight Over Nipa Rooftops",
		"rank3_depiction_caption": "Wide horizon illustrations contrast quiet moonlit bamboo groves and sleeping nipa huts against a winged silhouette banking across storm clouds.",
		"rank3_depiction_source": "Visayan Folkloric Accounts & Philippine Mythological Compendium.",
		"rank3_body": "Classic folkloric prints favor sweeping landscape compositions showing moonlit rice paddies, coconut silhouettes, and the distant call of the 'tiktik' bird—whose cry sounds loudest when the flyer is far away and faintest when she is directly overhead.\n\n[Field Note Placeholder — Archival Commentary]: Notice how older storytellers always emphasized the deception of sound over sight, teaching listeners to pay attention to quiet stillness rather than panic at loud noises in the dark.",
		"rank4_history": "Cultural historians connect Visayan manananggal and aswang narratives both to pre-modern explanations for sudden nocturnal illnesses and to colonial-era campaigns that demonized independent female healers (babaylan) who gathered medicinal night-blooming herbs after dark.\n\n[Field Note Placeholder — Historical Context]: Women who lived on the edges of towns, brewed herbal poultices, and refused colonial parish oversight were frequently cast as creatures of the night—turning revered community midwives into figures of fear over generations.",
		"rank5_trivia": "In nearly every regional variant, the manananggal's greatest vulnerability is daybreak itself: she must reunite before the first gold rays touch the horizon, making timekeeping between dusk and dawn a matter of survival.\n\n[Field Note Placeholder — Local Anecdote]: Manang Ana always checks the wall clock twice whenever she buys frozen tocino for her kids' breakfast—making sure morning meals are ready before she finally rests.",
		"rank6_epilogue": "Behind every fierce rumor in Karimlan is a tired mother working double shifts just to keep breakfast on her family's table.\n\n[Confidant Placeholder — Final Reflection]: Fear shrinks once somebody is met across an honest counter. Whatever wings or burdens Manang Ana carries after hours, your store remains the one place in town where nobody stares—and where her favorite frozen packs are always saved in the back."
	},
	"reynamayari": {
		"creature": "Mayari (Lunar Deity) & Biringan",
		"region": "Kapampangan / Tagalog Myth & Samar",
		"portrait": "res://Assets/characters/portraits/ReynaMayari Face.png",
		"rank1_origin": "Mayari is revered in Tagalog and Kapampangan cosmology as the one-eyed goddess of the moon, cool night air, and quiet dominion, intertwined here with legends of Biringan—Samar's unseen city of silver and gold.\n\n[Field Note Placeholder — Extended Observation]: Whenever Reyna Mayari steps up to the counter at closing time, the hum of the refrigerator seems to soften and coins ring with a clearer, heavier chime against the wood.",
		"rank2_taboos": "Samar folk wisdom warns travelers never to accept black heirloom rice or unpriced feasts from strangers in gleaming attire; partaking binds a mortal's debt to the hidden city beyond ordinary time.\n\n[Field Note Placeholder — Ledger Protocol]: Keep every peso counted cleanly before the evening bell. Honest, transparent tallies earn the moon's patience far better than flattery or excuses.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "portrait",
		"rank3_depiction_title": "Vertical Icon: Mayari, Sovereign of the Silver Moon",
		"rank3_depiction_caption": "Tall devotional-style portraiture depicting the lunar deity with one veiled eye and a halo of pale silver light, tempering the harsh heat of day.",
		"rank3_depiction_source": "F. Landa Jocano, 'Outline of Philippine Mythology' (1969) & Samar Biringan oral lore.",
		"rank3_body": "Unlike her fiery brother Apolaki, Mayari rules with cool poise rather than blinding glare. Artists portray her standing tall beneath crescent phases, holding scales or a silver ledger that weighs intention alongside tribute.\n\n[Field Note Placeholder — Archival Commentary]: Pre-colonial gold ornaments and lunar motifs found across Luzon and Visayas reflect a deep reverence for night cycles, tides, and agricultural planting calendars.",
		"rank4_history": "In classic Tagalog myth, Apolaki and Mayari clashed for sovereignty of the earth after Bathala's passing. When Apolaki struck one of Mayari's eyes in combat, remorse led them to divide time equally—bright sun by day, gentle silver light by night.\n\n[Field Note Placeholder — Historical Context]: Biringan stories emerged centuries later along Samar's misty rivers, describing phantom ocean liners and glowing avenues visible only to fishermen and late-night drivers.",
		"rank5_trivia": "To this day, couriers and wholesale drivers in Eastern Visayas trade stories of large paid deliveries addressed to 'Biringan'—arriving at dusk among grand gates, only to wake beside mist-covered ferns at dawn.\n\n[Field Note Placeholder — Local Anecdote]: Lola left a single pressed white sampaguita inside the back cover of her ledger, right beside the first entry bearing Mayari's silver mark.",
		"rank6_epilogue": "Even the Silver Ledger of Biringan yields to honest work, steady kindness, and a neighborhood tindahan kept with heart.\n\n[Confidant Placeholder — Final Reflection]: Debt began as a tether, yet night after night your small storefront proved that ordinary human warmth is worth more than all the illusory gold of an unseen city."
	},
	"rosalyn": {
		"creature": "White Lady (Multo / Aparisyon)",
		"region": "Quezon City (Balete Drive) & Nationwide",
		"portrait": "res://Assets/characters/portraits/Rosalyn Face.png",
		"rank1_origin": "Perhaps the most iconic figure of modern Philippine ghost lore, the White Lady appears along quiet tree-canopied avenues—most famously Quezon City's Balete Drive—draped in timeless white and lingering near streetlights.\n\n[Field Note Placeholder — Extended Observation]: Notice how Rosalyn never leaves wet footprints even on rainy evenings, yet lingers longest when warm OPM ballads play softly from the store radio.",
		"rank2_taboos": "Night drivers passing beneath overarching balete roots avoid honking in anger or staring into the rearview mirror, choosing instead to slow down respectfully and murmur a quiet greeting for souls still finding their way home.\n\n[Field Note Placeholder — Storefront Etiquette]: Never slam the counter window shut when a cool draft passes through; patience turns an eerie chill into a peaceful visit.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "portrait",
		"rank3_depiction_title": "Archival Portrait: The Apparition Under the Streetlamp",
		"rank3_depiction_caption": "Vertical monochrome study of a serene figure in white cotton standing beside rain-darkened asphalt and hanging roots.",
		"rank3_depiction_source": "Philippine Urban Legend Archives (1950s Metro Manila oral accounts).",
		"rank3_body": "Contrary to sensational horror films, the earliest mid-century accounts describe the apparition not as violent, but profoundly still—waiting beside road bends as though expecting a ride that never arrived.\n\n[Field Note Placeholder — Archival Commentary]: Vertical framing mirrors how headlights catch a standing silhouette between the pavement and overhanging branches.",
		"rank4_history": "Folklorists trace the Balete Drive phenomenon to post-World War II collective grief and a famous 1950s newspaper feature—transforming unmourned wartime tragedies into an enduring emblem of remembrance.\n\n[Field Note Placeholder — Historical Context]: As cities paved over old orchards and provincial trails, urban ghost lore preserved memory where plaques and monuments were missing.",
		"rank5_trivia": "In traditional Filipino belief, lingering spirits ('multo') rarely haunt out of malice; most remain tied to familiar daily routines—buying bread, listening to evening radio dramas, or waiting for someone to call them by name.\n\n[Field Note Placeholder — Local Anecdote]: Sometimes an extra coin appears neatly beside the candy jar after Rosalyn steps back into the evening mist.",
		"rank6_epilogue": "Sometimes all a drifting spirit needs is a warm light, a solid counter, and someone who remembers her name without flinching.\n\n[Confidant Placeholder — Final Reflection]: Karimlan is no longer a lonely crossroads for Rosalyn; your lit storefront has become a gentle harbor where memory feels welcome."
	},
	"tk": {
		"creature": "Tikbalang",
		"region": "Luzon Highlands & Bamboo Trails",
		"portrait": "res://Assets/characters/portraits/TK Face.png",
		"rank1_origin": "A lanky, fast-moving woodland trickster from Luzon lore, possessing a horse's head, hooves, and limbs so long that its knees rise higher than its crown whenever it squats on a roadside boulder.\n\n[Field Note Placeholder — Extended Observation]: TK taps his sneakers against the concrete at twice the speed of anyone else in town and somehow arrives from the far end of the barangay in thirty seconds flat.",
		"rank2_taboos": "Travelers who suddenly find themselves 'naligaw'—walking the exact same bend of bamboo trail three times in a row—must pause, turn their shirt inside-out, and ask permission calmly before continuing.\n\n[Field Note Placeholder — Trail Wisdom]: Getting angry only entertains a tikbalang; laughing along with the detour earns you a shortcut home.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "landscape",
		"rank3_depiction_title": "Panoramic Sketch: Sun-Shower Along the Mountain Pass",
		"rank3_depiction_caption": "Wide trail illustration showing sunbeams piercing afternoon rain clouds while a horse-headed silhouette vaults effortlessly across a mossy ravine.",
		"rank3_depiction_source": "Fray Juan de Plasencia (1589) & Tagalog Highland Folklore.",
		"rank3_body": "Landscape depictions highlight speed and terrain: mist-wrapped trails, swaying bamboo culms, and golden sun-showers where human footpaths twist unexpectedly into wild brush.\n\n[Field Note Placeholder — Archival Commentary]: Oral storytellers often pair the tikbalang with sudden shifts in mountain weather—bright sunshine colliding with warm tropical rain.",
		"rank4_history": "Centuries before Spanish galleons introduced horses to the archipelago, 1589 Tagalog chronicles already recorded the 'tigbalang' as a tall, shadowy forest phantom; equine features blended into the legend during the colonial era.\n\n[Field Note Placeholder — Historical Context]: Comparative mythologists also note parallels with South and Southeast Asian equine guardian motifs carried along maritime trade routes.",
		"rank5_trivia": "Whenever rain falls under bright sunshine, Filipino children still grin and say, 'May ikinakasal na tikbalang!'—a tikbalang wedding is underway!\n\n[Field Note Placeholder — Local Anecdote]: Whenever a sun-shower hits Karimlan, TK mysteriously buys two cold sodas instead of one.",
		"rank6_epilogue": "Once you learn to laugh at his detours, even the trickiest sprinter in Luzon becomes the fastest friend in your corner.\n\n[Confidant Placeholder — Final Reflection]: No path around Karimlan ever stays confusing for long when the local trickster himself considers your store his favorite pit stop."
	},
	"buboy": {
		"creature": "Tiyanak / Barangay Kid Lore",
		"region": "Tagalog & Visayan Countryside",
		"portrait": "res://Assets/characters/portraits/Buboy Face.png",
		"rank1_origin": "Draws gently from countryside tales of uncanny, fleet-footed children heard giggling near twilight groves, reimagined through the everyday energy of barangay street kids running afternoon errands.\n\n[Field Note Placeholder — Extended Observation]: Buboy's coins are always warm from being clutched tightly during a full-sprint race down the street so he won't forget what his mother told him to buy.",
		"rank2_taboos": "Provincial elders insist that every child playing teks or sipa outside must be called indoors before the six o'clock Angelus bell rings and shadows lengthen beneath the mango trees.\n\n[Field Note Placeholder — Neighborhood Rule]: Always count a kid's sukli (change) out loud so they make it home proud and unscolded.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "landscape",
		"rank3_depiction_title": "Street Vignette: Twilight Errands Before the Angelus",
		"rank3_depiction_caption": "Wide barangay scene of dusty slippers, scattered teks cards, and long golden-hour shadows stretching toward a lit sari-sari window.",
		"rank3_depiction_source": "Damiana Eugenio, 'Philippine Folk Literature Series' & Barangay Oral Culture.",
		"rank3_body": "Rather than grim cautionary woodcuts alone, modern folklorists recognize how countryside tales of wandering twilight children reinforced communal watchfulness—making every adult on the street responsible for getting neighborhood kids safely home.\n\n[Field Note Placeholder — Archival Commentary]: The sari-sari store sits at the center of Filipino childhood memory: the first place children practice counting coins, speaking politely, and being trusted with a household task.",
		"rank4_history": "Historically, stories of deceptive cries in unlit fields kept toddlers and older siblings from straying near deep irrigation canals, snake-hidden grass, and dark forest edges after sundown.\n\n[Field Note Placeholder — Historical Context]: Oral cautionary tales acted as a shared safety net across rural farming communities long before paved roads and streetlamps.",
		"rank5_trivia": "The classic Filipino 'utos'—repeating 'toyo, suka, bawang' ten times down the road only to blank out the instant you reach the store grill—is practically a national rite of passage.\n\n[Field Note Placeholder — Local Anecdote]: Buboy keeps a lucky rubber band around his wrist for sipa rematches right in front of your bench.",
		"rank6_epilogue": "Scuffed slippers, warm coins, and boundless laughter—the bright, noisy future of Karimlan.\n\n[Confidant Placeholder — Final Reflection]: Years from now, when Buboy is grown, this counter will still be the golden-hour memory he measures every other neighborhood against."
	},
	"sarimanok": {
		"creature": "Sarimanok",
		"region": "Mindanao (Maranao People, Lanao del Sur)",
		"portrait": "res://Assets/characters/portraits/Sarimanok Face.png",
		"rank1_origin": "The legendary multicolored bird of the Maranao people around Lake Lanao, celebrated across Mindanao as an enduring emblem of grace, artistry, and auspicious fortune.\n\n[Field Note Placeholder — Extended Observation]: Whenever vibrant feathers catch the afternoon sun outside your awning, half the street stops talking just to admire the colors.",
		"rank2_taboos": "Never treat the Sarimanok as an ordinary fowl; in Maranao tradition its form belongs to noble okir woodcarving, ceremonial flags, and spaces of hospitality and honor.\n\n[Field Note Placeholder — Cultural Respect]: Precision and generosity in presentation—clean shelves, bright signage, and respectful greetings—honor the spirit of abundance it represents.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "landscape",
		"rank3_depiction_title": "Okir Panel: The Plumage of Lake Lanao",
		"rank3_depiction_caption": "Horizontal carved-panel composition showcasing sweeping fern-like 'pako rabong' tail scrolls and a fish held in beak or talons as a sign of plenty.",
		"rank3_depiction_source": "Maranao Epic Tradition & National Commission for Culture and the Arts (NCCA).",
		"rank3_body": "Traditional Maranao carvings stretch horizontally across 'panolong' house-beams in flowing, rhythmic curves of vermilion, gold, emerald, and indigo—turning architecture itself into living storytelling.\n\n[Field Note Placeholder — Archival Commentary]: Every spiral and leaf motif in okir art follows centuries-old proportions passed from master carvers to apprentices.",
		"rank4_history": "Oral traditions link the bird to Raja Indarapatra and the moon-princess Sari, serving as a radiant messenger between the unseen sky-realms and human communities gathered around Lake Lanao.\n\n[Field Note Placeholder — Historical Context]: Throughout the twentieth century, the Sarimanok also became one of the most recognizable icons of indigenous southern Philippine artistry nationwide.",
		"rank5_trivia": "Authentic Sarimanok motifs almost always pair the bird with a fish—uniting sky and water in a single symbol of balanced prosperity.\n\n[Field Note Placeholder — Local Anecdote]: Days when the Sarimanok visits often coincide with lively foot traffic and unexpectedly generous tips.",
		"rank6_epilogue": "Where proud colors and generous hospitality meet, good fortune gladly makes its roost.\n\n[Confidant Placeholder — Final Reflection]: Your humble corner store has earned the rare honor of feeling festive even on an ordinary Tuesday afternoon."
	},
	"danilo": {
		"creature": "Barangay Watcher / Local Rumor-Keeper",
		"region": "Provincial Towns Across the Philippines",
		"portrait": "res://Assets/characters/portraits/Danilo Face.png",
		"rank1_origin": "Grounded in everyday barangay life rather than distant myth: the sharp-eyed regular who knows which delivery truck is running late, which storm cloud means business, and who needs a quiet helping hand.\n\n[Field Note Placeholder — Extended Observation]: Danilo leans against the warm edge of the wall with the unhurried calm of a man who has watched three decades of seasons pass down the same street.",
		"rank2_taboos": "Never brush off an old regular's casual heads-up; in a close-knit town, neighborhood intuition outruns official announcements by half a day.\n\n[Field Note Placeholder — Tambayan Wisdom]: Listening without gossiping is an art—keep confidences safe behind the counter and neighbors will trust you with the truth.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "landscape",
		"rank3_depiction_title": "Documentary Sketch: Dusk at the Corner Tindahan",
		"rank3_depiction_caption": "Wide street-level study of wooden benches, warm tungsten bulbs, and neighbors trading news as tricycles coast past at twilight.",
		"rank3_depiction_source": "Everyday Filipino Barangay Oral Tradition & Ethnographic Field Notes.",
		"rank3_body": "A sari-sari store is never merely retail space; sociologically, it is the living plaza of the street—part weather station, part message board, and part porch light for everyone walking home late.\n\n[Field Note Placeholder — Archival Commentary]: Sketchbooks of provincial towns invariably frame the store wide enough to include the bench outside, because the conversation on the bench is half the store's soul.",
		"rank4_history": "Long before mobile phones or barangay group chats, word of typhoons, fiestas, brownouts, and night-shift arrivals rippled reliably from tindahan to tindahan.\n\n[Field Note Placeholder — Historical Context]: Mutual aid ('bayanihan') thrives on proximity—simply noticing when an elderly neighbor hasn't picked up their morning coffee.",
		"rank5_trivia": "Sociologists studying Philippine neighborhoods note that micro-credit ('lista' or 'utang') works primarily through social trust cultivated face-to-face over years.\n\n[Field Note Placeholder — Local Anecdote]: Danilo can predict a sudden afternoon downpour ten minutes early just by the way ants march up the concrete post.",
		"rank6_epilogue": "Every town needs someone who pays attention—and someone behind the counter steady enough to care.\n\n[Confidant Placeholder — Final Reflection]: With Danilo's nod of approval, you aren't just running Lola's old shop anymore; you're truly part of Karimlan's backbone."
	},
	"brahim": {
		"creature": "Albularyo Apprentice / Anting-Anting Keeper",
		"region": "Karimlan, Mount Banahaw & Southern Luzon",
		"portrait": "res://Assets/characters/portraits/Brahim Face.png",
		"rank1_origin": "Draws from the living Filipino tradition of the 'albularyo'—herbalists and folk healers who pair medicinal plants like lagundi and sambong with quiet protective prayers and inscribed brass 'anting-anting' charms.\n\n[Field Note Placeholder — Extended Observation]: After walking away from corporate burnout in the city, Brahim returned home to Karimlan to apprentice under his father, trading spreadsheets for mortar-and-pestle remedies and steady brushwork.",
		"rank2_taboos": "In Southern Luzon lore, an anting-anting or protective ward holds its virtue only while its bearer remains humble and helpful; arrogance or selfish harm drains the brass cold.\n\n[Field Note Placeholder — Apprentice Notes]: Brahim's Tatay insists every prayer and line of ink be drawn without haste—if your breathing is ragged, set the brush down and brew ginger tea first.",
		"rank3_depiction_path": "res://Assets/ui/talisman.png",
		"rank3_depiction_orientation": "portrait",
		"rank3_depiction_title": "Archival Artifact: Weathered Brass Anting-Anting Plate",
		"rank3_depiction_caption": "Vertical cast-brass amulet suspended by a top ring, aged from warm bronze to ochre-gold and reserved for hand-inscribed sacred geometry.",
		"rank3_depiction_source": "Philippine Folk Amulet Collections & Southern Luzon Ethnographic Notes.",
		"rank3_body": "Authentic talisman plates are forged in vertical rectangular or triangular brass proportions with a sturdy suspension loop at the crown. Healers inscribe concentric rings, guiding stars, solar rays, and healing triads across the inner face.\n\n[Field Note Placeholder — Archival Commentary]: Notice the weathered brownish-gold patina of Brahim's practice talisman—warmed by decades of incense smoke in his father's workshop before being passed to his hands.",
		"rank4_history": "Philippine anting-anting traditions wove indigenous pre-colonial 'agimat' spirit-charms together with folk geometry and liturgical script during the eighteenth and nineteenth centuries, becoming cherished emblems of courage and protection.\n\n[Field Note Placeholder — Historical Context]: Alongside brass wards, rural albularyos preserved centuries of empirical botanical knowledge across barrios far from city hospitals.",
		"rank5_trivia": "Traditional keepers recharge or 'feed' their charms with quiet prayer on Fridays and during Holy Week, storing them wrapped in clean red or unbleached cotton cloth.\n\n[Field Note Placeholder — Local Anecdote]: Brahim swears your steady hand behind the counter helped him pass his father's toughest inspection without a single smudged line.",
		"rank6_epilogue": "True protection isn't cold metal—it's choosing a quieter, kinder life in service of the neighbors around you.\n\n[Confidant Placeholder — Final Reflection]: Watching Brahim settle into his father's footsteps feels a lot like tending your own store: proof that coming home can be the bravest chapter of all."
	},
	"rodel": {
		"creature": "Sireno / Siyokoy (Bantay-Tubig)",
		"region": "Visayan & Bikolano Coastal Waters",
		"portrait": "res://Assets/characters/portraits/Rodel Face.png",
		"rank1_origin": "Coastal Visayan and Bikolano traditions speak of the 'Bantay-Tubig'—merfolk, sireno, and scaled water stewards watching over estuaries, coral drop-offs, and tidal rivers.\n\n[Field Note Placeholder — Extended Observation]: Even during Karimlan's driest afternoons, Rodel carries the faint, clean scent of sea salt and rain-cooled river stone.",
		"rank2_taboos": "Small-boat fishermen ask permission before casting nets in unfamiliar coves and return juvenile catch to the water, honoring the unseen guardians of the tide.\n\n[Field Note Placeholder — Coastal Custom]: Never toss plastic or broken glass into a creek—what harms the upstream current eventually reaches the reef's keepers.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "portrait",
		"rank3_depiction_title": "Vertical Study: Guardian of the Deep Current",
		"rank3_depiction_caption": "Tall maritime illustration showing a gill-crested water guardian rising vertically through sun-pierced green water beneath a wooden outrigger.",
		"rank3_depiction_source": "Visayan Maritime Folklore & Maximo Ramos (1971).",
		"rank3_body": "Vertical compositions capture the depth of the water column—bright ripples and outrigger hulls at the surface giving way to calm, shadowy sanctuary below.\n\n[Field Note Placeholder — Archival Commentary]: Unlike European siren myths centered solely on shipwrecks, Philippine Bantay-Tubig accounts emphasize reciprocity: respect the water and the water sustains the village.",
		"rank4_history": "Anthropologists view Bantay-Tubig lore as indigenous marine stewardship encoded in narrative—preventing dynamite, poison, or reckless overharvesting in fragile spawning grounds.\n\n[Field Note Placeholder — Historical Context]: Riverine trade connected coastal Visayan communities with inland markets, carrying maritime stories deep into hillside towns.",
		"rank5_trivia": "Several island legends claim water-folk occasionally walk ashore during misty markets to trade smooth shells for sweet land fruits and cold bottled drinks, betrayed only by damp hems.\n\n[Field Note Placeholder — Local Anecdote]: Rodel always lingers happiest near the condensation mist of a freshly opened chiller door.",
		"rank6_epilogue": "No matter how far inland the road winds, gentle currents always find a welcoming shore.\n\n[Confidant Placeholder — Final Reflection]: Your store has become an oasis for Rodel—a cool, friendly harbor far from the noise of open water."
	},
	"lolopilo": {
		"creature": "Duwende (Nuno sa Punso)",
		"region": "Luzon & Visayas Earth Mounds",
		"portrait": "res://Assets/characters/portraits/LoloPilo Face.png",
		"rank1_origin": "Known affectionately and warily across the archipelago as the 'Nuno sa Punso'—ancient, diminutive elders of the earth who make their homes beneath hardened clay anthills, mossy stones, and old garden roots.\n\n[Field Note Placeholder — Extended Observation]: Lolo Pilo's eyes crinkle with the exact mischief of someone who has watched four generations of Karimlan kids lose their slippers in the tall grass.",
		"rank2_taboos": "Every Filipino child learns early to say 'Tabi-tabi po, makikiraan lang po' before stepping near an earthen mound or shadowy yard corner, lest careless disrespect invite sudden swelling or fever ('na-nuno').\n\n[Field Note Placeholder — Yard Custom]: Leaving a piece of sweet candy on a garden stone is the time-tested way to apologize for an accidental kick to a mound.",
		"rank3_depiction_path": "",
		"rank3_depiction_orientation": "landscape",
		"rank3_depiction_title": "Garden Plate: The Elder Beneath the Mango Roots",
		"rank3_depiction_caption": "Wide ground-level perspective peering beneath broad taro leaves at a bearded elder in a woven hat seated beside a weathered clay punso.",
		"rank3_depiction_source": "Tagalog & Visayan Oral Folklore & NCCA Cultural Heritage Archives.",
		"rank3_body": "Artists often drop the viewpoint right down to grass level in wide frames so fallen mangoes, sipa washers, and tangled roots tower like cathedral arches around the Nuno's quiet porch.\n\n[Field Note Placeholder — Archival Commentary]: Traditional tales distinguish between 'duwendeng puti' (playful, generous elders fond of honest households) and 'duwendeng itim' (irritable recluse spirits who dislike noise).",
		"rank4_history": "Practically, Nuno sa Punso taboos taught children humility toward nature while keeping bare feet away from mound-building termites, venomous ants, and cobras sheltering in dry earth cavities.\n\n[Field Note Placeholder — Historical Context]: Across Southeast Asia, earth-lord beliefs remind human settlers that land is shared with older, unseen inhabitants.",
		"rank5_trivia": "Hospitable families favored by a white duwende are said to enjoy steady customers, thriving backyard trees, and small lost trinkets mysteriously turning up swept neatly onto the doorstep.\n\n[Field Note Placeholder — Local Anecdote]: Nobody in Karimlan has ever beaten Lolo Pilo's all-time sipa count—though he insists his knees aren't what they were in 1890.",
		"rank6_epilogue": "As long as laughter, sipa kicks, and honest trade echo outside your window, Lolo Pilo's punso will always bless this ground.\n\n[Confidant Placeholder — Final Reflection]: Beneath the oldest roots in Karimlan sits a timeless friend who decided your little store was worth rooting for."
	}
}

static func get_entry(clean_id: String) -> Dictionary:
	return ENTRIES.get(clean_id.to_lower(), {})
