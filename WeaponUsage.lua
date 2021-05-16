weapon_usage = {}

do
    local configDefaults = {
        ["REPORT_FILENAME"] = "weapon_usage.csv",
        ["AIRBASE_REPORT_FILENAME"] = "airbase_weapon_usage.csv",
        ["TRACK_BY_AIRFIELD"] = false,
        ["ONLY_TRACK_HUMANS"] = true,
    }

    local internalConfig = {}

    local ordinanceDiff = {}

    local airfieldOrdinanceDiff = {}

    local columns = {
        "displayName",
        "delta",
    }

    local menu = nil

    -- Create a uniq string each time the script is loaded.
    -- This prevents the next mission from loading after an "End Mission" action
    -- and over-writing the file.
    local fileUniqId = string.format("%s", math.random(0, 10000))

    local function log(tmpl, ...)
        local txt = string.format("[WU] " .. tmpl, ...)

        if __DEV_ENV == true then
            trigger.action.outText(txt, 30) 
        end

        env.info(txt)
    end

    local function buildConfig()
        local cfg = mist.utils.deepCopy(configDefaults)
        
        if weapon_usage.config then
            for k,v in pairs(weapon_usage.config) do
                cfg[k] = v
            end
        end

        return cfg
    end
    
    local function printMunitionStatus()
        local str = "Munition usage:\n--------------------------\n"
        for typeName,v in pairs(ordinanceDiff) do
            str = str .. string.format("%s: %s\n", v.displayName, v.delta)
        end
    
        trigger.action.outText(str, 30)
    end

    local function printAirfieldStatus(params)
        local str = string.format("%s munition usage:\n--------------------------\n", params.airfieldName)
        for typeName,v in pairs(airfieldOrdinanceDiff[params.airfieldName]) do
            str = str .. string.format("%s: %s\n", v.displayName, v.delta)
        end
    
        trigger.action.outText(str, 30)
    end
    
    local function adjustDiff(weaponTypeName, displayName, delta, airfieldName)
        if internalConfig.TRACK_BY_AIRFIELD then
            if not airfieldOrdinanceDiff[airfieldName] then
                airfieldOrdinanceDiff[airfieldName] = {}

                airfieldOrdinanceDiff[airfieldName][weaponTypeName] = {
                    displayName = displayName,
                    delta = 0,
                }
            end

            if airfieldOrdinanceDiff[airfieldName] and not airfieldOrdinanceDiff[airfieldName][weaponTypeName] then
                airfieldOrdinanceDiff[airfieldName][weaponTypeName] = {
                    displayName = displayName,
                    delta = 0,
                }
            end
            
            airfieldOrdinanceDiff[airfieldName][weaponTypeName].delta = airfieldOrdinanceDiff[airfieldName][weaponTypeName].delta + delta
        end
        
        if not ordinanceDiff[weaponTypeName] then
            ordinanceDiff[weaponTypeName] = { 
                displayName = displayName, 
                delta = 0, 
            }
        end
    
        ordinanceDiff[weaponTypeName].delta = ordinanceDiff[weaponTypeName].delta + delta
    end

    local function getReportFile(name, writeAccess)
        local fileName = string.format("%s\\%s_%s", lfs.writedir(), fileUniqId, name)
        local file = io.open(fileName, writeAccess and 'w' or 'r')

        return file
    end

    local function writeReport()
        local fp = getReportFile(internalConfig.REPORT_FILENAME, true)

        if not fp then
            log("Could not get file handle")
            return
        end

        local csv = ""
        for typeName,usageRecord in pairs(ordinanceDiff) do
            local row = ""
            for i,col in ipairs(columns) do

                -- Ensure the last column does not get a comma
                local fmt = i == #columns and "%s" or "%s,"
                row = row .. string.format(fmt, usageRecord[col])
            end
            row = row .. "\n"
            csv = csv .. row
        end

        log("Writing report file...")
        fp:write(csv)
        fp:close()
    end

    local function writeAirbaseReport()
        local fp = getReportFile(internalConfig.AIRBASE_REPORT_FILENAME, true)

        if not fp then
            log("Could not get file handle")
            return
        end

        local csv = ""
        for airbaseName,record in pairs(airfieldOrdinanceDiff) do
            for typeName,usageRecord in pairs(record) do
                local row = string.format("%s,", airbaseName)
                for i,col in ipairs(columns) do
                    -- Ensure the last column does not get a comma
                    local fmt = i == #columns and "%s" or "%s,"
                    row = row .. string.format(fmt, usageRecord[col])
                end
                row = row .. "\n"
                csv = csv .. row
            end
        end

        log("Writing airbase report file...")
        fp:write(csv)
        fp:close()
    end
    
    local function eventHandler (event)
        local object = event.initiator
        if object == nil then
            return
        end
        
        if event.id == world.event.S_EVENT_TAKEOFF or event.id == world.event.S_EVENT_LAND then
            local ordinance = object:getAmmo()

            if not ordinance then
                -- Unit does not have weapons/ammo
                return
            end

            if internalConfig.ONLY_TRACK_HUMANS then
                local unit = Unit.getByName(object:getName())
    
                if unit then
                    if unit:getPlayerName() == nil then
                        -- Only track humans
                        return
                    end
                end
            end    

            -- Subtract on takeoff, add on land
            local sign = event.id == world.event.S_EVENT_TAKEOFF and -1 or 1

            local airfieldName = "Ground"
            if event.place then
                airfieldName = event.place:getName()
            end

            local eventText = event.id == world.event.S_EVENT_TAKEOFF and "taken off" or "landed"

            log("Unit %s has %s at %s", object:getName(), eventText, airfieldName)

            if internalConfig.TRACK_BY_AIRFIELD then
                if not airfieldOrdinanceDiff[airfieldName] then
                    missionCommands.addCommand(airfieldName, menu, printAirfieldStatus, { airfieldName=airfieldName })
                end
            end

            for i,weapon in ipairs(ordinance) do
                adjustDiff(weapon.desc.typeName, weapon.desc.displayName, (weapon.count * sign), airfieldName)
            end

            writeReport()

            if internalConfig.TRACK_BY_AIRFIELD then
                writeAirbaseReport()
            end
        end
    end


    function weapon_usage.init()
        -- This will ensure the server does not pause on errors.
        -- Warning: you need to check your DCS logs if you do not have this variable set.
        if not __DEV_ENV == true then
            env.setErrorMessageBoxEnabled(false)
        end

        internalConfig = buildConfig()

        menu = missionCommands.addSubMenu("Show munitions status")
        missionCommands.addCommand("Total", menu, printMunitionStatus)

        mist.addEventHandler(eventHandler)

        local msg = string.format("Weapon usage tracking enabled. Unique file ID: %s", fileUniqId)
        log(msg)
        trigger.action.outText(msg, 30)
    end
end