# Project Context

## Session Role

This project is currently in a game-idea concretization phase. Treat this file as the baseline planning guide before gameplay, scene, UI, map, or tool work.

## Game Direction

- Build a small 2D LÖVE mini-game designed for fast production.
- Target a Steam release if the project proves fun enough.
- The game is a Touhou Project fan work using Kijin Seija, Kishin Sagume, and moon rabbit characters.
- Seija and Sagume do not need to be playable leads. They can function as systems, commanders, disruptions, or narrative devices.
- Prioritize a compact replayable loop over a long fixed campaign.

## Story Premise

- The story takes place at a banquet held sometime after the events of Legacy of Lunatic Kingdom.
- Kijin Seija plans to ruin the banquet.
- Shinmyoumaru Sukuna is not a core mastermind. She is a helper who has been talked into assisting Seija.
- Kishin Sagume is not an invited guest and cannot openly help without making her involvement conspicuous.
- Sagume detects the sabotage and gives unofficial orders to Ringo and Seiran, who are already present in Gensokyo.
- Ringo and Seiran remained in Gensokyo after the Legacy of Lunatic Kingdom incident instead of fully withdrawing.
- Sagume's deeper motive should remain somewhat open to player interpretation.

## Character Roles

- Directors: Kishin Sagume and Doremy Sweet.
- Players: Ringo and Seiran.
- Roaming participants: Suika Ibuki, Mystia Lorelei, and Rumia.
- Interference candidate participants: Cirno, Tewi Inaba, Mamizou Futatsuiwa, and Reisen Udongein Inaba.
- Opposing side: Kijin Seija and Shinmyoumaru Sukuna.

## Player Characters

- The player chooses either Ringo or Seiran before a run or stage.
- Only the selected character is controlled during that run or stage.
- Both obey Sagume as a superior officer and trust her instructions.
- Ringo is more relaxed and flexible.
- Seiran is more military-minded and focused on mission execution.
- Do not create character differences that split core puzzle routes unless there is a clear need.

Initial character direction:

- Ringo benefits more from supplies.
- Seiran can use limited bullets to briefly stun roaming participants.
- Supply effects are not finalized and should be tuned during implementation.
- Seiran's bullets are non-lethal control tools, not attacks that defeat participants.

## Core Pitch

Moon rabbit operatives receive written mission orders from Sagume and carry out missions in noisy field conditions.

- Written mission orders are accurate and should be followed as written.
- Sagume's live call briefings are shown as call UI text, not actual voice.
- Because Sagume's spoken words invert outcomes, call briefing information must be interpreted in reverse.
- Seija interferes by creating noise, fake call fragments, misleading UI, and chaotic field conditions.

The player must combine reliable written orders with reversed live briefing information while filtering Seija's interference.

## Core Rules

### Written Orders

- Written orders define the real mission goals.
- Written orders are not spoken, so they are interpreted normally.
- Keep written goals simple and readable.
- Written orders and Sagume briefings are fully separate systems: orders define goals, briefings define hazards or field information.
- Orders should appear in a dedicated UI at stage start and remain visible in the right-side in-game panel.

Examples:

- Retrieve the supply box.
- Activate the seal device.
- Evacuate through the north exit.
- Inspect the marked terminal.

### Sagume Call Briefings

- Sagume's call briefings should focus on hazards, obstacles, field conditions, and risk information.
- They must not rewrite, cancel, or replace the mission objective.
- Since the briefing is spoken, the practical meaning is reversed.
- Briefings are displayed through call UI text, not actual voice.
- Briefings are triggered by nearby objects such as participants, supplies, or objective points.
- Early briefing text should use clear opposite pairs. More ambiguous wording can be considered later for higher difficulty.
- The original briefing log may be implemented simply first. Whether to show it during play should be decided after playtesting.

Examples:

- "The west corridor is safe." means the west corridor is dangerous.
- "The red box is genuine." means the red box is fake.
- "There are no guards near the east door." means guards are near the east door.
- "Seija will be quiet this time." means Seija interference will be strong.

### Doremy Support

- Doremy helps when Sagume is absent or by cutting into communication.
- Doremy's own statements are interpreted normally.
- Doremy may relay Sagume's original words. In that case, the Sagume statement is still interpreted in reverse.
- Doremy may also explain Sagume's words after already reversing their meaning. In that case, Doremy's explanation is interpreted normally.
- Sagume and Doremy do not use honorific distance with each other. Doremy can speak casually about Sagume.
- Doremy also supports the retry fiction: stage failure can be treated as a dream outcome and restarted.

Examples:

- "Sagume says the west side is safe." means the west side is dangerous.
- "If Sagume says that, the west side is dangerous." means the west side is dangerous.
- "I think the north path is fine." means the north path is fine.
- "Let's leave that outcome as a dream." can be used for retry presentation.

### Seija Interference

- Seija creates confusion, not unsolvable ambiguity.
- Fake information must always have a readable tell.
- The player should feel clever for filtering Seija, not tricked by unfair noise.
- Do not start with fake communication UI as Seija's main role. Establish her in-game interference first.
- Seija's first gameplay role is trap and field disruption.

Possible interference:

- Screen or control inversion traps.
- Direction or sign confusion.
- Disguised hazards that resemble supplies or objective objects.
- Objects that cause damage when touched or when their trigger condition is met.
- Roaming participant patterns made harder to read or avoid.

## Participants And Hazards

- Roaming obstacles are banquet participants, including existing Touhou characters such as Suika, Mystia, and Rumia.
- They should not be framed as enemies to defeat.
- Use terms such as participant, noisy participant, or obstruction rather than enemy where possible.
- Player interaction with them is avoidance-first.
- HP loss represents being caught in the commotion, hit by a hazard, or disrupted by a participant.
- Seiran's bullets can briefly stun participants, with limited ammunition.
- Participants move according to character-flavored patterns.
- Triggers can include contact, range entry, line of sight, objective approach, or timed behavior.

