--!strict

--[[
    CheckPositionDeltas.server.lua
    Author: Michael Southern [DevIrradiant]

    Description: Monitors the delta of character Positions.
    
    NOTE: Package automatically starts, just configure the SetupConfiguration
    under Refs to what best suits your experience below. 
    
    You may attach an attribute to the player {isTeleporting: boolean}.
    Toggle this accordingly if you intend to teleport players intentionally -
    both before and after the teleport.

    RefreshRate: Seconds per check
    MaxMagnitude: Maximum stud allowance
    DebugMode: Disables kicking, enables warns (great for
    helping configure RefreshRate and MaxMagnitude)
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Types
type Configuration = {
    RefreshRate: number,
    MaxMagnitude: number,
    DebugMode: boolean
}

-- Refs
local _configuration = {
    RefreshRate = 0.1,
    MaxMagnitude = 30,
    DebugMode = true
} :: Configuration

local _positionData = {} :: {[Player]: Vector3}
local _respawnConnections = {} :: {[Player]: RBXScriptConnection}
local _diedConnections = {} :: {[Player]: RBXScriptConnection}
local _elapsed = 0



-- Class
local PositionDeltaService = {}

-- Create player entry
function PositionDeltaService:_playerAdded(player: Player?)
    if not player then
        return
    end

    -- add new position entry
    local playerEntry = _positionData[player]
    if not playerEntry then
        _positionData[player] = Vector3.zero
    end

    -- add a respawn connection entry -- prevent false positive when respawning
    local respawnEntry = _respawnConnections[player]
    if not respawnEntry then
        -- listen for new character
        _respawnConnections[player] = player.CharacterAdded:Connect(function(newCharacter: Model)
            -- zero out position entry to prevent false positive
            _positionData[player] = Vector3.zero
    
            -- listen for humanoid
            local humanoid = newCharacter:WaitForChild("Humanoid", 5) :: Humanoid?
            if humanoid then
                -- listen for Died, zero out position entry to prevent false positive
                _diedConnections[player] = humanoid.Died:Once(function()
                    _positionData[player] = Vector3.zero
                    _diedConnections[player] = nil
                end)
            end
        end) 
    end
end

-- Remove player entry
function PositionDeltaService:_playerRemoving(player: Player?)
    if not player then
        return
    end

    -- remove position entry
    local playerEntry = _positionData[player]
    if playerEntry then
        _positionData[player] = nil
    end

    -- remove respawn detection entry
    local respawnEntry = _respawnConnections[player]
    if respawnEntry then
        _respawnConnections[player]:Disconnect()
        _respawnConnections[player] = nil
    end

    -- remove died connection entry
    local diedEntry = _diedConnections[player]
    if diedEntry then
        _diedConnections[player]:Disconnect()
        _diedConnections[player] = nil
    end
end

-- Player exceeded MaxMagnitude
function PositionDeltaService:_exceededMaxMagnitude(player: Player?)
    if not player then
        return
    end

    local playerEntry = _positionData[player]
    if not playerEntry then
        return
    end

    if _configuration.DebugMode then
        warn(`{player.Name} has exceeded MaxMagnitude`)
    else
        player:Kick()
    end
end

-- Compare positions for each player
function PositionDeltaService:_scan()
    -- filter through all player entries
    for player: Player, lastPosition: Vector3 in _positionData do

        -- prevent yield for each player
        task.spawn(function()
            -- TODO verify player isn't being teleported by the server
            
            -- verify a character exists
            local character = player.Character :: Model?
            if character then
                -- verify humanoid exists and player is alive
                local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
                if not humanoid then
                    return
                end
                if humanoid.Health <= 0 then
                    return
                end

                -- check magnitude
                local currentPosition = character:GetPivot().Position
                local magnitude = (currentPosition - lastPosition).Magnitude

                -- check to see if defined threshold was exceeded
                if magnitude > _configuration.MaxMagnitude then
                    -- check to see if player entry is new before firing exceeded
                    if lastPosition ~= Vector3.zero then
                        PositionDeltaService:_exceededMaxMagnitude(player)
                    end
                end

                -- update entry
                if player then
                    _positionData[player] = currentPosition
                end
            end
        end)
        
    end
end


-- init
-- Listen for entering / exiting Players
Players.PlayerAdded:Connect(function(player: Player)
    PositionDeltaService:_playerAdded(player)
end)
Players.PlayerRemoving:Connect(function(player: Player)
    PositionDeltaService:_playerRemoving(player)
end)
for _, player: Player in Players:GetPlayers() do
    PositionDeltaService:_playerAdded(player)
end

-- Begin scanning
RunService.Heartbeat:Connect(function(deltaTime: number)
    -- add time passed
    _elapsed += deltaTime
        
    -- determine if it's time for a scan
    if _elapsed >= _configuration.RefreshRate then
        _elapsed = 0
        PositionDeltaService:_scan()
    end
end)
