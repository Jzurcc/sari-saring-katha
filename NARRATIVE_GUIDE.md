# Sari-Saring Katha: Fixing the Customer Writing

A diagnosis of the current dialogue, what the best cozy games do differently, and a practical system for rewriting. Based on a read of `Lolo Pilo/Story.dtl`, `Kuyakap/Story.dtl`, `Rosalyn/Story.dtl`, `Generic/Purchase.dtl`, plus research on *Coffee Talk*, *Stardew Valley*, *Unpacking*, *Venba*, *Potion Permit*, and general game-writing craft.

---

## 1. What's wrong (specific to your files)

| # | Problem | Where you see it |
|---|---------|------------------|
| 1 | **Choices are fake.** Every option leads to the same result. Players figure this out in two visits, then stop reading. | Lolo Pilo: "Let's play!" / "Maybe next time" both end in `story_success`. Same skeleton in all 6 chapters. |
| 2 | **Characters state the theme instead of wanting something.** Lines read like fortune cookies. | "Laughter is better than gold." / "Routine is the only thing that keeps the clock from ticking too fast." / "Even the strongest tree eventually starts to lean." |
| 3 | **Every scene opens with a greeting + exposition dump.** The first 3 to 4 lines carry no tension. | Lolo ch.1 explains who he is, how old he is, and who your lola was before anything happens. |
| 4 | **Elders all sound the same.** Same warm, wise, aphoristic voice, same tics ("apo", "Hehe", "Ho-ho"). Swap the name tag and nothing changes. | Lolo Pilo and Kuya Kap are interchangeable. |
| 5 | **The player is an audience, not a participant.** Nobody asks you for anything difficult, and nothing you do costs you or them. | Almost all choices are "react nicely / react less nicely." |
| 6 | **Ellipses and pauses stand in for emotion.** When every line has `[pause=1.0]`, nothing is emphasized. | Rosalyn: the concept is strong (coins falling through her hands) but the delivery drowns in `[wave]` and `.[pause].[pause]`. |
| 7 | **Dialogue ignores your game's verbs.** Counter, change, utang, lista, stock, price, bench, tsismis. The story could happen in any café. | Only Kuya Kap's "anchor" (his usual item) uses the actual transaction. That is why he is your strongest character. |
| 8 | **Generic lines are name-switch tables with one beat each.** | `Generic/Purchase.dtl`: "High prices today, huh? Economy must be tough." |

**What already works (keep it):**
- **Kuya Kap**: the cigarettes as his "anchor," the clinic with the "careful face," and exact change down to the centavo. This is subtext done right: the *object* carries the feeling.
- **Rosalyn's premise**: the cold drink "gives my hands something to remember." Concrete, strange, sad.
- Real folklore underneath (`FolkloreCatalog.gd`) that most games never use.

---

## 2. What you're missing (the research, distilled)

### 2.1 Every scene needs a WANT, an OBSTACLE, and a TURN
Customers currently *visit*. They need to *want something from the player this visit.*
- **Want**: small and concrete ("exact change," "one more cigarette than I should," "don't tell Mama").
- **Obstacle**: the player, the price, the stock, the lista, pride.
- **Turn**: one line where the real subject surfaces.

If a scene has no want, cut it or make it a one-line bark.