Example participant patterns:

- Suika wanders drunkenly, blocks paths, and can become a larger collision threat.
- Mystia can interfere with visibility or on-screen clarity.
- Rumia can create darkness areas, hide paths, or reduce visibility around hazards.

Interference candidate direction:

- Cirno is the strongest first add: ice fields, slippery movement, frozen paths, or temporary route blocks.
- Tewi is a strong second add: traps, fake supplies, prank routing, and bait objects.
- Reisen fits the moon rabbit theme but should avoid overlapping with Sagume/Doremy/Seija information rules; use restrained perception or danger-zone disruption if added.
- Mamizou is best saved for later because disguise and fake-object systems increase production cost.
- Do not add all candidates at once. Add one participant pattern at a time and test whether it changes play clearly.

## Obstacles

- Use HP as the failure pressure.
- Use time limits as a difficulty pressure.
- Attack-type hazards can reduce HP.
- Non-attack interference should mainly increase difficulty by delaying, confusing, or forcing reroutes.
- Pushable boxes are common puzzle objects used to block participant routes.
- Do not differentiate Ringo and Seiran through box handling.

## Replayable Structure

Use card-like mission generation instead of only fixed stages.

Each run can combine:

- A written order card.
- A map layout.
- Object positions and initial states.
- Sagume hazard briefing cards.
- Seija interference cards.
- Time limit or rank target.

Keep the generation authored, not free-form natural language. Prewritten cards are enough.

## Map Structure

- Maps should control tempo through instructions, hazards, participants, and interference rather than deep exploration.
- Avoid complex dungeon layouts that make players spend time simply searching.
- Use room-grid layouts with 10x10 rooms.
- Some rooms are fixed by a global map pattern.
- Non-fixed rooms can be selected randomly from authored room templates.
- Add volume by adding special encounter rooms one at a time.
- Keep routes shallow, with goals and exits readable early.
- Randomness should mostly affect what disruption appears, not whether the player can find the stage objective.

Possible global patterns:

- Cross pattern: fixed center plus north, south, east, and west rooms.
- Corner pattern: fixed northwest, northeast, southwest, and southeast rooms.
- T pattern: one central branch point with short objective, supply, and exit branches.
- Ring or loop patterns can be added only if they stay compact and readable.

Good randomization targets:

- Which participant appears.
- Which room contains supplies.
- Which route is hazardous.
- Which objective approach contains a trap.
- Which Sagume or Doremy briefing triggers near a point of interest.

Bad randomization targets:

- Hiding objectives too deeply.
- Too many dead ends.
- Long repeated corridors.
- Large maps that make movement time the main challenge.

## Minimal Scope

The first playable version should include:

- One moon rabbit player character.
- Top-down 2D movement.
- Interact button.
- Call UI text presentation.
- Written order panel.
- Timer and mission result screen.
- 3-4 object types.
- 4-6 map layouts.
- Enough cards for short replayable runs.

Initial object set:

- Supply box: retrieve, ignore, distinguish real/fake.
- Seal device: activate or avoid.
- Exit door: choose correct evacuation route.
- Hazard tile or guarded area: avoid based on reversed briefing.
- Pushable box: block participant movement routes.

## Recommended Run Format

- 3-5 minute mission runs.
- A run contains several small objectives in one compact map.
- Failure should give immediate, readable feedback.
- Retry should be fast.
- Ranking can be based on time, mistakes, and optional objectives.

## What To Avoid Early

- Real voice recognition.
- Full voice acting.
- Natural language generation.
- Large story routes.
- Complex enemy AI.
- Bullet hell systems.
- Large maps.
- Inventory-heavy gameplay.
- Growth or equipment systems.

Add these only after the base mission loop is proven fun.

## Setting Gaps To Keep In Mind

- Tutorial dialogue should teach the core rule early: written orders are read normally, spoken briefings are interpreted in reverse.
- Sagume uses written orders for stable goals, but must use real-time calls for changing field conditions.
- Ringo and Seiran already know Sagume's ability, so reversing spoken briefings is normal procedure for them.
- Sagume's motive should be implied, not over-explained.
- Shinmyoumaru's gameplay role is intentionally on hold until the core setting and loop need her.
- Seija's communication interference is also on hold until trap and roaming-obstacle gameplay are established.

## LÖVE Direction

- Use the LÖVE engine.
- Keep systems data-driven where it directly supports mission cards.
- Do not build a broad framework before the first playable loop.
- Favor small scenes, simple resources, and clear UI.
- Keyboard and controller support matter for a Steam target.

Likely data concepts:

- Mission definition.
- Written order card.
- Sagume briefing card.
- Seija interference card.
- Interactable object.
- Run state and scoring.

## Steam And Touhou Fan Work Notes

Follow the Touhou Project fan work guideline:

https://touhou-project.news/guideline/

Planning constraints:

- Clearly state that the game is a Touhou Project fan work.
- Avoid anything that could be mistaken for an official Touhou game.
- Do not use original game assets such as sprites, music, UI, or extracted materials.
- Create original art, music, UI, and sound.
- Avoid publishing original game endings or using original screenshots as game assets.
- Avoid excessive sexual content, defamatory content, or political/ideological messaging through Touhou fan work.
- Re-check the latest guideline before release, because the guideline can change.

Suggested notice:

> This is a fan-made work based on Touhou Project. It is not an official Touhou Project title.

Use equivalent Korean/Japanese/English wording as needed in the game, credits, and store page.
