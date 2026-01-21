# Aerodrome-9: Anigma ECS Game Demo Spec

## 1. Concept Overview

Aerodrome-9 is a small, self-contained narrative tactics demo built to showcase:

- Anigma’s ECS architecture
- Governance-driven session harness
- Dynamic, locally generated dialogue via MLX-powered models

The fiction is “Foundation meets Jules Verne, but played on a Game Boy”:

On Aerodrome-9, a floating “balloon world” held together by relay towers and guild platforms, the Empire depends on the Guild of Windwrights for signal relays and lift gas. The Archive’s psychohistorians warn that a brief disruption here cascades into a century-long fracture. The Guild sees imperial requisitions as slow suffocation. The Empire fears losing command channels to the frontier. This is brass relays, airships, pneumatic tubes, data tablets, and probabilistic charts, not neon.

The single crisis for the demo:

> Will the Windwright Guild cut imperial relay access during the coming storm window?

There are three intersecting points of view:

- Archive field theoretician arrives with prediction charts and needs evidence and consent to adjust forecasts.  
- Imperial officer is tasked with securing the relay channels and can negotiate or coerce.  
- Frontier guild engineer controls physical relays and maintenance crews and balances guild autonomy against imperial demands.

The demo targets a single run of roughly fifteen to thirty minutes, with three to five scenes. Each scene is a small tile map, a handful of interactables and NPCs, and a single question that pushes global state.

## 2. Player Experience & Core Loop

Moment to moment, the player moves a low-resolution character on a 2D tile map, inspects devices and terminals, talks to NPCs, and triggers levers or consoles. Each scene has an investigation phase using verbs like Examine, Listen, and Probe which reveal facts and change internal flags and metrics. The vibe is “Detroit: Become Human” style investigations, but top-down 2D with sparse overlays instead of cinematic quick-time events.

Each scene has an action budget. Moving is free. Actions like inspect, talk, or use consume one action point. Certain special moves, such as forcing an emergency override or pulling in a remote prediction update, can cost two. When the action budget is exhausted or a critical flag flips, the scene resolves and pushes updates into WorldState and ChoiceHistory.

Across a full run, the player visits three to five scenes, such as Arrival Deck, Relay Control, Guild Hall, Storm Gantry, and Observation Spire. Earlier flags determine which scene comes next. If relaySecured is true, the storm confrontation might be skipped. If guildAnger exceeds a threshold, the player can be pushed into a blockade sequence.

After each scene, a simple psychohistory view shows a small chart of visited nodes, newly accessible branches, and current predicted outcomes. These are percentages computed from WorldState and ChoiceHistory, not a real ML model, so they stay predictable and testable.

## 3. ECS Data Model

All game state is expressed through ECS components, systems, and data-driven scene definitions.

### 3.1 Core Components

Positions and basic rendering:

```swift
struct Position: Component {
    var x: Int
    var y: Int
}

struct Velocity: Component {
    var dx: Int
    var dy: Int
}

struct Sprite: Component {
    var spriteId: String
    var z: Int
}

struct InputControlled: Component {
    var isEnabled: Bool
}
```

Narrative identity and social state:

```swift
struct ActorRole: Component {
    enum Role { case archive, officer, guild }
    var role: Role
}

struct FactionAlignment: Component {
    enum Faction { case archive, empire, guild }
    var faction: Faction
    var trust: Int   // range -100 ... 100
}

struct RelationshipMeter: Component {
    var targetId: EntityId
    var value: Int   // simple dyadic score
}
```

Interaction and triggers:

```swift
struct Interactable: Component {
    enum InteractionKind { case talk, examine, use, choice }
    var interactionId: String
    var kind: InteractionKind
}

struct InteractionZone: Component {
    var radius: Int
}

struct DialogueNode: Component {
    var nodeId: String
}

struct SceneTrigger: Component {
    var triggerId: String
    var conditions: [String]
}
```

Scene and global progression:

