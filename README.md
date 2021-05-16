# WeaponUsage

A DCS Lua script for tracking weapon usage. When a jet takes off with ordinance, a report file is generated that "debits" the number of munitions. When they land, the munitions are "credited" back, and the report is written again with the new state.

## Usage

To enable mission scripts to write to disk, you must first comment out these lines in your <DCS install directory>\Scripts\MissionScripting.lua. \*\*Note you will need to do this after every DCS update

```lua
do
    __DEV_ENV = true -- set this to enable extra logging and to pause the simulation on lua errors
    -- sanitizeModule('os')
    -- sanitizeModule('io')
    -- sanitizeModule('lfs')
    require = nil
    loadlib = nil
end
```

To use the script, download the contents of WeaponUsage.lua and add a "DO SCRIPT FILE" action to your mission. Once the script is loaded, add a "DO SCRIPT" action with the following code:

```lua
weapon_usage.init()
```

## Configuration

Add a trigger action AFTER the script has been loaded, add a "DO SCRIPT" action. Any configuration options NOT specified will be set to their default (shown below).

These are the available configuration options:

```lua
weapon_usage.config = {
    ["REPORT_FILENAME"] = "weapon_usage.csv",
    ["AIRBASE_REPORT_FILENAME"] = "airbase_weapon_usage.csv",
    ["TRACK_BY_AIRFIELD"] = false,
    ["ONLY_TRACK_HUMANS"] = true,
}

weapon_usage.init()
```

## Development

To enable verbose logging, set this in your <DCS install directory>\Scripts\MissionScripting.lua

```lua
do
    __DEV_ENV = true -- <-- verbose logging
    -- sanitizeModule('os')
    -- sanitizeModule('io')
    -- sanitizeModule('lfs')
    require = nil
    loadlib = nil
end
```

Add this to a "DO SCRIPT" action in your mission to reload the scripts every time the mission starts.

dofile(lfs.writedir()..[[..\..\WeaponUsage\WeaponUsage.lua]])