### 2.2 Subtext beats statement ("show, don't tell")
Characters rarely say what they feel. They talk about the broken fence, the usual order, the weather.
- Bad: *"Maybe the anchors are getting heavy."*
- Good: *"Exact change. Down to the last centavo."* (He's counting what he can still afford. The player supplies the feeling.)

**Rule:** if a line could be a poster quote, it's wrong. Rewrite it as an action or an object.

### 2.3 Choices should change the *relationship*, not the plot
In cozy games choices are **tone and boundary**, not branching plot (*Coffee Talk*: serving what they ordered vs. what they needed).
Three postures cover most scenes:
1. **Tender** (comfort, ask, give)
2. **Light** (joke, deflect)
3. **Practical** (stay professional, hold the line)

Each must have a different **consequence** (see Section 4). Otherwise it's "three ways to say yes."

### 2.4 Trust is earned in tiers (Stardew's heart events)
Strangers don't confess. Gate vulnerability behind Rep rank (you already have 6 ranks, which is perfect):

| Rank | What they'll say |
|------|------------------|
| 1 to 2 | Habits, gossip, small talk. Guarded. |
| 3 to 4 | A real complaint, a memory, a slip. |
| 5 | The thing they're afraid of. |
| 6 | They do something *for* you unprompted. |

Open with a **stereotype** (Kap = gruff regular, Mayari = intimidating collector) and let later ranks crack it.

### 2.5 The player is a witness, not a fixer
The best moments (Shane's cliff scene) have the NPC make their own decision. The player's job is to *be there*. Don't let a single choice "cure" anyone.

### 2.6 Short beats, split by purpose
- **Barks** (Visit/Purchase/Smalltalk): 1 to 2 lines, high variety, strong voice.
- **Scenes** (Story): rare, earned, 6 to 12 lines, one decision.

Your Story files carry too many paragraphs that should be barks, and your barks carry flat generic lines that should have voice.

### 2.7 Specificity beats universality
"Cigarettes" is generic; "Champion Menthol, one stick short of the pack he finished Sunday" is a person. Same for place (the Angelus bell, the lista, the sukli) and for Filipino register. Tagalog/English mixing should differ *per character*, not be a decoration.

---

## 3. Make each voice distinct (voice sheet template)

Fill this out for every character before writing a line.

```
NAME:
WANT (this arc):                 e.g. "To not be a burden"
FEAR:                            e.g. "Being forgotten"
SECRET / LIE:                    e.g. "Says he's fine"
SENTENCE LENGTH:                 short / mid / rambling
REGISTER:                        Tagalog-heavy / Taglish / formal English / ...
TICS (max 1):                    e.g. ends sentences with "ha?"
NEVER SAYS:                      e.g. "I feel"
HOW THEY SHOW AFFECTION:         e.g. insults you, tips exact change
OBJECT THEY CARRY / BUY:         e.g. the same pack, same time
```

**Quick voice proposals from your existing cast:**
- **Kuya Kap**: short, understated, answers a question with an object. Never explains. (Already close.)
- **Lolo Pilo**: stop making him a gentle sage. He's a **competitive trickster** who cheats at sipa and is furious about being forgotten. Funny first, sad second.
- **Rosalyn**: fewer pauses, more *precise physical observations*. One `[wave]` at the end of a beat, not every line.
- **Manang Ana**: haggling is her love language. She argues price because she cares.
- **Buboy**: kids don't philosophize. He asks blunt questions and lies badly.

**The swap test:** replace the speaker's name with another character. If the line still works, rewrite it.

---

## 4. Tie choices to the game's own systems

You already have most of this infrastructure (`Transaction_Branch`, `world_flags` in `CharacterProgressionManager`, Rep ranks, Utang, favorites discovery, price tolerance). Use them so choices *cost or reward something real*.

| Choice type | Consequence you can already build | Why it's meaningful |
|---|---|---|
| **Give utang or refuse** | Utang balance + Rep + their future repay chance | Money vs. kindness is the sari-sari dilemma. |
| **Discount / keep price** | Short-term income vs. Rep and "favorite" discovery | Player-authored generosity. |
| **Hold their usual for them** | Stock cost now, bonus reaction next visit | Care shown through behavior. |
| **Keep or share tsismis** | Another character's mood, Rep with both | Information as currency (the bench is real). |
| **Ask vs. don't ask** | Unlocks a deeper beat *now* or *later*, never both | Respecting a boundary is a valid, rewarded choice. |
| **Say "tabi-tabi po"** or not | Folklore taboo respected, Rep, Rank 2 journal entry pays off | Uses your existing educational content. |
| **Minigame yes/no** | Both fine, but "no" should *change the scene*, not skip it | Never use this as the only choice in a scene. |

### Three rules for choices
1. **Every option must be a different person.** If two lines mean the same thing, delete one.
2. **Mark a flag when it matters.** `set world_flag "kap_asked_about_clinic" = true` and let a *later* scene reference it. Callbacks make players feel remembered.
3. **Allow the wrong answer.** A line that makes someone leave quietly is more memorable than a free +Rep.

### Idea: the Journal as a gameplay key
Your Folklore Journal's Rank 2 *Traditional Beliefs & Taboos* are perfect choice-gates. Reading them lets the player pick the line that shows respect (*"Tabi-tabi po"*, shirt inside-out, salt by the window). Players who skip the journal can still choose, but won't know the right move. This turns your journal from reading material into *knowledge you use*.

---

## 5. A writing process that fixes the bloat

1. **One-line beat first.** *"Lolo Pilo wants a rematch to avoid admitting he's lonely."* If you can't write it in a line, the scene isn't ready.
2. **Outline in three beats.** Want, Obstacle, Turn.
3. **Draft too long, then cut 40%.** Delete the greeting, the explanation, and anything that sounds like a lesson.
4. **Line budget:** average **6 to 10 words** per line; max **2 sentences**. One idea per line. A choice at least every 4 to 6 lines.
5. **Read it aloud** in the character's voice. If you wouldn't say it at a counter, cut it.
6. **The cut test:** remove each line. If the scene still works, it stays removed.
7. **Pause budget:** max one `[pause]` per beat, and only where a real person would stop.

---

## 6. Before / after

### Lolo Pilo, Chapter 1 (first meeting)

**Before:** 4 lines of self-introduction, flattery, then "Care for a quick round?" with two outcomes that end the same.

**After (want: a game; obstacle: pride and an unpaid grudge; turn: he admits it's about your lola):**

```
label Greeting
if {Transaction_Chapter} == 0.0:
	LoloPilo: You sweep the back step at night.
	LoloPilo: Dust goes straight into my roof.
	- Sorry. Tabi-tabi po.
		set {Transaction_Branch} = 0.0
		LoloPilo: Hm. [pause=0.4] Your lola said that too. Every night.
	- Your... roof?
		set {Transaction_Branch} = 1.0
		LoloPilo: The mound behind the shop, apo. [pause=0.4] Pilo. Ask anyone older than forty.
	LoloPilo: She owed me one game of sipa. 1968. I was winning.
	- Then let's finish it.
		[signal arg="minigame:sipa"]
		LoloPilo: You kick like her. [pause=0.5] Worse. But like her.
	- I'm working, Lolo.
		LoloPilo: She said that too. [pause=0.6] Then she let me win a game at closing.
	[signal arg="story_success"]
	[end_timeline]
```

What changed:
- **Cut ~70%** of the words, with no greeting.
- **Real folklore as the hook**: "tabi-tabi po" is the gate; the two openers show *two different players*.
- **Both choices have a reaction** that reveals Lola, so the second isn't "skip."
- **Callback ready**: `Transaction_Branch` lets chapter 3 say *"You said sorry the first night. Nobody says sorry to the mound anymore."* (or *"Still can't say tabi-tabi."*)

### Rosalyn, pacing fix

**Before:** every line wrapped in `[wave]` with 3 to 4 pauses.

**After:** the *content* does the slowness.

```
Rosalyn: Cold coffee. [pause=0.8] Please.
Rosalyn: I tried a warm cup last Tuesday. [pause=0.6] I felt the shape. Nothing else.
```

### Generic price complaint

**Before:** *"High prices today, huh? Economy must be tough."*

**After (barks, one per mood, no commentary):**
- Manang Ana: *"₱{price}? Tawad. ₱{price_minus_two}."*
- Buboy: *"Kuya, sobrang mahal. Sasabihin ko kay Mama."*
- Kuya Kap: *(counts coins slowly.)* *"Hm."*

---

## 7. Implementation checklist for your project

- [ ] Fill out the voice sheet for each of the 10 characters (Section 3).
- [ ] Rewrite **one** character end-to-end as a pilot (suggest Lolo Pilo: he's the most generic and the highest payoff).
- [ ] Add 2 to 3 **real branches** per Story file that set a flag; reference them in a later chapter.
- [ ] Add a small hook to read/write `world_flags` from `.dtl` conditions so callbacks are one line.
- [ ] Replace name-switch tables in `Generic/Purchase.dtl` with short per-character barks pulled from the voice sheets.
- [ ] Add 1 **NPC-initiated** moment per character at Rank 4+ (they come in and bring up what *you* did).
- [ ] Gate **one** deeper beat per character behind a journal-taboo choice.
- [ ] Re-read every scene aloud; cut 40%.

---

## 8. Sources (from web research)

- Cozy-game dialogue craft: emotional tiers, choice as tone, subtext with physical actions (various narrative-design write-ups).
- *Coffee Talk*, *Unpacking*, *Venba*, *Potion Permit*: small-scale intimacy, objects as narrators, empathy-based choices.
- *Stardew Valley* heart events: slow trust, subverting archetypes, player as witness, consequence for wrong answers.
- Barks, subtext, show-don't-tell, and consequence design (narrative-design references including The Narrative Department).
- Sari-sari store storytelling: utang, suki, tsismis, and the counter as a stage for folklore.
