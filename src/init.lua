--!strict

--[[
    PositionDeltaService.lua
    Author: Michael Southern [DevIrradiant]
]]

-- Types
export type Configuration = {
    MagnitudeRate: number,
    MaxMagnitude: number,
    StrikeDebounce: number,
    StrikeRate: number,
    MaxStrikes: number,

    DebugMode: boolean
}

type PlayerEntry = {
    Position: Vector3,
    Strikes: number,
    LastStrike: number,
    ScanActive: boolean
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Constants
local _configuration = {
    MagnitudeRate = 0.1,
    MaxMagnitude = 30,
    StrikeDebounce = 1,
    StrikeRate = 10,
    MaxStrikes = 5,

    DebugMode = false
} :: Configuration

local _playerData = {} :: {[Player]: PlayerEntry}
local _respawnConnections = {} :: {[Player]: RBXScriptConnection}
local _diedConnections = {} :: {[Player]: RBXScriptConnection}

-- Refs
local magnitudeTimer = 0
local strikeTimer = 0



-- Class
local PositionDeltaService = {}

-- Prevent client usage
if not RunService:IsServer() then
    warn(`client attempted to require package`)
    return PositionDeltaService
end

-- Create player entry
function PositionDeltaService:_playerAdded(player: Player?)
    if player == nil then
        warn(`no player was supplied`)
        return
    end

    -- add new position entry
    local playerEntry = _playerData[player]
    if not playerEntry then
        _playerData[player] = {
            Position = Vector3.zero,
            Strikes = 0,
            LastStrike = workspace:GetServerTimeNow(),
            ScanActive = true
        }

        playerEntry = _playerData[player]
    end

    -- add a respawn connection entry -- prevent false positive when respawning
    local respawnEntry = _respawnConnections[player]
    if not respawnEntry then
        -- listen for new character
        _respawnConnections[player] = player.CharacterAdded:Connect(function(newCharacter: Model)
            -- zero out position entry to prevent false positive
            playerEntry.Position = Vector3.zero
    
            -- listen for humanoid
            local humanoid = newCharacter:WaitForChild("Humanoid", 5) :: Humanoid?
            if humanoid then
                -- listen for Died, zero out position entry to prevent false positive
                _diedConnections[player] = humanoid.Died:Once(function()
                    playerEntry.Position = Vector3.zero
                    _diedConnections[player] = nil
                end)
            end
        end)
    end
end

-- Remove player entry
function PositionDeltaService:_playerRemoving(player: Player?)
    if player == nil then
        return
    end

    -- remove position entry
    local playerEntry = _playerData[player]
    if playerEntry then
        _playerData[player] = nil
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
    if player == nil then
        return
    end

    local playerEntry = _playerData[player]
    if not playerEntry then
        warn(`no entry found for {player.Name}`)
        return
    end

    if workspace:GetServerTimeNow() >= playerEntry.LastStrike + _configuration.StrikeDebounce then
        playerEntry.Strikes += 1
        playerEntry.LastStrike = workspace:GetServerTimeNow()

        if _configuration.DebugMode then
            warn(`{player.Name} has exceeded MaxMagnitude, strike {playerEntry.Strikes}`)
        end
    end
end

-- Compare positions for each player
function PositionDeltaService:_scan()
    -- filter through all player entries
    for player: Player, entry: PlayerEntry in _playerData do
        -- ensure player can be scanned
        if not entry.ScanActive then
            continue
        end

        -- prevent yield for each player
        task.spawn(function()
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
                local magnitude = (currentPosition - entry.Position).Magnitude

                -- check to see if defined threshold was exceeded
                if magnitude > _configuration.MaxMagnitude then
                    -- check to see if player entry is new before firing exceeded
                    if entry.Position ~= Vector3.zero then
                        PositionDeltaService:_exceededMaxMagnitude(player)
                    end
                end

                -- update entry
                if player then
                    _playerData[player].Position = currentPosition
                end
            end
        end)
        
    end
end

-- Check player Strikes
function PositionDeltaService:_handleStrikes()
    -- filter through all player entries
    for player: Player, entry: PlayerEntry in _playerData do
        -- if player exceeded, kick them, otherwise reset strikes
        if entry.Strikes >= _configuration.MaxStrikes then
            -- Assess debug status
            if _configuration.DebugMode then
                warn(`{player.Name} has exceeded MaxStrikes`)
                entry.Strikes = 0

                continue
            end

            player:Kick()
        else
            entry.Strikes = 0
        end
    end
end

-- Update configuration
function PositionDeltaService:UpdateConfiguration(config: Configuration?)
    -- ensure config was supplied
    if config == nil then
        warn(`no configuration was supplied`)
        return
    end

    -- ensure config is a table
    if typeof(config) ~= "table" then
        warn(`configuration must be table, not {typeof(config)}`)
        return
    end

    -- ensure all keys exist and types match
    for key, value in config do
        if _configuration[key] == nil then
            warn(`key {key} does not exist in configuration`)
            return
        else
            local currentType = typeof(value)
            local matchType = typeof(_configuration[key])
            if currentType ~= matchType then
                warn(`provided type {currentType} is incompatible with {key} type {matchType}`)
                return
            end
       end
    end
    
    -- overwrite default configuration key by key in the event any keys weren't supplied
    for key, value in config do
        _configuration[key] = value
    end
end

-- Disable / Enable scanning
function PositionDeltaService:IgnoreScan(player: Player?, ignore: boolean)
    -- ensure player was sent
    if player == nil then
        warn(`no player was provided`)
        return
    end

    -- ensure an entry exists for provided player
    local playerEntry = _playerData[player]
    if not playerEntry then
        warn(`no entry found for {player.Name}`)
        return
    end

    -- ensure an ignore was sent, and it's a boolean
    if ignore == nil then
        warn(`no boolean was provided`)
        return
    elseif typeof(ignore) ~= `boolean` then
        warn(`supplied ignore type must be boolean, not {typeof(ignore)}`)
        return
    end

    -- reset position if applicable
    if not ignore then
        playerEntry.Position = Vector3.zero
    end
    
    -- toggle ignore
    playerEntry.ScanActive = ignore
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
    magnitudeTimer += deltaTime
    strikeTimer += deltaTime
        
    -- determine if it's time for a scan
    if magnitudeTimer >= _configuration.MagnitudeRate then
        magnitudeTimer = 0
        PositionDeltaService:_scan()
    end
    if strikeTimer >= _configuration.StrikeRate then
        strikeTimer = 0
        PositionDeltaService:_handleStrikes()
    end
end)

return PositionDeltaService
