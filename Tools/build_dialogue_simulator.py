#!/usr/bin/env python3
"""
Builds a 100% self-contained, mobile-friendly single-file HTML Visual Novel
dialogue simulator (`tools/dialogue_simulator.html`) embedding all real `.dtl`
timelines, chapter prerequisites, and epilogue data from Sari-Saring Katha.

Usage:
    python tools/build_dialogue_simulator.py
"""

import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TIMELINES_DIR = ROOT / "Dialogue" / "Timelines"
OUTPUT_HTML = ROOT / "tools" / "dialogue_simulator.html"

CHARACTERS = [
    {"id": "kuyakap", "name": "Kuya Kap", "folder": "Kuyakap", "color": "#d49b54", "cats": ["cigarette", "bottle", "candy"], "prereqs": {3: [("manangana", 2)]}},
    {"id": "manangana", "name": "Manang Ana", "folder": "ManangAna", "color": "#e07a5f", "cats": ["can", "frozen", "pack"], "prereqs": {3: [("kuyakap", 2)], 4: [("buboy", 4)]}},
    {"id": "buboy", "name": "Buboy", "folder": "Buboy", "color": "#81b29a", "cats": ["snack", "candy", "can"], "prereqs": {4: [("kuyakap", 3)]}},
    {"id": "lolopilo", "name": "Lolo Pilo", "folder": "LoloPilo", "color": "#f2cc8f", "cats": ["candy", "snack", "sachet"], "prereqs": {}},
    {"id": "tk", "name": "T.K.", "folder": "TK", "color": "#6cb2eb", "cats": ["bottle", "snack", "pack"], "prereqs": {}},
    {"id": "rodel", "name": "Rodel", "folder": "Rodel", "color": "#4ea8de", "cats": ["bottle", "can", "frozen"], "prereqs": {1: [("sarimanok", 2)], 2: [("sarimanok", 3)], 3: [("sarimanok", 4)], 4: [("sarimanok", 4)], 5: [("sarimanok", 5)]}},
    {"id": "sarimanok", "name": "Sarimanok", "folder": "Sarimanok", "color": "#f6c90e", "cats": ["snack", "pack", "can"], "prereqs": {1: [("rodel", 1)], 2: [("rodel", 2)], 3: [("rodel", 3)], 4: [("rodel", 4)], 5: [("rodel", 5)]}},
    {"id": "brahim", "name": "Brahim", "folder": "Brahim", "color": "#7ec292", "cats": ["can", "sachet", "bottle"], "prereqs": {3: [("rosalyn", 3)]}},
    {"id": "danilo", "name": "Danilo", "folder": "Danilo", "color": "#b8a9c9", "cats": ["snack", "bottle", "sachet"], "prereqs": {1: [("rosalyn", 1)], 3: [("rosalyn", 4)]}},
    {"id": "rosalyn", "name": "Rosalyn", "folder": "Rosalyn", "color": "#cfe0f5", "cats": ["candy", "bottle"], "visit_until_final": True, "prereqs": {2: [("brahim", 1)], 3: [("danilo", 2)], 4: [("brahim", 4), ("danilo", 4)]}},
    {"id": "reynamayari", "name": "Reyna Mayari", "folder": "ReynaMayari", "color": "#c9b6ff", "cats": ["candy", "frozen", "bottle", "snack"], "collector": True, "prereqs": {}},
]

SAMPLE_ITEMS = {
    "cigarette": ["Champyon", "Marboro", "Mayti"],
    "candy": ["Mentor", "Pocha", "Chubs"],
    "bottle": ["Tubig", "Kokaloka", "C2"],
    "can": ["Argentita", "Cenchuree Tuna", "Mema"],
    "frozen": ["Tocino", "Hotdog", "Ice Candy"],
    "sachet": ["Kopimo", "Aryel"],
    "snack": ["Anoba", "Patos", "Dantes"],
    "pack": ["Pantit", "Lucky9"],
}


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def collect_timelines() -> dict:
    data = {}
    for ch in CHARACTERS:
        cid = ch["id"]
        folder = TIMELINES_DIR / ch["folder"]
        data[cid] = {
            "story": read_text(folder / "Story.dtl"),
            "purchase": read_text(folder / "Purchase.dtl"),
            "visit": read_text(folder / "Visit.dtl"),
        }
    data["_special"] = {
        "mayari_collect": read_text(TIMELINES_DIR / "mayari_collect.dtl"),
        "papa_ulap": read_text(TIMELINES_DIR / "PapaUlap.dtl"),
        "mario_tutorial": read_text(TIMELINES_DIR / "UncleMarioTutorial.dtl"),
    }
    return data


def build_html(bundle: dict) -> str:
    bundle_json = json.dumps(bundle, ensure_ascii=False)
    # Prevent closing </script> injection
    bundle_json = bundle_json.replace("</", "<\\/")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
