# **PositionDeltaService**

## **Introduction**
This package is used to monitor the deltas of HumanoidRootParts at set intervals. It should be stored server-side.

## **Installation**
Install PositionDeltaService by adding a Wally dependency. (e.g. PositionDeltaService = "devirradiant/positiondeltaservice@^1")

## **Usage**
Positions are cached and magnitude is compared against a max threshold at set intervals. Once a magnitude exceeds the maximum theshold, the player is given a strike. Strikes are also refreshed at set intervals - this is in the event that false positives are detected. Once the player has exceeded the max number of strikes, they will be kicked. 

A default configuration is supplied, but it is recommended to adapt this based on the style of your game (e.g. A racing game where players are moving at higher speeds will require a higher maximum threshold with a more frequent interval.)

Use the exported type `Configuration` to create a config and `PositionDeltaService:UpdateConfiguration(config)` to re-configure the default configuration. Not all keys are required, so you may supply only the keys you want to overwrite. 

- MagnitudeRate: number | Seconds per check
- MaxMagnitude: number | Maximum stud allowance
- StrikeDebounce: number | Seconds per strike allowance (prevents spamming)
- StrikeRate: number | Seconds per MaxStrike check - Strikes reset each interval
- MaxStrikes: number | Maximum strike allowance
- DebugMode: boolean | Disables kicking, enables warns (helpful for determining best Configuration)

### **Configuration Example**
```lua
local PositionDeltaService = require(game:GetService("ServerScriptService").Packages.PositionDeltaService)

local configuration = {
    MagnitudeRate = 0.1,
    MaxMagnitude = 30,
    StrikeDebounce = 1,
    StrikeRate = 10,
    MaxStrikes = 5,

    DebugMode = true
} :: PositionDeltaService.Configuration

PositionDeltaService:UpdateConfiguration
```

This package also allows you to disable / enable monitoring for specific players with the `PositionDeltaService:IgnoreScan(player: Player, ignore: boolean)` method. This is useful for times where players may be travelling at high velocities, or when you intend teleport the player. 

### **Intentional Teleport Example**
```lua
local Player = game:GetService("Players").DevIrradiant
local PositionDeltaService = require(game:GetService("ServerScriptService").Packages.PositionDeltaService)

-- We're about to teleport the Player, ignore delta checking!
PositionDeltaService:IgnoreScan(Player, true)

-- Teleport the Player
Player.Character:PivotTo(CFrame.new(Vector3.new(100,0,100)))

-- Player has been teleported, resume delta checking!
PositionDeltaService:IgnoreScan(Player, false)
```