```swift
struct SceneState: Component {
    var sceneId: String
    var actionsRemaining: Int
    var resolved: Bool
}

struct WorldState: Component {
    var crisisFlags: [String: Bool]
    var metrics: [String: Double]   // relayAccess, guildAnger, archiveConfidence
}

struct ChoiceEntry: Codable {
    var sceneId: String
    var choiceId: String
    var effects: [StateEffect]
}

struct ChoiceHistory: Component {
    var entries: [ChoiceEntry]
}
```

UI overlay state:

```swift
struct UIFlowchartView: Component {
    var isVisible: Bool
}

struct UIDialogueView: Component {
    var active: Bool
    var currentNodeId: String?
}
```

### 3.2 Systems

- **InputSystem** reads input, marks desired movement and interaction intent for the player entity.  
- **MovementSystem** applies Velocity to Position, clamping to tile map bounds and collision masks.  
- **RenderingSystem** draws the tile map, sprites sorted by z, and overlay UIs via SpriteKit or a minimal renderer.  
- **InteractionSystem** finds nearby entities with InteractionZone and Interactable, and fires interaction events when the player accepts.  
- **DialogueSystem** resolves dialogue nodes and dynamic text, posts StateEffects, and advances or closes dialogue views.  
- **SceneResolutionSystem** decrements actionsRemaining on each interaction, marks the scene resolved on zero actions or if key flags were set, and pushes SceneTransition events.  
- **PsychohistorySystem** reads WorldState and ChoiceHistory and generates a small internal graph of nodes and edges for the flowchart UI.  
- **UISystem** toggles between exploration view, dialogue overlays, and the psychohistory flowchart.

All systems run inside the existing Anigma ECS engine so they can be driven by the same harness and governance stack.

## 4. Branching & State Representation

The game content is described with data-driven scene, choice, and state effect definitions. These can start as Swift structs and later move to JSON, YAML, or another external format for easier editing.

```swift
struct SceneDefinition: Codable {
    let id: String
    let pov: ActorRole.Role
    let mapId: String
    let npcs: [EntityBlueprint]
    let interactables: [EntityBlueprint]
    let entryConditions: [String: Bool]
    let actionsBudget: Int
    let choices: [ChoiceDefinition]
    let resolutionEffects: [StateEffect]
    let nextSceneCandidates: [SceneTransition]
}

struct ChoiceDefinition: Codable {
    let id: String
    let prompt: String
    let requirements: [String: Bool]
    let costs: Int
    let effects: [StateEffect]
    let nextSceneOverrides: [SceneTransition]?
}

struct SceneTransition: Codable {
    let sceneId: String
    let conditionFlags: [String: Bool]
}

struct StateEffect: Codable {
    enum Kind { case flagSet, flagClear, metricDelta, relationshipDelta }
    let kind: Kind
    let key: String
    let value: Double
}
```

After the player makes a choice, StateEffects are applied to WorldState and relevant components. For example, setting `relaySecured` to true, increasing `guildAnger` by ten, and raising `archiveConfidence` by five would be three separate effects. PsychohistorySystem then uses WorldState, ChoiceHistory, and SceneDefinition to compute possible next scenes and rough outcome probabilities for the flowchart.

## 5. Dynamic Dialogue via Local MLX LLM

Dialogue content is generated at runtime using a local MLX-powered language model. This keeps sensitive information on device and avoids network calls, while still allowing rich contextual variations in conversations. MLX provides fast on-device inference pipelines for LLMs that can be integrated into Swift via mlx-swift and the underlying C++ runtime.

### 5.1 Dialogue Engine Architecture

The dialogue engine sits behind a strict interface so it cannot randomly mutate world state.

```swift
struct DialogueContext: Codable {
    var pov: ActorRole.Role
    var sceneId: String
    var npcId: String
    var worldFlags: [String: Bool]
    var metrics: [String: Double]
    var relationships: [String: Int]
    var recentChoices: [ChoiceEntry]
}

struct DialogueTurn {
    var lineId: String
    var speaker: String
    var text: String
    var impliedEffects: [StateEffect]
}

protocol DialogueGenerator {
    func generateReply(context: DialogueContext,
                       playerChoice: String?) async throws -> DialogueTurn
}
```