<title>Sari-Saring Katha — Mobile VN Dialogue Simulator</title>
<style>
  :root {{
    --bg: #120f0c;
    --panel: #1b1612;
    --panel-2: #241d17;
    --gold: #d59f47;
    --gold-bright: #ffe294;
    --cream: #fff5e4;
    --muted: #b8a995;
    --green: #7ec292;
    --red: #e0635a;
    --border: rgba(213, 159, 71, 0.35);
  }}
  * {{ box-sizing: border-box; -webkit-tap-highlight-color: transparent; }}
  html, body {{
    margin: 0; padding: 0; height: 100%; background: var(--bg); color: var(--cream);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    overflow: hidden;
  }}
  .app {{
    display: flex; flex-direction: column; height: 100dvh; max-width: 640px; margin: 0 auto;
    background: radial-gradient(circle at top, #282018 0%, var(--bg) 65%);
  }}
  /* Top HUD */
  .topbar {{
    display: flex; align-items: center; justify-content: space-between; gap: 8px;
    padding: 10px 12px; background: rgba(15, 12, 10, 0.92); border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }}
  .hud-stats {{ font-size: 12px; color: var(--gold-bright); font-weight: 600; line-height: 1.35; }}
  .hud-stats span {{ color: var(--muted); font-weight: 400; }}
  .top-btns {{ display: flex; gap: 6px; }}
  .pill-btn {{
    background: var(--panel-2); color: var(--cream); border: 1px solid var(--border);
    border-radius: 8px; padding: 6px 10px; font-size: 12px; font-weight: 600; cursor: pointer;
  }}
  .pill-btn.gold {{ background: #3e2e16; color: var(--gold-bright); border-color: var(--gold); }}
  .pill-btn:active {{ transform: scale(0.97); }}

  /* Stage */
  .stage {{
    flex: 1; display: flex; flex-direction: column; justify-content: flex-end;
    padding: 12px; gap: 10px; overflow-y: auto; position: relative;
  }}
  .char-card {{
    margin: auto 0; text-align: center; padding: 14px 12px;
    background: rgba(27, 22, 18, 0.72); border: 1px solid var(--border); border-radius: 14px;
  }}
  .avatar {{
    width: 72px; height: 72px; border-radius: 50%; margin: 0 auto 8px;
    display: flex; align-items: center; justify-content: center;
    font-size: 28px; font-weight: 800; color: #120f0c;
    border: 3px solid var(--gold); box-shadow: 0 6px 18px rgba(0,0,0,0.45);
  }}
  .char-title {{ font-size: 18px; font-weight: 700; color: var(--gold-bright); }}
  .char-meta {{ font-size: 12px; color: var(--muted); margin-top: 2px; }}
  .order-pill {{
    display: inline-block; margin-top: 8px; padding: 4px 10px; border-radius: 999px;
    background: rgba(126, 194, 146, 0.16); border: 1px solid var(--green);
    color: var(--green); font-size: 12px; font-weight: 600;
  }}

  /* Log toast */
  .toast {{
    font-size: 11px; color: var(--gold-bright); background: rgba(62, 46, 22, 0.9);
    border: 1px solid var(--gold); border-radius: 8px; padding: 6px 10px; text-align: center;
  }}

  /* Gameplay Debug Bar */
  .action-bar {{
    display: flex; flex-wrap: wrap; gap: 6px; padding: 8px 12px;
    background: #171310; border-top: 1px solid var(--border); flex-shrink: 0;
  }}
  .act-btn {{
    flex: 1 1 auto; min-width: 92px; padding: 9px 10px; border-radius: 9px;
    border: 1px solid var(--border); background: var(--panel-2); color: var(--cream);
    font-size: 12px; font-weight: 700; cursor: pointer; text-align: center;
  }}
  .act-btn.primary {{ background: #2c4a35; border-color: var(--green); color: #e8ffef; }}
  .act-btn.sub {{ background: #4b3818; border-color: var(--gold-bright); color: var(--gold-bright); }}
  .act-btn.warn {{ background: #4a2320; border-color: var(--red); color: #ffd9d6; }}
  .act-btn:active {{ transform: scale(0.97); }}

  /* Dialogue Box */
  .dialogue-wrap {{
    padding: 12px; background: #14100d; border-top: 2px solid var(--gold); flex-shrink: 0;
  }}
  .speaker {{
    font-size: 13px; font-weight: 800; letter-spacing: 0.4px; margin-bottom: 4px;
    text-transform: uppercase;
  }}
  .text-box {{
    min-height: 76px; font-size: 16px; line-height: 1.45; color: var(--cream);
    cursor: pointer; user-select: none; padding: 4px 0 8px;
  }}
  .tap-hint {{ font-size: 11px; color: var(--muted); text-align: right; }}
  .choices {{ display: flex; flex-direction: column; gap: 7px; margin-top: 8px; }}
  .choice-btn {{
    width: 100%; text-align: left; padding: 11px 13px; border-radius: 10px;
    background: var(--panel-2); color: var(--gold-bright); border: 1px solid var(--gold);
    font-size: 14px; font-weight: 600; cursor: pointer;
  }}
  .choice-btn:active {{ background: #3c2e1c; }}

  /* Modal / Drawer */
  .overlay {{
    position: fixed; inset: 0; background: rgba(0,0,0,0.82); z-index: 50;
    display: none; align-items: center; justify-content: center; padding: 14px;
  }}
  .overlay.open {{ display: flex; }}
  .modal {{
    width: 100%; max-width: 520px; max-height: 86dvh; overflow-y: auto;
    background: var(--panel); border: 2px solid var(--gold); border-radius: 14px;
    padding: 16px; display: flex; flex-direction: column; gap: 10px;
  }}
  .modal h3 {{ margin: 0; color: var(--gold-bright); font-size: 18px; }}
  .grid-2 {{ display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }}
  .stat-row {{
    display: flex; justify-content: space-between; font-size: 13px; padding: 6px 8px;
    background: var(--panel-2); border-radius: 8px; border: 1px solid rgba(255,255,255,0.06);
  }}
  .shake {{ display: inline-block; animation: shk 0.25s infinite; }}
  @keyframes shk {{
    0% {{ transform: translate(0,0); }} 25% {{ transform: translate(1px,-1px); }}
    50% {{ transform: translate(-1px,1px); }} 75% {{ transform: translate(1px,1px); }}
  }}
</style>
</head>
<body>
<div class="app">
  <div class="topbar">
    <div class="hud-stats" id="hudStats">Day 1 · Ledger ₱0 / ₱2000</div>
    <div class="top-btns">
      <button class="pill-btn gold" onclick="openPicker()">Cast</button>
      <button class="pill-btn" onclick="openDebug()">Debug</button>
    </div>
  </div>

  <div class="stage" id="stage">
    <div class="char-card" id="charCard">
      <div class="avatar" id="avatar">?</div>
      <div class="char-title" id="charTitle">Sari-Saring Katha VN Sim</div>
      <div class="char-meta" id="charMeta">Tap "Next Random Customer" below to begin!</div>
      <div class="order-pill" id="orderPill" style="display:none"></div>
    </div>
    <div class="toast" id="toast" style="display:none"></div>
  </div>

  <div class="action-bar" id="actionBar"></div>

  <div class="dialogue-wrap">
    <div class="speaker" id="speaker" style="color: var(--gold-bright)">SYSTEM</div>
    <div class="text-box" id="textBox" onclick="onTapDialogue()">Welcome! Tap Next Random Customer, or open Cast to jump into any character's story.</div>
    <div class="choices" id="choices"></div>
    <div class="tap-hint" id="tapHint">Tap text to continue</div>
  </div>
</div>

<!-- Dynamic Prompt Modal (Minigame / Tally / Epilogue) -->
<div class="overlay" id="promptOverlay">
  <div class="modal" id="promptModal"></div>
</div>

<!-- Cast Picker Modal -->
<div class="overlay" id="pickerOverlay" onclick="if(event.target===this) closeModals()">
  <div class="modal">
    <h3>Pick Customer / Event</h3>
    <div class="grid-2" id="pickerGrid"></div>
    <button class="act-btn sub" onclick="startNightlyMayari(); closeModals();">🌙 Nightly Reyna Mayari</button>
    <button class="act-btn" onclick="startSpecial('papa_ulap','Chatter','Papa Ulap'); closeModals();">📻 Papa Ulap Radio</button>
    <button class="act-btn" onclick="startSpecial('mario_tutorial','Greeting','Uncle Mario'); closeModals();">🛵 Uncle Mario Tutorial</button>
    <button class="pill-btn" onclick="closeModals()">Close</button>
  </div>
</div>

<!-- Debug Inspector Modal -->
<div class="overlay" id="debugOverlay" onclick="if(event.target===this) closeModals()">
  <div class="modal">
    <h3>Debug State & Shortcuts</h3>
    <div class="grid-2">
      <button class="act-btn sub" onclick="addLedger(600)">+₱600 (30% Mayari)</button>
      <button class="act-btn primary" onclick="addLedger(2000)">Seal Ledger (₱2000)</button>
      <button class="act-btn" onclick="showEpilogueModal()">Preview Epilogue</button>
      <button class="act-btn warn" onclick="resetState()">Reset All Progress</button>
    </div>
    <div id="debugBody" style="display:flex;flex-direction:column;gap:6px;"></div>
    <button class="pill-btn" onclick="closeModals()">Close</button>
  </div>
</div>

<script>
const BUNDLE = {bundle_json};

const STATE = {{
  day: 1,
  ledgerPaid: 0,
  ledgerGoal: 2000,
  mayariMet: false,
  chapters: {{}},
  tallies: {{}},
  outcomes: {{}},
  flags: {{}},
  debts: {{}},
  lastCustomer: "",
  lastItem: "",
}};

function initState() {{
  STATE.day = 1; STATE.ledgerPaid = 0; STATE.mayariMet = false;
  STATE.chapters = {{}}; STATE.tallies = {{}}; STATE.outcomes = {{}}; STATE.flags = {{}}; STATE.debts = {{}};
  STATE.lastCustomer = ""; STATE.lastItem = "";
  for (const c of BUNDLE.characters) {{
    STATE.chapters[c.id] = 0;
    STATE.tallies[c.id] = 0;
    STATE.outcomes[c.id] = "";
    STATE.debts[c.id] = 0;
  }}
  saveLocal();
}}

function saveLocal() {{
  try {{ localStorage.setItem("ssk_vn_sim_v1", JSON.stringify(STATE)); }} catch (e) {{}}
}}
function loadLocal() {{
  try {{
    const raw = localStorage.getItem("ssk_vn_sim_v1");
    if (raw) {{ Object.assign(STATE, JSON.parse(raw)); return true; }}
  }} catch (e) {{}}
  return false;
}}
if (!loadLocal()) initState();

function resetState() {{
  initState();
  closeModals();
  showToast("Progress reset to Day 1!");
  renderIdle();
}}

// ── Structured AST DTL Parser & Frame-Stack Interpreter ──────────────────

function parseDTLToLabels(text) {{
  const rawLines = text.split(/\\r?\\n/);
  const flat = [];
  for (let i = 0; i < rawLines.length; i++) {{
    const raw = rawLines[i];
    const trimmed = raw.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    let indent = 0;
    while (indent < raw.length && raw[indent] === "\\t") indent++;
    flat.push({{ indent, text: trimmed }});
  }}

  function parseBlock(startIdx, minIndent) {{
    const stmts = [];
    let i = startIdx;
    while (i < flat.length) {{
      const cur = flat[i];
      if (cur.indent < minIndent) break;
      const t = cur.text;
      if (cur.indent === 0 && t.startsWith("label ")) break;

      if (t.startsWith("if ") && t.endsWith(":")) {{
        const ind = cur.indent;
        const branches = [];
        let cond = t.slice(3, -1).trim();
        let res = parseBlock(i + 1, ind + 1);
        branches.push({{ cond, body: res.stmts }});
        i = res.nextIdx;
        while (i < flat.length && flat[i].indent === ind) {{
          const nt = flat[i].text;
          if (nt.startsWith("elif ") && nt.endsWith(":")) {{
            cond = nt.slice(5, -1).trim();
            res = parseBlock(i + 1, ind + 1);
            branches.push({{ cond, body: res.stmts }});
            i = res.nextIdx;
          }} else if (nt === "else:") {{
            res = parseBlock(i + 1, ind + 1);
            branches.push({{ cond: null, body: res.stmts }});
            i = res.nextIdx;
            break;
          }} else {{
            break;
          }}
        }}
        stmts.push({{ type: "if_chain", branches }});
        continue;
      }}

      if (t.startsWith("- ")) {{
        const ind = cur.indent;
        const options = [];
        while (i < flat.length && flat[i].indent === ind && flat[i].text.startsWith("- ")) {{
          const label = flat[i].text.slice(2).trim();
          const res = parseBlock(i + 1, ind + 1);
          options.push({{ label, body: res.stmts }});
          i = res.nextIdx;
        }}
        stmts.push({{ type: "choices", options }});
        continue;
      }}

      if (t === "[end_timeline]") {{
        stmts.push({{ type: "end" }});
      }} else if (t.startsWith("[wait ")) {{
        // ignore wait timers in VN sim
      }} else if (t.startsWith("jump ")) {{
        stmts.push({{ type: "jump", target: t.slice(5).trim() }});
      }} else if (t.startsWith("set ")) {{
        const m = t.match(/^set\\s+\\{{([^}}]+)\\}}\\s*=\\s*range\\((\\d+),\\s*(\\d+)\\)\\.pick_random\\(\\)/);
        if (m) stmts.push({{ type: "set_rand", varName: m[1].trim(), lo: parseInt(m[2], 10), hi: parseInt(m[3], 10) }});
      }} else if (t.startsWith("[signal ")) {{
        const m = t.match(/arg="([^"]+)"/);
        if (m) stmts.push({{ type: "signal", arg: m[1] }});
      }} else {{
        const colon = t.indexOf(":");
        if (colon > 0 && !t.startsWith("[")) {{
          stmts.push({{ type: "line", speaker: t.slice(0, colon).trim(), text: t.slice(colon + 1).trim() }});
        }}
      }}
      i++;
    }}
    return {{ stmts, nextIdx: i }};
  }}

  const labels = {{}};
  let i = 0;
  while (i < flat.length) {{
    if (flat[i].indent === 0 && flat[i].text.startsWith("label ")) {{
      const aliases = [];
      while (i < flat.length && flat[i].indent === 0 && flat[i].text.startsWith("label ")) {{
        aliases.push(flat[i].text.slice(6).trim());
        i++;
      }}
      const res = parseBlock(i, 0);
      for (const a of aliases) labels[a] = res.stmts;
      i = res.nextIdx;
    }} else {{
      const res = parseBlock(i, 0);
      if (!labels["__root__"]) labels["__root__"] = res.stmts;
      i = res.nextIdx;
    }}
  }}
  return labels;
}}

let RUN = null; // Current timeline runner state

function buildVars(ctx) {{
  const v = {{}};
  const cid = ctx.charId || "";
  const ch = cid ? (STATE.chapters[cid] || 0) : 0;
  v.Transaction_Chapter = ch;
  v.Transaction_Tally = cid ? (STATE.tallies[cid] || 0) : 0;
  v.Transaction_ItemWants = ctx.itemWants || "Anoba";
  v.Transaction_SubstituteItemName = ctx.subItemName || "Mentor";
  v.Transaction_HasReactiveOpener = false;
  v.Transaction_ReactiveOpener = "";
  v.Transaction_StoryGouged = !!ctx.gouged;
  v.Transaction_MinigameWon = !!ctx.minigameWon;
  v.Transaction_WantsDebt = ctx.wantsDebt ? 1.0 : 0.0;
  v.Transaction_RepaymentAmount = cid ? (STATE.debts[cid] || 0) : 0;
  v.Transaction_GreetingVar = Math.random() * 100;
  v.Transaction_TalkVar = Math.random() * 100;
  v.Transaction_SatisfyVar = Math.random() * 100;
  v.Transaction_WrongItemVar = Math.random() * 100;
  v.Transaction_VisitVar = Math.random() * 100;
  v.Variation = 1.0;

  v.Global_TipActive = Math.random() < 0.25 ? 1.0 : 0.0;
  v.Global_RumorActive = STATE.lastCustomer ? (Math.random() < 0.35 ? 1.0 : 0.0) : 0.0;
  v.Global_RumorType = Math.random() < 0.5 ? 0.0 : 1.0;
  v.Global_LastCustomer = STATE.lastCustomer || "Kuya Kap";
  v.Global_LastItem = STATE.lastItem || "Anoba";
  v.Global_EventRumorActive = false;
  v.Global_RadioEclipse = false;
  v.Global_RadioTimeCheck = "10:30 AM";
  v.Global_TimeOfDayPhase = "before_noon";
  v.Global_TallyGoal = STATE.ledgerGoal;
  v.Global_TallyTotalPaid = STATE.ledgerPaid;
  v.Global_TallyRemaining = Math.max(0, STATE.ledgerGoal - STATE.ledgerPaid);
  v.Global_TallyMin = Math.min(80, v.Global_TallyRemaining);
  v.Global_TallyOffer = ctx.tallyOffer || 0;
  v.Global_MayariMet = STATE.mayariMet;
  const ratio = STATE.ledgerPaid / STATE.ledgerGoal;
  v.Global_LedgerTier = ratio >= 1 ? 5 : ratio >= 0.75 ? 4 : ratio >= 0.5 ? 3 : ratio >= 0.3 ? 2 : ratio >= 0.15 ? 1 : 0;

  let allies = 0;
  for (const id of Object.keys(STATE.outcomes)) if (STATE.outcomes[id]) allies++;
  v.Global_CompletedNeighborsCount = allies;

  // Map all world flags & outcome convenience flags
  const flagMap = {{
    Flag_KapClinicKnown: !!STATE.flags.kap_clinic_known,
    Flag_KapSubCandy: !!STATE.flags.kap_sub_candy,
    Flag_KapQuitSmoking: STATE.outcomes.kuyakap === "quit_smoking",
    Flag_AnaUtangAccepted: !!STATE.flags.ana_utang_accepted_early,
    Flag_AnaUtangRefused: !!STATE.flags.ana_utang_refused_early,
    Flag_AnaSubFeast: !!STATE.flags.ana_sub_feast,
    Flag_AnaFlewAgain: STATE.outcomes.manangana === "flew_again",
    Flag_BuboyTeksWon: !!STATE.flags.buboy_teks_won,
    Flag_BuboyTrustedErrand: !!STATE.flags.buboy_trusted_errand,
    Flag_BuboyRunner: STATE.outcomes.buboy === "trusted_runner",
    Flag_PiloPunsoRattled: !!STATE.flags.pilo_punso_rattled,
    Flag_PiloSubSweet: !!STATE.flags.pilo_sub_sweet,
    Flag_PiloWagerSet: !!STATE.flags.pilo_wager_set,
    Flag_PiloChampion: STATE.outcomes.lolopilo === "grand_champion",
    Flag_TKTrueNameKnown: !!STATE.flags.tk_true_name_known,
    Flag_TKSubHydrate: !!STATE.flags.tk_sub_hydrate,
    Flag_TKRematchAccepted: !!STATE.flags.tk_rematch_accepted,
    Flag_TKTrailWarden: STATE.outcomes.tk === "trail_warden",
    Flag_RodelNameRemembered: !!STATE.flags.rodel_name_remembered,
    Flag_RodelSubWater: !!STATE.flags.rodel_sub_water,
    Flag_RodelShelteredBird: !!STATE.flags.rodel_sheltered_bird,
    Flag_RodelRememberedAnito: STATE.outcomes.rodel === "remembered_anito",
    Flag_SmkMetRodel: !!STATE.flags.smk_met_rodel,
    Flag_SmkSubFish: !!STATE.flags.smk_sub_fish,
    Flag_SmkHonoredRodel: !!STATE.flags.smk_honored_rodel,
    Flag_SmkLivingEmblem: STATE.outcomes.sarimanok === "living_emblem",
    Flag_RosalynSeen: !!STATE.flags.rosalyn_seen,
    Flag_RosalynWelcome: !!STATE.flags.rosalyn_welcome,
    Flag_RosalynErrandKnown: !!STATE.flags.rosalyn_errand_known,
    Flag_RosalynAtPeace: STATE.outcomes.rosalyn === "peaceful_anchor",
    Flag_BrahimSteadyStart: !!STATE.flags.brahim_steady_start,
    Flag_BrahimSubRest: !!STATE.flags.brahim_sub_rest,
    Flag_BrahimLanternWard: !!STATE.flags.brahim_lantern_ward,
    Flag_BrahimTrueAlbularyo: STATE.outcomes.brahim === "true_albularyo",
    Flag_DaniloSawRosalyn: !!STATE.flags.danilo_saw_rosalyn,
    Flag_DaniloEyesKnown: !!STATE.flags.danilo_eyes_known,
    Flag_DaniloTracedTether: !!STATE.flags.danilo_traced_tether,
    Flag_DaniloWatchfulAlly: STATE.outcomes.danilo === "watchful_ally",
    Flag_MayariOwesUtang: !!STATE.flags.mayari_owes_utang,
    Flag_MayariRefusedBlackRice: !!STATE.flags.mayari_refused_black_rice,
    Flag_MayariTrustBarangay: !!STATE.flags.mayari_trust_barangay,
    Flag_MayariQueenAtCounter: STATE.outcomes.reynamayari === "queen_at_the_counter",
  }};
  Object.assign(v, flagMap);
  return v;
}}

function evalExpr(expr, vars) {{
  let s = expr.replace(/\\{{([^}}]+)\\}}/g, (_, k) => {{
    const val = vars[k.trim()];
    if (typeof val === "string") return JSON.stringify(val);
    if (val === undefined) return "false";
    return String(val);
  }});
  s = s.replace(/\\band\\b/g, "&&").replace(/\\bor\\b/g, "||").replace(/\\bnot\\b/g, "!");
  try {{ return !!Function("return (" + s + ");")(); }} catch (e) {{ return false; }}
}}

function formatText(raw, vars) {{
  let s = raw.replace(/\\{{([^}}]+)\\}}/g, (_, k) => vars[k.trim()] !== undefined ? vars[k.trim()] : "");
  s = s.replace(/\\[color=([^\\]]+)\\]/g, '<span style="color:$1;font-weight:700">').replace(/\\[\\/color\\]/g, "</span>");
  s = s.replace(/\\[shake[^\\]]*\\]/g, '<span class="shake">').replace(/\\[\\/shake\\]/g, "</span>");
  s = s.replace(/\\[(pause|wave)[^\\]]*\\]/g, "").replace(/\\[\\/(wave)\\]/g, "");
  return s;
}}

function startTimeline(dtlText, label, ctx) {{
  const labels = parseDTLToLabels(dtlText);
  const vars = buildVars(ctx);
  RUN = {{
    labels, vars, ctx,
    frames: [],
    waitingChoice: false,
    waitingTap: false,
    ended: false,
    subCat: "",
    pendingMilestones: [],
  }};
  const startKey = (label && labels[label]) ? label : (labels["Greeting"] ? "Greeting" : Object.keys(labels)[0]);
  if (startKey) jumpToLabel(startKey);
  updateHUD();
  renderActionBar();
  stepRunner();
}}

function jumpToLabel(lbl) {{
  if (!RUN || !RUN.labels[lbl]) return false;
  RUN.frames = [{{ list: RUN.labels[lbl], idx: 0 }}];
  RUN.waitingChoice = false;
  RUN.waitingTap = false;
  RUN.ended = false;
  return true;
}}

function stepRunner() {{
  if (!RUN || RUN.ended) return;
  RUN.waitingChoice = false;
  RUN.waitingTap = false;
  document.getElementById("choices").innerHTML = "";

  while (RUN.frames.length > 0) {{
    const top = RUN.frames[RUN.frames.length - 1];
    if (top.idx >= top.list.length) {{
      RUN.frames.pop();
      continue;
    }}
    const stmt = top.list[top.idx++];

    if (stmt.type === "end") {{
      finishPhase();
      return;
    }}
    if (stmt.type === "jump") {{
      if (jumpToLabel(stmt.target)) continue;
      finishPhase();
      return;
    }}
    if (stmt.type === "set_rand") {{
      RUN.vars[stmt.varName] = Math.floor(Math.random() * (stmt.hi - stmt.lo)) + stmt.lo;
      continue;
    }}
    if (stmt.type === "if_chain") {{
      for (const b of stmt.branches) {{
        if (b.cond === null || evalExpr(b.cond, RUN.vars)) {{
          if (b.body.length > 0) RUN.frames.push({{ list: b.body, idx: 0 }});
          break;
        }}
      }}
      continue;
    }}
    if (stmt.type === "choices") {{
      RUN.waitingChoice = true;
      renderChoices(stmt.options);
      return;
    }}
    if (stmt.type === "signal") {{
      const paused = handleSignal(stmt.arg);
      if (paused) return;
      continue;
    }}
    if (stmt.type === "line") {{
      showLine(stmt.speaker, stmt.text);
      RUN.waitingTap = true;
      return;
    }}
  }}
  finishPhase();
}}

function renderChoices(options) {{
  const box = document.getElementById("choices");
  document.getElementById("tapHint").textContent = "Choose a response";
  box.innerHTML = "";
  options.forEach(o => {{
    const btn = document.createElement("button");
    btn.className = "choice-btn";
    btn.innerHTML = formatText(o.label, RUN.vars);
    btn.onclick = () => {{
      if (o.body && o.body.length > 0) RUN.frames.push({{ list: o.body, idx: 0 }});
      stepRunner();
    }};
    box.appendChild(btn);
  }});
}}

function showLine(spk, rawBody) {{
  const c = BUNDLE.characters.find(x => x.folder.toLowerCase() === spk.toLowerCase() || x.id === spk.toLowerCase());
  const spkEl = document.getElementById("speaker");
  spkEl.textContent = c ? c.name : spk;
  spkEl.style.color = c ? c.color : "var(--gold-bright)";
  document.getElementById("textBox").innerHTML = formatText(rawBody, RUN.vars);
  document.getElementById("tapHint").textContent = "Tap text to continue";
}}

function onTapDialogue() {{
  if (!RUN || RUN.waitingChoice) return;
  if (RUN.waitingTap) {{
    stepRunner();
  }}
}}

function handleSignal(arg) {{
  const cid = RUN.ctx.charId;
  if (arg.startsWith("flag:")) {{
    const [k, val] = arg.slice(5).split("=");
    STATE.flags[k] = (val === "true" || val === undefined);
    Object.assign(RUN.vars, buildVars(RUN.ctx));
    showToast("Flag set: " + k + " = " + STATE.flags[k]);
    saveLocal();
  }} else if (arg.startsWith("tally:")) {{
    const delta = parseInt(arg.slice(6), 10) || 0;
    if (cid) {{
      STATE.tallies[cid] = (STATE.tallies[cid] || 0) + delta;
      RUN.vars.Transaction_Tally = STATE.tallies[cid];
      showToast(cid + " tally " + (delta >= 0 ? "+" : "") + delta + " (now " + STATE.tallies[cid] + ")");
      saveLocal();
    }}
  }} else if (arg.startsWith("outcome:")) {{
    const out = arg.slice(8);
    if (cid) {{
      STATE.outcomes[cid] = out;
      showToast("Outcome unlocked: " + out);
      saveLocal();
    }}
  }} else if (arg.startsWith("allow_sub_cat:")) {{
    RUN.subCat = arg.slice(14);
    const pool = BUNDLE.items[RUN.subCat] || ["Mentor"];
    RUN.ctx.subItemName = pool[0];
    RUN.vars.Transaction_SubstituteItemName = pool[0];
    renderActionBar();
    showToast("Secret Substitution active: " + RUN.subCat + " (" + pool[0] + ")");
  }} else if (arg === "utang_accepted") {{
    if (cid) STATE.debts[cid] = (STATE.debts[cid] || 0) + 35;
    showToast("Utang accepted (+₱35 on lista)");
    saveLocal();
  }} else if (arg === "repay_debt") {{
    if (cid) STATE.debts[cid] = 0;
    showToast("Utang repaid!");
    saveLocal();
  }} else if (arg === "story_success" || arg === "story_fail_forward") {{
    if (RUN.ctx.mode === "story" && cid && !RUN.ctx.completed) {{
      STATE.chapters[cid] = Math.min(6, (STATE.chapters[cid] || 0) + 1);
      showToast(RUN.ctx.charName + " advanced to Chapter " + STATE.chapters[cid] + "!");
      saveLocal();
    }}
    RUN.ctx.completed = true;
  }} else if (arg === "refuse_service") {{
    showToast("Out of stock — White Check retry next visit!");
    RUN.ctx.completed = true;
  }} else if (arg.startsWith("minigame:")) {{
    const mg = arg.slice(9);
    openPrompt(`
      <h3>🎮 Minigame: ${{mg}}</h3>
      <div style="font-size:14px;color:var(--muted)">Simulate the minigame outcome to test Win vs. Fail-Forward dialogue:</div>
      <div class="grid-2">
        <button class="act-btn primary" onclick="resolveMinigame(true)">Simulate WIN</button>
        <button class="act-btn warn" onclick="resolveMinigame(false)">Simulate LOSE</button>
      </div>
    `);
    return true;
  }} else if (arg === "open_tally_offer") {{
    STATE.mayariMet = true;
    saveLocal();
    if (STATE.ledgerPaid >= STATE.ledgerGoal) {{
      openPrompt(`
        <h3>🌙 Sealed Ledger — Pick Lunar Favor</h3>
        <div style="font-size:14px;color:var(--muted)">The Silver Ledger is sealed! Draw a free Favor card for tomorrow.</div>
        <button class="act-btn primary" onclick="resolveTally(0, 'SealedOutro')">Claim Lunar Favor</button>
      `);
      return true;
    }}
    openPrompt(`
      <h3>🌙 Reyna Mayari's Nightly Tally</h3>
      <div style="font-size:14px;color:var(--muted)">Paid: ₱${{STATE.ledgerPaid}} / ₱${{STATE.ledgerGoal}}</div>
      <button class="act-btn primary" onclick="resolveTally(300, 'Generous')">Generous (+₱300 · Favors)</button>
      <button class="act-btn sub" onclick="resolveTally(100, 'Success')">Balanced (+₱100)</button>
      <button class="act-btn warn" onclick="resolveTally(20, 'Shortfall')">Shortfall (+₱20 · Omen)</button>
      <button class="act-btn primary" onclick="resolveTally(${{STATE.ledgerGoal - STATE.ledgerPaid}}, 'LedgerCleared')">Seal Full Ledger (₱2000)</button>
    `);
    return true;
  }} else if (arg === "check_mayari_milestones") {{
    if (RUN.pendingMilestones && RUN.pendingMilestones.length > 0) {{
      const nextId = RUN.pendingMilestones.shift();
      if (jumpToLabel("Milestone_" + nextId)) {{
        return false; // keep stepping straight into the milestone label!
      }}
    }}
  }} else if (arg === "show_epilogue") {{
    showEpilogueModal();
    return true;
  }}
  updateHUD();
  return false;
}}

function resolveMinigame(won) {{
  closeModals();
  RUN.ctx.minigameWon = won;
  RUN.vars.Transaction_MinigameWon = won;
  stepRunner();
}}

function resolveTally(amt, targetLabel) {{
  closeModals();
  const prev = STATE.ledgerPaid;
  STATE.ledgerPaid = Math.min(STATE.ledgerGoal, STATE.ledgerPaid + amt);
  STATE.day += 1;
  saveLocal();
  RUN.ctx.tallyOffer = amt;
  RUN.pendingMilestones = [];
  const milestones = [
    ["reroll_1", 300],
    ["daytime_mayari", 600],
    ["shifted_odds_reroll_2", 1000],
    ["twin_moons", 1500],
  ];
  for (const [mid, thresh] of milestones) {{
    if (prev < thresh && STATE.ledgerPaid >= thresh) RUN.pendingMilestones.push(mid);
  }}
  Object.assign(RUN.vars, buildVars(RUN.ctx));
  if (STATE.ledgerPaid >= STATE.ledgerGoal && prev < STATE.ledgerGoal) targetLabel = "LedgerCleared";
  RUN.ctx.completed = true;
  jumpToLabel(targetLabel);
  updateHUD();
  stepRunner();
}}

function finishPhase() {{
  RUN.ended = true;
  RUN.waitingTap = false;
  document.getElementById("tapHint").textContent = RUN.ctx.completed ? "Visit finished — tap Next Random Customer" : "Use counter buttons below (or Next Customer)";
  renderActionBar();
}}

// ── Customer Selection & Real Prerequisite DAG ───────────────────────────

function canPlayStory(chObj) {{
  const cur = STATE.chapters[chObj.id] || 0;
  if (cur >= 6) return false;
  if (chObj.collector && STATE.ledgerPaid < 600) return false;
  const reqs = chObj.prereqs[cur] || [];
  for (const [tid, minCh] of reqs) {{
    if ((STATE.chapters[tid] || 0) < minCh) return false;
  }}
  return true;
}}

function nextRandomCustomer() {{
  const pool = BUNDLE.characters.filter(c => !c.collector || STATE.ledgerPaid >= 600);
  // Prefer characters with an available story chapter (70% chance)
  const storyReady = pool.filter(canPlayStory);
  let pick = (storyReady.length && Math.random() < 0.72)
    ? storyReady[Math.floor(Math.random() * storyReady.length)]
    : pool[Math.floor(Math.random() * pool.length)];
  startCustomer(pick.id, null);
}}

function startCustomer(cid, forcedMode) {{
  const chObj = BUNDLE.characters.find(x => x.id === cid);
  if (!chObj) return;
  const curCh = STATE.chapters[cid] || 0;
  let mode = forcedMode;
  if (!mode) {{
    if (canPlayStory(chObj)) mode = "story";
    else if (chObj.visit_until_final && curCh < 6) mode = "visit";
    else mode = Math.random() < 0.7 ? "purchase" : "visit";
  }}
  const cat = chObj.cats[Math.floor(Math.random() * chObj.cats.length)];
  const itemList = BUNDLE.items[cat] || ["Anoba"];
  const itemWants = itemList[Math.floor(Math.random() * itemList.length)];
  const isVisitStory = ((cid === "rosalyn" && curCh < 5) || (cid === "sarimanok" && curCh === 0)) && mode === "story";

  const ctx = {{
    charId: cid, charName: chObj.name, color: chObj.color,
    mode, itemWants, isVisitStory,
    wantsDebt: (mode === "purchase" && Math.random() < 0.2),
    completed: false,
  }};
  STATE.lastCustomer = chObj.name;
  STATE.lastItem = itemWants;

  document.getElementById("avatar").style.background = chObj.color;
  document.getElementById("avatar").textContent = chObj.name.slice(0, 2).toUpperCase();
  document.getElementById("charTitle").textContent = chObj.name + (cid === "reynamayari" ? " (Disguised)" : "");
  document.getElementById("charMeta").textContent =
    (mode === "story" ? ("Story Chapter " + (curCh + 1) + " / 6") : mode.toUpperCase()) +
    " · Tally: " + (STATE.tallies[cid] || 0) +
    (STATE.outcomes[cid] ? (" · " + STATE.outcomes[cid]) : "");

  const pill = document.getElementById("orderPill");
  if (mode === "visit" || isVisitStory) {{
    pill.style.display = "none";
  }} else {{
    pill.style.display = "inline-block";
    pill.textContent = "Wants: " + itemWants;
  }}

  const dtl = BUNDLE.timelines[cid][mode];
  startTimeline(dtl, "Greeting", ctx);
}}

function startNightlyMayari() {{
  document.getElementById("avatar").style.background = "#c9b6ff";
  document.getElementById("avatar").textContent = "RM";
  document.getElementById("charTitle").textContent = "Reyna Mayari (Nightly Tally)";
  document.getElementById("charMeta").textContent = "Silver Ledger: ₱" + STATE.ledgerPaid + " / ₱" + STATE.ledgerGoal;
  document.getElementById("orderPill").style.display = "none";
  startTimeline(BUNDLE.timelines._special.mayari_collect, "Greeting", {{ charId: "reynamayari", charName: "Reyna Mayari", mode: "nightly", completed: false }});
}}

function startSpecial(key, label, title) {{
  document.getElementById("avatar").style.background = "#d59f47";
  document.getElementById("avatar").textContent = title.slice(0, 2).toUpperCase();
  document.getElementById("charTitle").textContent = title;
  document.getElementById("charMeta").textContent = "Special Broadcast / Event";
  document.getElementById("orderPill").style.display = "none";
  startTimeline(BUNDLE.timelines._special[key], label, {{ charId: "", charName: title, mode: "special", completed: true }});
}}

function renderActionBar() {{
  const bar = document.getElementById("actionBar");
  bar.innerHTML = "";
  const canServe = RUN && RUN.ended && !RUN.ctx.completed && (RUN.ctx.mode === "purchase" || (RUN.ctx.mode === "story" && !RUN.ctx.isVisitStory));

  if (canServe) {{
    const b1 = makeBtn("✓ Give " + RUN.ctx.itemWants, "act-btn primary", () => {{ RUN.vars.Transaction_StoryGouged = false; jumpToLabel("Satisfy"); stepRunner(); }});
    bar.appendChild(b1);
    if (RUN.subCat) {{
      bar.appendChild(makeBtn("★ Give Sub (" + RUN.ctx.subItemName + ")", "act-btn sub", () => {{ jumpToLabel("SubstituteItem"); stepRunner(); }}));
    }}
    bar.appendChild(makeBtn("₱ Overcharge", "act-btn warn", () => {{ RUN.vars.Transaction_StoryGouged = true; jumpToLabel("Satisfy"); stepRunner(); }}));
    bar.appendChild(makeBtn("✕ Wrong Item", "act-btn", () => {{ jumpToLabel("WrongItem"); stepRunner(); }}));
    bar.appendChild(makeBtn("Out of Stock", "act-btn", () => {{ jumpToLabel("Talk"); stepRunner(); }}));
  }} else {{
    bar.appendChild(makeBtn("🎲 Next Random Customer", "act-btn primary", nextRandomCustomer));
    bar.appendChild(makeBtn("🌙 Nightly Tally", "act-btn sub", startNightlyMayari));
  }}
}}

function makeBtn(label, cls, fn) {{
  const b = document.createElement("button");
  b.className = cls; b.textContent = label; b.onclick = fn;
  return b;
}}

function renderIdle() {{
  RUN = null;
  document.getElementById("charTitle").textContent = "Sari-Saring Katha VN Sim";
  document.getElementById("charMeta").textContent = "Tap Next Random Customer to begin!";
  document.getElementById("orderPill").style.display = "none";
  document.getElementById("speaker").textContent = "SYSTEM";
  document.getElementById("textBox").textContent = "Ready to test dialogues, prerequisites, substitutions, and endings!";
  document.getElementById("choices").innerHTML = "";
  updateHUD();
  renderActionBar();
}}

function updateHUD() {{
  let doneCh = 0;
  for (const c of BUNDLE.characters) doneCh += (STATE.chapters[c.id] || 0);
  const pct = Math.round((STATE.ledgerPaid / STATE.ledgerGoal) * 100);
  document.getElementById("hudStats").innerHTML =
    `Day ${{STATE.day}} · Ledger ₱${{STATE.ledgerPaid}}/₱${{STATE.ledgerGoal}} (${{pct}}%) <span>· Ch ${{doneCh}}/66</span>`;
}}

function showToast(msg) {{
  const t = document.getElementById("toast");
  t.textContent = msg; t.style.display = "block";
  clearTimeout(window._toastTimer);
  window._toastTimer = setTimeout(() => t.style.display = "none", 2600);
}}

function openPrompt(html) {{
  document.getElementById("promptModal").innerHTML = html;
  document.getElementById("promptOverlay").classList.add("open");
}}

function openPicker() {{
  const grid = document.getElementById("pickerGrid");
  grid.innerHTML = "";
  for (const c of BUNDLE.characters) {{
    const cur = STATE.chapters[c.id] || 0;
    const locked = !canPlayStory(c) && cur < 6;
    const btn = document.createElement("button");
    btn.className = "act-btn";
    btn.innerHTML = `${{c.name}}<br><span style="font-size:10px;color:var(--muted)">Ch ${{cur}}/6${{locked ? " (Prereq)" : ""}}</span>`;
    btn.onclick = () => {{ closeModals(); startCustomer(c.id, null); }};
    grid.appendChild(btn);
  }}
  document.getElementById("pickerOverlay").classList.add("open");
}}

function openDebug() {{
  const body = document.getElementById("debugBody");
  body.innerHTML = "";
  for (const c of BUNDLE.characters) {{
    const row = document.createElement("div");
    row.className = "stat-row";
    row.innerHTML = `<b>${{c.name}}</b><span>Ch ${{STATE.chapters[c.id]||0}}/6 · Tally ${{STATE.tallies[c.id]||0}} · ${{STATE.outcomes[c.id]||"—"}}</span>`;
    body.appendChild(row);
  }}
  const flags = Object.keys(STATE.flags).filter(k => STATE.flags[k]);
  const fRow = document.createElement("div");
  fRow.className = "stat-row";
  fRow.innerHTML = `<b>Active Flags</b><span style="text-align:right;max-width:65%">${{flags.length ? flags.join(", ") : "None"}}</span>`;
  body.appendChild(fRow);
  document.getElementById("debugOverlay").classList.add("open");
}}

function addLedger(amt) {{
  STATE.ledgerPaid = Math.min(STATE.ledgerGoal, STATE.ledgerPaid + amt);
  saveLocal();
  updateHUD();
  closeModals();
  showToast("Silver Ledger now ₱" + STATE.ledgerPaid + " / ₱" + STATE.ledgerGoal);
}}

function showEpilogueModal() {{
  let doneCh = 0, doneArcs = 0;
  let rows = "";
  for (const c of BUNDLE.characters) {{
    doneCh += (STATE.chapters[c.id] || 0);
    if (STATE.outcomes[c.id]) doneArcs++;
    rows += `<div class="stat-row"><b>${{c.name}}</b><span style="color:var(--gold-bright)">${{STATE.outcomes[c.id] || "Unfinished (Ch " + (STATE.chapters[c.id]||0) + "/6)"}}</span></div>`;
  }}
  openPrompt(`
    <h3>✨ Karimlan Chronicle — Thank You for Playing!</h3>
    <div style="font-size:13px;color:var(--muted)">Day ${{STATE.day}} · Story Chapters: ${{doneCh}} / 66 · Stories Finished: ${{doneArcs}} / 11</div>
    ${{rows}}
    <div style="font-size:12px;color:var(--cream);padding:8px;background:var(--panel-2);border-radius:8px;">
      ${{66 - doneCh > 0 ? ("There are still " + (66 - doneCh) + " story chapters waiting across Karimlan — keep playing or reset to discover alternate endings!") : "All 66 chapters completed! Reset to try different choices and alternate endings."}}
    </div>
    <button class="act-btn primary" onclick="closeModals()">Keep the Shutters Open</button>
  `);
}}

function closeModals() {{
  document.querySelectorAll(".overlay").forEach(el => el.classList.remove("open"));
}}

renderIdle();
</script>
</body>
</html>
"""


def main():
    bundle = {
        "characters": CHARACTERS,
        "items": SAMPLE_ITEMS,
        "timelines": collect_timelines(),
    }
    OUTPUT_HTML.parent.mkdir(parents=True, exist_ok=True)
    html = build_html(bundle)
    OUTPUT_HTML.write_text(html, encoding="utf-8")
    size_kb = OUTPUT_HTML.stat().st_size / 1024.0
    print(f"Generated {OUTPUT_HTML} ({size_kb:.1f} KB) with {len(CHARACTERS)} characters + special timelines.")


if __name__ == "__main__":
    main()
