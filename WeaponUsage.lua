weapon_usage = {}

do
    local configDefaults = {
        ["REPORT_FILENAME"] = "weapon_usage.csv",
    }

    local internalConfig = {}

    local ordinanceDiff = {}

    local columns = {
        "displayName",
        "delta",
    }

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
    
    local function adjustDiff(weaponTypeName, displayName, delta)
        if not ordinanceDiff[weaponTypeName] then
            ordinanceDiff[weaponTypeName] = { 
                displayName = displayName, 
                delta = 0, 
            }
        end
    
        ordinanceDiff[weaponTypeName].delta = ordinanceDiff[weaponTypeName].delta + delta
    
        -- Log the diff so someone can see how to adjust stores in the next mission
        -- log(mist.utils.tableShow(ordinanceDiff))
    end

    local function getReportFile(writeAccess)
        local fileName = string.format("%s\\%s", lfs.writedir(), internalConfig.REPORT_FILENAME)
        local file = io.open(fileName, writeAccess and 'w' or 'r')

        return file
    end

    local function writeReport()
        local fp = getReportFile(true)

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
    
    local function eventHandler (event)
        local object = event.initiator
        if object == nil then
            return
        end
    
        -- if object.getPlayerName and object:getPlayerName() == nil then
        --     -- Only track humans
        --     return
        -- end
    
    
        if event.id == world.event.S_EVENT_TAKEOFF or event.id == world.event.S_EVENT_LAND then
            log(event.place:getName())
            local ordinance = object:getAmmo()
    
            -- Subtract on takeoff, add on land
            local sign = event.id == world.event.S_EVENT_TAKEOFF and -1 or 1

            log("Unit %s has taken off", object:getName())
    
            for i,weapon in ipairs(ordinance) do
                adjustDiff(weapon.desc.typeName, weapon.desc.displayName, (weapon.count * sign))
            end
            writeReport(true)
        end
    end


    internalConfig = buildConfig()

    missionCommands.addCommand("Show munitions status", nil, printMunitionStatus)

    mist.addEventHandler(eventHandler)

    trigger.action.outText("Weapon usage tracking enabled", 30)
end