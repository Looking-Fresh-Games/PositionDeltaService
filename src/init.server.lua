--!strict

--[[
    CheckPositionDeltas.lua
    Author: MichaelSouthern

    Description: Monitors the delta of character Positions.
    
    NOTE: Package automatically starts, just configure the SetupConfiguration
    under Refs to what best suits your experience below. 
    
    You may attach an attribute to the player {isTeleporting: boolean}.
    Toggle this accordingly if you intend to teleport players intentionally -
    both before and after the teleport.

    RefreshRate: Seconds per check
    MaxMagnitude: Maximum stud allowance
    IgnoreState: OPTIONAL - string to 
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
local Configuration = {
    RefreshRate = 1,
    MaxMagnitude = 10,
    DebugMode = true
} :: Configuration


-- Class
local CheckPositionDeltas = {}
CheckPositionDeltas.__index = CheckPositionDeltas

function CheckPositionDeltas.new()
    local self = setmetatable({}, CheckPositionDeltas)

    -- Internal Refs
    self._positionData = {} :: any

    -- Listen for entering / exiting Players
    Players.PlayerAdded:Connect(function(player: Player)
        self:_playerAdded(player)
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        self:_playerRemoving(player)
    end)

    -- Setup
    for _, player: Player in Players:GetPlayers() do
        self:_playerAdded(player)
    end
    self:_init()

    return self
end

-- Create player entry
function CheckPositionDeltas:_playerAdded(player: Player?)
    if not player then
        return
    end

    local playerEntry = self._positionData[player]
    if playerEntry then
        return
    end

    self._positionData[player] = Vector3.zero
end

-- Remove player entry
function CheckPositionDeltas:_playerRemoving(player: Player?)
    if not player then
        return
    end

    local playerEntry = self._positionData[player]
    if not playerEntry then
        return
    end

    self._positionData[player] = nil
end

-- Player exceeded MaxMagnitude
function CheckPositionDeltas:_exceededMaxMagnitude(player: Player?)
    if not player then
        return
    end

    local playerEntry = self._positionData[player]
    if not playerEntry then
        return
    end

    if Configuration.DebugMode then
        warn(`{player.Name} has exceeded MaxMagnitude`)
    else
        player:Kick()
    end
end

-- Compare positions for each player
function CheckPositionDeltas:_scan()
    -- filter through all player entries
    for player: Player, lastPosition: Vector3 in self._positionData do
        -- TODO verify player isn't being teleported by the server
        
        -- verify a character exists
        local character = player.Character :: Model?
        if character then
            local currentPosition = character:GetPivot().Position
            local magnitude = (currentPosition - lastPosition).Magnitude
                
            -- check to see if defined threshold was exceeded
            if magnitude > Configuration.MaxMagnitude then
                -- check to see if player entry is new
                if lastPosition ~= Vector3.zero then
                    self:_exceededMaxMagnitude(player)
                end
            end

            -- update entry
            if player then
                self._positionData[player] = currentPosition
            end
        end
    end
end

function CheckPositionDeltas:_init()
    local elapsed = 0

    RunService.Heartbeat:Connect(function(deltaTime: number)
        -- add time passed
        elapsed += deltaTime
        
        -- determine if it's time for a scan
        if elapsed >= Configuration.RefreshRate then
            elapsed = 0
            self:_scan()
        end
    end)
end

CheckPositionDeltas.new()