The concrete implementation, `MLXDialogueGenerator`, uses mlx-swift to host a small local model, such as a quantized 3B or smaller instruction-tuned model. The pipeline is:

1. DialogueSystem builds a DialogueContext from ECS components and the last few ChoiceEntry values.  
2. It calls `generateReply` with the player’s last text choice or selected option.  
3. MLXDialogueGenerator builds a compact prompt that encodes the current scene, speaker role, relevant flags, and some canonical style instructions for the Aerodrome-9 setting, then runs a local inference step.  
4. The generated text is clamped using simple decoding rules and optional regex or classifier filters to keep it in bounds.  
5. The engine maps inferred emotional tone or explicit tags in the model output back into StateEffect values, for example small adjustments to trust, anger, or confidence metrics.

The dialogue engine is not allowed to freely change flags. It can only propose effects, which are then run through the existing governance and policy system before being applied. That preserves determinism where it matters and keeps playtests repeatable.

### 5.2 MLX Integration Constraints

The MLX integration should respect existing Anigma concerns:

- All MLX work runs locally on the player device.  
- Inference is isolated from file I/O; it only sees a DialogueContext and returns text.  
- No network access is required for dialogue, which keeps it testable and compliant in offline or privacy-sensitive environments.  
- Dialogue generation runs asynchronously and must respect a budget per turn, for example a short token cap and hard timeout so it never blocks the frame loop.

The actual model and tokenizer selection can be swapped without changing the DialogueGenerator interface: start with a small, fast model and iterate later.

## 6. Integration with Anigma / Harmonia Harness

The game demo is treated as a normal harness session, not a special case. The harness decides when to run a game session, under which config, and with which trust tier. The game only supplies domain-specific logic and metrics.

```swift
struct GameSessionIntent: Codable {
    let featureCategory: String       // "anigma.game.demo"
    let pov: ActorRole.Role
    let startingSceneId: String
    let trustTier: String
    let configId: String?
}
```

The main integration surface is defined by a `GameDemoRunner` protocol:

```swift
protocol GameDemoRunner {
    func runScene(intent: GameSessionIntent,
                  state: WorldState?) async throws -> (SessionReport, WorldState)

    func runGame(intent: GameSessionIntent) async throws -> SessionReport
}
```

The harness wraps game sessions in the usual governance flow. A scene run becomes a SessionReport populated with:

- Visited scenes and last scene id  
- Choices taken as (sceneId, choiceId) entries  
- World state deltas, for example flag changes and metric deltas  
- Simple health metrics such as factionStability or predictionAccuracy  
- GovernanceTrace that records any actions that were blocked due to policy or trust tier constraints

From the harness and governance side, the game demo is just another feature category with its own policy and bandit configuration. This keeps it consistent with the rest of Anigma and lets you eventually use the same machinery to optimize game content, difficulty, or testing strategies.

## 7. Concrete Next Steps

Short-term, the implementation sequence can be:

1. Create a standalone Swift module for the ECS game core that contains the components, systems, and GameDemoRunner.  
2. Implement a single scene definition, such as Relay Control, with three meaningful choices and simple flag and metric effects.  
3. Add a basic psychohistory flowchart view that uses the internal graph from PsychohistorySystem.  
4. Implement a very small MLXDialogueGenerator that runs a local model and is wired only into DialogueSystem.  
5. Add a harness adapter that creates a GameSessionIntent, calls runScene, and converts the result into a SessionReport with governance trace and metrics.

Once that vertical slice is working, Anigma gets a playable, ECS-driven, MLX-dialogue-powered demo that doubles as a harness client and a very loud signal to anyone looking that “yes, this stack can actually ship experiences, not just argue about configs.”
