--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny / brian / Mewtiny
	License: MIT License
]]

-- Setup to wrap our stuff in a table so we don't pollute the global environment
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}
_G.CleveRoids = CleveRoids


function CleveRoids.GetSpellCost(spellSlot, bookType)
    CleveRoids.Frame:SetOwner(WorldFrame, "ANCHOR_NONE")
    CleveRoids.Frame:SetSpell(spellSlot, bookType)
    local _, _, cost = string.find(CleveRoids.Frame.costFontString:GetText() or "", "^(%d+) [^ys]")
    local _, _, reagent = string.find(CleveRoids.Frame.reagentFontString:GetText() or "", "^Reagents: (.*)")
    if reagent and string.sub(reagent, 1, 2) == "|c" then
        reagent = string.sub(reagent, 11, -3)
    end

    return (cost and tonumber(cost) or 0), (reagent and tostring(reagent) or nil)
end

function CleveRoids.GetProxyActionSlot(slot)
    if not slot then return end
    return CleveRoids.actionSlots[slot] or CleveRoids.actionSlots[slot.."()"]
end

function CleveRoids.TestForActiveAction(actions)
    if not actions then return end

    local hasActive = false
    if actions.tooltip and table.getn(actions.list) == 0 then
        CleveRoids.TestAction(actions.cmd, actions.args)
        hasActive = true
        actions.active = actions.tooltip
    else
        for _, action in actions.list do
            -- break on first action that passes tests
            if CleveRoids.TestAction(action.cmd, action.args) then
                hasActive = true
                if action.sequence then
                    actions.sequence = action.sequence
                    actions.active = CleveRoids.GetCurrentSequenceAction(actions.sequence)
                else
                    actions.active = action
                end
                break
            end
        end
    end

    if not hasActive then
        actions.active = nil
        actions.sequence = nil
        return
    end

    if actions.active then
        if actions.active.spell then
            actions.active.inRange = 1

            -- nampower range check
            if IsSpellInRange then
                actions.active.inRange = IsSpellInRange(actions.active.action)
            end

            actions.active.oom = (UnitMana("player") < actions.active.spell.cost)

            if actions.active.isReactive then
                if not CleveRoids.IsReactiveUsable(actions.active.action) then
                    actions.active.oom = false
                    actions.active.usable = nil
                else
                    actions.active.usable = (pfUI and pfUI.bars) and nil or 1
                end
            elseif actions.active.inRange ~= 0 and not actions.active.oom then
                actions.active.usable = 1

            -- pfUI:actionbar.lua -- update usable [out-of-range = 1, oom = 2, not-usable = 3, default = 0]
            elseif pfUI and pfUI.bars and actions.active.oom then
                actions.active.usable = 2
            else
                actions.active.usable = nil
            end
        else
            actions.active.inRange = 1
            actions.active.usable = 1
        end
    end
end

function CleveRoids.TestForAllActiveActions()
    for slot, actions in CleveRoids.Actions do
        CleveRoids.TestForActiveAction(actions)
        CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
    end
end

function CleveRoids.ClearAction(slot)
    if not CleveRoids.Actions[slot] then return end
    CleveRoids.Actions[slot].active = nil
    CleveRoids.Actions[slot] = nil
end

function CleveRoids.GetAction(slot)
    if not slot or not CleveRoids.ready then return end

    local actions = CleveRoids.Actions[slot]
    if actions then return actions end

    local text = GetActionText(slot)

    if text then
        local macro = CleveRoids.GetMacro(text)
        if macro then
            actions = macro.actions

            CleveRoids.TestForActiveAction(actions)
            CleveRoids.Actions[slot] = actions
            CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
            return actions
        end
    end
end

function CleveRoids.GetActiveAction(slot)
    local action = CleveRoids.GetAction(slot)
    return action and action.active
end

function CleveRoids.SendEventForAction(slot, event, ...)
    local _this = this

    arg1, arg2, arg3, arg4, arg5, arg6, arg7 = unpack(arg)

    local page = floor((slot - 1) / NUM_ACTIONBAR_BUTTONS) + 1
    local pageSlot = slot - (page - 1) * NUM_ACTIONBAR_BUTTONS

    -- Classic support.

    if slot >= 73 then
        this = _G["BonusActionButton" .. pageSlot]
        if this then ActionButton_OnEvent(event) end
    else
        if slot >= 61 then
            this = _G["MultiBarBottomLeftButton" .. pageSlot]
        elseif slot >= 49 then
            this = _G["MultiBarBottomRightButton" .. pageSlot]
        elseif slot >= 37 then
            this = _G["MultiBarLeftButton" .. pageSlot]
        elseif slot >= 25 then
            this = _G["MultiBarRightButton" .. pageSlot]
        else
            this = nil
        end

        if this then ActionButton_OnEvent(event) end

        if page == CURRENT_ACTIONBAR_PAGE then
            this = _G["ActionButton" .. pageSlot]
            if this then ActionButton_OnEvent(event) end
        end
    end

    this = _this

    for _, fn in ipairs(CleveRoids.actionEventHandlers) do
        fn(slot, event, unpack(arg))
    end
end

-- Executes the given Macro's body
-- body: The Macro's body
function CleveRoids.ExecuteMacroBody(body,inline)
    local lines = CleveRoids.splitString(body, "\n")
    if inline then lines = CleveRoids.splitString(body, "\\n"); end

    for k,v in pairs(lines) do
        ChatFrameEditBox:SetText(v)
        ChatEdit_SendText(ChatFrameEditBox)
    end
    return true
end

-- Gets the body of the Macro with the given name
-- name: The name of the Macro
-- returns: The body of the macro
function CleveRoids.GetMacroBody(name)
    local macro = CleveRoids.GetMacro(name)
    return macro and macro.body
end

-- Attempts to execute a macro by the given name
-- name: The name of the macro
-- returns: Whether the macro was executed or not
function CleveRoids.ExecuteMacroByName(name)
    local body = CleveRoids.GetMacroBody(name)
    if not body then
        return false
    end

    CleveRoids.ExecuteMacroBody(body)
    return true
end

function CleveRoids.SetHelp(conditionals)
    if conditionals.harm then
        conditionals.help = false
    end
end

function CleveRoids.FixEmptyTarget(conditionals)
    if not conditionals.target then
        if UnitExists("target") then
            conditionals.target = "target"
        elseif GetCVar("autoSelfCast") == "1" then
            conditionals.target = "player"
        end
    end

    return false
end

-- Fixes the conditionals' target by targeting the target with the given name
-- conditionals: The conditionals containing the current target
-- name: The name of the player to target
-- hook: The target hook
-- returns: Whether or not we've changed the player's current target
function CleveRoids.FixEmptyTargetSetTarget(conditionals, name, hook)
    if not conditionals.target then
        hook(name)
        conditionals.target = "target"
        return true
    end
    return false
end

-- Returns the name of the focus target or nil
function CleveRoids.GetFocusName()
    if ClassicFocus_CurrentFocus then
        return ClassicFocus_CurrentFocus
    elseif CURR_FOCUS_TARGET then
        return CURR_FOCUS_TARGET
    end

    return nil
end

-- Attempts to target the focus target.
-- returns: Whether or not it succeeded
function CleveRoids.TryTargetFocus()
    local name = CleveRoids.GetFocusName()

    if not name then
        return false
    end

    CleveRoids.Hooks.TARGET_SlashCmd(name)
    return true
end

function CleveRoids.GetMacroNameFromAction(text)
    if string.sub(text, 1, 1) == "{" and string.sub(text, -1) == "}" then
        local name
        if string.sub(text, 2, 2) == "\"" and string.sub(text, -2, -2) == "\"" then
            return string.sub(text, 3, -3)
        else
            return string.sub(text, 2, -2)
        end
    end
end

function CleveRoids.CreateActionInfo(action, conditionals)
    local _, _, text = string.find(action, "!?%??~?(.*)")
    local spell = CleveRoids.GetSpell(text)
    local item, macroName, macro, macroTooltip, actionType, texture


    if not spell then
        item = CleveRoids.GetItem(text)
    end
    if not item then
        macroName = CleveRoids.GetMacroNameFromAction(text)
        macro = CleveRoids.GetMacro(macroName)
        macroTooltip = (macro and macro.actions) and macro.actions.tooltip
    end

    if spell then
        actionType = "spell"
        texture = spell.texture or CleveRoids.unknownTexture
    elseif item then
        actionType = "item"
        texture = (item and item.texture) or CleveRoids.unknownTexture
    elseif macro then
        actionType = "macro"
        texture = (macro.actions and macro.actions.tooltip and macro.actions.tooltip.texture)
                    or (macro and macro.texture)
                    or CleveRoids.unknownTexture
    end

    local info = {
        action = text,
        item = item,
        spell = spell,
        macro = macroTooltip,
        type = actionType,
        texture = texture,
        conditionals = conditionals,
    }

    return info
end

function CleveRoids.SplitCommandAndArgs(text)
    local _, _, cmd, args = string.find(text, "(/%w+%s?)(.*)")
    if cmd and args then
        cmd = CleveRoids.Trim(cmd)
        text = CleveRoids.Trim(args)
    end
    return cmd, args
end

function CleveRoids.ParseSequence(text)
    local args = string.gsub(text, "(%s*,%s*)", ",")
    local _, c, cond = string.find(args, "(%[.*%])")
    local _, r, reset, resetVal = string.find(args, "(%s*%]*%s*reset=([%w/]+)%s+)")

    actionSeq = CleveRoids.Trim((r and string.sub(args, r+1)) or (c and string.sub(args, c+1)) or args)
    args = (cond or "") .. actionSeq

    if not actionSeq then
        return
    end

    local sequence = {
        index = 1,
        reset = {},
        status = 0,
        list = {},
        lastUpdate = 0,
        cond = cond,
        args = args,
        cmd = "/castsequence",
        -- 技能队列相关字段
        queueWindow = 0.5,        -- 测试用 1秒 队列窗口
        canQueue = false,         -- 是否可以排队
        queueStartTime = 0,       -- 队列窗口开始时间
        nextQueued = false,       -- 下一个技能是否已排队
        queuedIndex = 0          -- 已排队的技能索引
    }
    if resetVal then
        for _, rule in ipairs(CleveRoids.Split(resetVal, "/")) do
            local secs = tonumber(rule)
            if secs and secs > 0 then
                sequence.reset.secs = secs
            else
                sequence.reset[string.lower(rule)] = true
            end
        end
    end

    for _, a in ipairs(CleveRoids.Split(actionSeq, ",")) do
        local sa = CleveRoids.CreateActionInfo(CleveRoids.GetParsedMsg(a))
        table.insert(sequence.list, sa)
    end
    CleveRoids.Sequences[text] = sequence

    return sequence
end

function CleveRoids.ParseMacro(name)
    if not name then return end

    local macroID = GetMacroIndexByName(name)
    if not macroID then return end

    local _, texture, body = GetMacroInfo(macroID)

    if not body and GetSuperMacroInfo then
        _, texture, body = GetSuperMacroInfo(name)
    end

    if not texture or not body then return end


    local macro = {
        id = macroId,
        name = name,
        texture = texture,
        body = body,
        actions = {},
    }
    macro.actions.list = {}

    -- build a list of testable actions for the macro
    for i, line in CleveRoids.splitString(body, "\n") do
        line = CleveRoids.Trim(line)
        local cmd, args = CleveRoids.SplitCommandAndArgs(line)

        -- check for #showtooltip
        if i == 1 then
            local _, _, st, _, tt = string.find(line, "(#showtooltip)(%s?(.*))")

            -- if no #showtooltip, nothing to keep track of
            if not st then
                break
            end
            tt = CleveRoids.Trim(tt)

            -- #showtooltip and item/spell/macro specified, only use this tooltip
            if st and tt ~= "" then
                macro.actions.tooltip = CleveRoids.CreateActionInfo(tt)
                macro.actions.cmd = cmd
                macro.actions.args = tt
                break
            end
        else
            -- make sure we have a testable action
            if line ~= "" and args ~= "" and CleveRoids.dynamicCmds[cmd] then
                for _, arg in CleveRoids.splitStringIgnoringQuotes(args) do
                    local action = CleveRoids.CreateActionInfo(CleveRoids.GetParsedMsg(arg))

                    if cmd == "/castsequence" then
                        local sequence = CleveRoids.GetSequence(args)
                        if sequence then
                            action.sequence = sequence
                        end
                    end

                    action.cmd = cmd
                    action.args = arg
                    action.isReactive = CleveRoids.reactiveSpells[action.action]
                    table.insert(macro.actions.list, action)
                end
            end
        end
    end

    CleveRoids.Macros[name] = macro
    return macro
end

function CleveRoids.ParseMsg(msg)
    if not msg then return end
    local conditionals = {}

    msg, conditionals.ignoretooltip = string.gsub(CleveRoids.Trim(msg), "^%?", "")
    local _, cbEnd, conditionBlock = string.find(msg, "%[(.+)%]")
    local _, _, noSpam, cancelAura, action = string.find(string.sub(msg, (cbEnd or 0) + 1), "^%s*(!?)(~?)([^!~]+.*)")
    action = CleveRoids.Trim(action or "")

    -- Store the action along with the conditionals incase it's needed
    conditionals.action = action
    action = string.gsub(action, "%(Rank %d+%)", "")

    if noSpam and noSpam ~= "" then
        local spamCond = CleveRoids.GetSpammableConditional(action)
        if spamCond then
            conditionals[spamCond] = { action }
        end
    end
    if cancelAura and cancelAura ~= "" then
        conditionals.cancelaura = action
    end

    if not conditionBlock then
        return conditionals.action, conditionals
    end

    -- Set the action's target to @unitid if found
    local _, _, target = string.find(conditionBlock, "(@[^%s,]+)")
    if target then
        conditionBlock = CleveRoids.Trim(string.gsub(conditionBlock, target, ""))
        conditionals.target = string.sub(target, 2)
    end

    if conditionBlock and action then
        -- Split the conditional block by comma or space
        for _, conditionGroups in CleveRoids.splitStringIgnoringQuotes(conditionBlock, {",", " "}) do
            if conditionGroups ~= "" then
                -- Split conditional groups by colon
                local conditionGroup = CleveRoids.splitStringIgnoringQuotes(conditionGroups, ":")
                local condition, args = conditionGroup[1], conditionGroup[2]

                -- No args, just set the conditional
                if not args or args == "" then
                    if conditionals[condition] and type(conditionals) ~= "table" then
                        conditionals[condition] = { conditionals[condition] }
                        table.insert(conditionals[condition], action)
                    else
                        conditionals[condition] = action
                    end
                else
                    if not conditionals[condition] then
                        conditionals[condition] = {}
                    end

                    -- Split the args by / for multiple values
                    for _, arg in CleveRoids.splitString(args, "/") do
                        -- Remove quotes around conditional args and replace any _ with spaces, put the = operator back in if shorthand was used
                        arg = string.gsub(arg, '"', "")
                        arg = string.gsub(arg, "_", " ")
                        arg = string.gsub(arg, "^#(%d+)$", "=#%1")
                        arg = string.gsub(arg, "([^>~=<]+)#(%d+)", "%1=#%2")

                        -- Get comparitive args
                        local _, _, name, operator, amount = string.find(arg, "([^>~=<]*)([>~=<]+)(#?%d+)")
                        if not operator or not amount then
                            table.insert(conditionals[condition], arg)
                        else
                            local amount, checkStacks = string.gsub(amount, "#", "")
                            table.insert(conditionals[condition], {
                                -- TODO: localize rank pattern?
                                name = (name and name ~= "") and name or action,
                                operator = operator,
                                amount = tonumber(amount),
                                checkStacks = (checkStacks == 1)
                            })
                        end
                    end
                end
            end
        end
        return conditionals.action, conditionals
    end
end

-- Get previously parsed or parse, store and return
function CleveRoids.GetParsedMsg(msg)
    if not msg then return end

    if CleveRoids.ParsedMsg[msg] then
        return CleveRoids.ParsedMsg[msg].action, CleveRoids.ParsedMsg[msg].conditionals
    end

    CleveRoids.ParsedMsg[msg] = {}
    CleveRoids.ParsedMsg[msg].action, CleveRoids.ParsedMsg[msg].conditionals = CleveRoids.ParseMsg(msg)

    return CleveRoids.ParsedMsg[msg].action, CleveRoids.ParsedMsg[msg].conditionals
end

function CleveRoids.GetMacro(name)
    return CleveRoids.Macros[name] or CleveRoids.ParseMacro(name)
end

function CleveRoids.GetSequence(args)
    return CleveRoids.Sequences[args] or CleveRoids.ParseSequence(args)
end

function CleveRoids.GetCurrentSequenceAction(sequence)
    return sequence.list[sequence.index]
end

function CleveRoids.ResetSequence(sequence)
    sequence.index = 1
    
    -- 重置队列相关状态
    sequence.canQueue = false
    sequence.nextQueued = false
    sequence.queueStartTime = 0
end

function CleveRoids.AdvanceSequence(sequence)
    local oldIndex = sequence.index
    if sequence.index < table.getn(sequence.list) then
        sequence.index = sequence.index + 1
        if CleveRoids.showSequenceInfo then
            CleveRoids.Print(string.format("|cFFFF66FFAdvanceSequence|r %d → %d (%d/%d)", 
                oldIndex, sequence.index, sequence.index, table.getn(sequence.list)))
        end
    else
        CleveRoids.ResetSequence(sequence)
        if CleveRoids.showSequenceInfo then
            CleveRoids.Print(string.format("|cFFFF66FFAdvanceSequence|r %d → 1 (重置循环)", oldIndex))
        end
        
        -- 序列循环重置时，触发动作条图标更新
        for slot, actions in CleveRoids.Actions do
            if actions.sequence == sequence then
                CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                break
            end
        end
    end
end

function CleveRoids.TestAction(cmd, args)
    local msg, conditionals = CleveRoids.GetParsedMsg(args)

    -- 调试输出：解析结果 (已屏蔽，太频繁)
    -- if CleveRoids.showSequenceInfo then
    --     CleveRoids.Print(string.format("|cFF888888TestAction|r cmd=%s, args=%s → msg=%s", 
    --         cmd or "nil", args or "nil", msg or "nil"))
    -- end

    if string.find(msg, "#showtooltip") or conditionals.ignoretooltip == 1 then
        -- if CleveRoids.showSequenceInfo then
        --     CleveRoids.Print("|cFF888888TestAction|r → 忽略 #showtooltip")
        -- end
        return
    end

    if not conditionals then
        if not msg then
            -- if CleveRoids.showSequenceInfo then
            --     CleveRoids.Print("|cFF888888TestAction|r → 无消息，返回nil")
            -- end
            return
        else
            -- action is a {macro} or item/spell
            local result = CleveRoids.GetMacroNameFromAction(msg) or msg
            -- if CleveRoids.showSequenceInfo then
            --     CleveRoids.Print(string.format("|cFF888888TestAction|r → 无条件，返回: %s", result))
            -- end
            return result
        end
    end

    local origTarget = conditionals.target
    if cmd == "" or not CleveRoids.dynamicCmds[cmd] then
        -- untestables
        -- if CleveRoids.showSequenceInfo then
        --     CleveRoids.Print(string.format("|cFF888888TestAction|r → 不可测试的命令: %s", cmd))
        -- end
        return
    end

    if conditionals.target == "mouseover" then
        if not UnitExists("mouseover") then
            conditionals.target = CleveRoids.mouseoverUnit
        end
        if not conditionals.target or (conditionals.target ~= "focus" and not UnitExists(conditionals.target)) then
            conditionals.target = origTarget
            -- if CleveRoids.showSequenceInfo then
            --     CleveRoids.Print("|cFF888888TestAction|r → mouseover 目标无效")
            -- end
            return false
        end
    end

    CleveRoids.FixEmptyTarget(conditionals)
    CleveRoids.SetHelp(conditionals)

    -- 调试输出：条件测试 (已屏蔽，太频繁)
    -- if CleveRoids.showSequenceInfo then
    --     local condStr = ""
    --     for k, v in pairs(conditionals) do
    --         if not CleveRoids.ignoreKeywords[k] then
    --             condStr = condStr .. k .. "=" .. tostring(v) .. " "
    --         end
    --     end
    --     CleveRoids.Print(string.format("|cFF888888TestAction|r → 测试条件: %s", condStr))
    -- end

    for k, v in pairs(conditionals) do
        if not CleveRoids.ignoreKeywords[k] then
            if not CleveRoids.Keywords[k] or not CleveRoids.Keywords[k](conditionals) then
                -- failed test
                conditionals.target = origTarget
                -- if CleveRoids.showSequenceInfo then
                --     CleveRoids.Print(string.format("|cFF888888TestAction|r → 条件失败: %s", k))
                -- end
                return
            end
        end
    end

    -- tests passed
    conditionals.target = origTarget
    local result = CleveRoids.GetMacroNameFromAction(msg) or msg
    -- if CleveRoids.showSequenceInfo then
    --     CleveRoids.Print(string.format("|cFF888888TestAction|r → 条件通过，返回: %s", result))
    -- end
    return result
end

-- Does the given action with a set of conditionals provided by the given msg
-- msg: The conditions followed by the action's parameters
-- hook: The hook of the function we've intercepted
-- fixEmptyTargetFunc: A function setting the player's target if the player has none. Required to return true if we need to re-target later or false if not
-- targetBeforeAction: A boolean value that determines whether or not we need to target the target given in the conditionals before performing the given action
-- action: A function that is being called when everything checks out
function CleveRoids.DoWithConditionals(msg, hook, fixEmptyTargetFunc, targetBeforeAction, action)
    local msg, conditionals = CleveRoids.GetParsedMsg(msg)

    -- No conditionals. Just exit.
    if not conditionals then
        if not msg then -- if not even an empty string
            return false
        else
            if string.sub(msg, 1, 1) == "{" and string.sub(msg, -1) == "}" then
                if string.sub(msg, 2, 2) == "\"" and string.sub(msg, -2, -2) == "\"" then
                    return CleveRoids.ExecuteMacroBody(string.sub(msg, 3, -3), true)
                else
                    return CleveRoids.ExecuteMacroByName(string.sub(msg, 2, -2))
                end
            end

            if hook then
                hook(msg)
            end
            return true
        end
    end

    if conditionals.cancelaura then
        if CleveRoids.CancelAura(conditionals.cancelaura) then
            return true
        end
    end

    local origTarget = conditionals.target
    if conditionals.target == "mouseover" then
        if not UnitExists("mouseover") then
            conditionals.target = CleveRoids.mouseoverUnit
        end
        if not conditionals.target or (conditionals.target ~= "focus" and not UnitExists(conditionals.target)) then
            conditionals.target = origTarget
            return false
        end
    end

    local needRetarget = false
    if fixEmptyTargetFunc then
        needRetarget = fixEmptyTargetFunc(conditionals, msg, hook)
    end

    CleveRoids.SetHelp(conditionals)

    if conditionals.target == "focus" then
        if UnitExists("target") and UnitName("target") == CleveRoids.GetFocusName() then
            conditionals.target = "target"
            needRetarget = false
        else
            if not CleveRoids.TryTargetFocus() then
                conditionals.target = origTarget
                return false
            end
            conditionals.target = "target"
            needRetarget = true
        end
    end

    for k, v in pairs(conditionals) do
        if not CleveRoids.ignoreKeywords[k] then
            if not CleveRoids.Keywords[k] or not CleveRoids.Keywords[k](conditionals) then
                if needRetarget then
                    TargetLastTarget()
                    needRetarget = false
                end
                conditionals.target = origTarget
                return false
            end
        end
    end

    if conditionals.target ~= nil and targetBeforeAction and not (CleveRoids.hasSuperwow and action == CastSpellByName) then
        if not UnitIsUnit("target", conditionals.target) then
            needRetarget = true
        end

        if SpellIsTargeting() then
            SpellStopCasting()
        end

        TargetUnit(conditionals.target)
    else
        if needRetarget then
            TargetLastTarget()
            needRetarget = false
        end
    end

    local result = true
    if string.sub(msg, 1, 1) == "{" and string.sub(msg, -1) == "}" then
        if string.sub(msg, 2, 2) == "\"" and string.sub(msg, -2,-2) == "\"" then
            result = CleveRoids.ExecuteMacroBody(string.sub(msg, 3, -3), true)
        else
            result = CleveRoids.ExecuteMacroByName(string.sub(msg, 2, -2))
        end
    else
        if CleveRoids.hasSuperwow and action == CastSpellByName and conditionals.target then
            CastSpellByName(msg, conditionals.target)
        else
            action(msg)
        end
    end

    if needRetarget then
        TargetLastTarget()
    end

    conditionals.target = origTarget
    return result
end

-- Attempts to cast a single spell from the given set of conditional spells
-- msg: The player's macro text
function CleveRoids.DoCast(msg)
    local handled = false

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        if CleveRoids.DoWithConditionals(v, CleveRoids.Hooks.CAST_SlashCmd, CleveRoids.FixEmptyTarget, not CleveRoids.hasSuperwow, CastSpellByName) then
            handled = true -- we parsed at least one command
            break
        end
    end
    return handled
end

-- Attempts to target a unit by its name using a set of conditionals
-- msg: The raw message intercepted from a /target command
function CleveRoids.DoTarget(msg)
    local handled = false

    local action = function(msg)
        if string.sub(msg, 1, 1) == "@" then
            local unit = string.sub(msg, 2)
            if CleveRoids.hasSuperwow then
                local _, guid = UnitExists(unit)
                if guid then TargetUnit(guid) end
            else
                CleveRoids.Hooks.TARGET_SlashCmd(UnitName(unit))
            end
        end
    end

    for k, v in CleveRoids.splitStringIgnoringQuotes(msg) do
        local _, cPos, anyCond = string.find(v, "(%[.*%])")
        local _, _, atTarget = string.find(v, "%s*@([^%s]+)%s*$", (cPos and cPos+1 or 1))
        if atTarget then handled = true end
        if atTarget and not anyCond then
            v = "[@"..atTarget.."] "..v
        end
        if CleveRoids.DoWithConditionals(v, CleveRoids.Hooks.TARGET_SlashCmd, CleveRoids.FixEmptyTargetSetTarget, false, action) then
            handled = true
            break
        end
    end
    return handled
end

-- Attempts to attack a unit by a set of conditionals
-- msg: The raw message intercepted from a /petattack command
function CleveRoids.DoPetAttack(msg)
    local handled = false

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        if CleveRoids.DoWithConditionals(v, PetAttack, CleveRoids.FixEmptyTarget, true, PetAttack) then
            handled = true
            break
        end
    end
    return handled
end

-- Attempts to use or equip an item from the player's inventory by a  set of conditionals
-- Also checks if a condition is a spell so that you can mix item and spell use
-- msg: The raw message intercepted from a /use or /equip command
function CleveRoids.DoUse(msg)
    local handled = false

    local action = function(msg)
        local item = CleveRoids.GetItem(msg)

        if item and item.inventoryID then
            return UseInventoryItem(item.inventoryID)
        elseif item and item.bagID then
            CleveRoids.GetNextBagSlotForUse(item, msg)
            return UseContainerItem(item.bagID, item.slot)
        end

        if (MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1) then return end
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        v = string.gsub(v, "^%?", "")
        local subject = v
        local _,e = string.find(v,"%]")
        if e then subject = CleveRoids.Trim(string.sub(v,e+1)) end

        if CleveRoids.GetSpell(subject) then
            handled = CleveRoids.DoWithConditionals(v, CleveRoids.Hooks.CAST_SlashCmd, CleveRoids.FixEmptyTarget, not CleveRoids.hasSuperwow, CastSpellByName)
        else
            -- TODO false needs checking here, for things like juju power we have an issue
            -- we need to target the spell but targeting before cast counts as a target change
            -- and this is potentially bad for things like the OH swing timer reset bug

            handled = CleveRoids.DoWithConditionals(v, action, CleveRoids.FixEmptyTarget, false, action)
        end
        if handled then break end
    end
    return handled
end

function CleveRoids.EquipBagItem(msg, offhand)
    local item = CleveRoids.GetItem(msg)

    if not item or (not item.bagID and not item.inventoryID) then
        return false
    end

    local invslot = offhand and 17 or 16
    if item.bagID then
        CleveRoids.GetNextBagSlotForUse(item, msg)
        PickupContainerItem(item.bagID, item.slot)
    else
        PickupInventoryItem(item.inventoryID)
    end

    EquipCursorItem(invslot)
    ClearCursor()

    return true
end

-- TODO: Refactor all these DoWithConditionals sections
function CleveRoids.DoEquipMainhand(msg)
    local handled = false

    local action = function(msg)
        return CleveRoids.EquipBagItem(msg, false)
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        v = string.gsub(v, "^%?", "")

        if CleveRoids.DoWithConditionals(v, action, CleveRoids.FixEmptyTarget, false, action) then
            handled = true
            break
        end
    end
    return handled
end

function CleveRoids.DoEquipOffhand(msg)
    local handled = false

    local action = function(msg)
        return CleveRoids.EquipBagItem(msg, true)
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        v = string.gsub(v, "^%?", "")

        if CleveRoids.DoWithConditionals(v, action, CleveRoids.FixEmptyTarget, false, action) then
            handled = true
            break
        end
    end
    return handled
end

function CleveRoids.DoUnshift(msg)
    local handled

    local action = function(msg)
        local currentShapeshiftIndex = CleveRoids.GetCurrentShapeshiftIndex()
        if currentShapeshiftIndex ~= 0 then
            CastShapeshiftForm(currentShapeshiftIndex)
        end
    end

    for k, v in pairs(CleveRoids.splitStringIgnoringQuotes(msg)) do
        handled = false
        if CleveRoids.DoWithConditionals(v, action, CleveRoids.FixEmptyTarget, false, action) then
            handled = true
            break
        end
    end

    if handled == nil then
        action()
    end

    return handled
end

function CleveRoids.DoRetarget()
    if GetUnitName("target") == nil
        or UnitHealth("target") == 0
        or not UnitCanAttack("player", "target")
    then
        ClearTarget()
        TargetNearestEnemy()
    end
end

function CleveRoids.DoCastSequence(sequence)
    if not CleveRoids.hasSuperwow then
        CleveRoids.Print("|cFFFF0000/castsequence|r requires |cFF00FFFFSuperWoW|r.")
        return
    end

    if CleveRoids.currentSequence and not CleveRoids.CheckSpellCast("player") then
        CleveRoids.currentSequence = nil
    elseif CleveRoids.currentSequence then
        -- 智能队列检查：如果是同一个序列且在队列窗口期内，允许排队
        if sequence == CleveRoids.currentSequence and CleveRoids.currentSequence.canQueue then
            -- 检查是否已经排队了下一个技能
            if not CleveRoids.currentSequence.nextQueued then
                -- 推进序列索引，标记为已排队
                CleveRoids.AdvanceSequence(CleveRoids.currentSequence)
                CleveRoids.currentSequence.nextQueued = true
                CleveRoids.currentSequence.queuedIndex = CleveRoids.currentSequence.index
                
                CleveRoids.LogWithTime(string.format("|cFF00FF00排队|r 下一个技能 (索引: %d/%d)", 
                    CleveRoids.currentSequence.index, table.getn(CleveRoids.currentSequence.list)))
                
                -- 触发动作条图标更新
                for slot, actions in CleveRoids.Actions do
                    if actions == sequence then
                        CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                        break
                    end
                end
                return
            else
                CleveRoids.LogWithTime("|cFFFFAA00已排队|r - 忽略重复按键")
                return
            end
        else
            CleveRoids.LogWithTime("|cFFFF0000阻止|r - 不在队列窗口期或序列不匹配")
            return
        end
    end

    if sequence.index > 1 then
        if sequence.reset then
            for k, _ in sequence.reset do
                if CleveRoids.kmods[k] and CleveRoids.kmods[k]() then
                    CleveRoids.ResetSequence(sequence)
                    
                    -- 触发动作条图标更新
                    for slot, actions in CleveRoids.Actions do
                        if actions.sequence == sequence then
                            CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                            break
                        end
                    end
                end
            end
        end
    end

    local active = CleveRoids.GetCurrentSequenceAction(sequence)
    if active and active.action then
        sequence.status = 0
        sequence.lastUpdate = GetTime()
        sequence.expires = 0

        CleveRoids.currentSequence = sequence

        local action = (sequence.cond or "") .. active.action
        local result = CleveRoids.DoWithConditionals(action, nil, nil, not CleveRoids.hasSuperwow, CastSpellByName)

        return result
    end
end

function CleveRoids.OnUpdate(self)
    -- make sure spells and items have been parsed
    if not CleveRoids.ready then return end


    local time = GetTime()
    -- Slow down a bit.
    if (time - CleveRoids.lastUpdate) < 0.1 then return end
    CleveRoids.lastUpdate = time

    if CleveRoids.CurrentSpell.autoAttackLock and (time - CleveRoids.autoAttackLockElapsed) > 0.2 then
        CleveRoids.CurrentSpell.autoAttackLock = false
        CleveRoids.CurrentSpell.autoAttackLockElapsed = nil
    end

    for _, sequence in pairs(CleveRoids.Sequences) do
        if sequence.index > 1 and sequence.reset.secs and (time - sequence.lastUpdate) >= sequence.reset.secs then
            if CleveRoids.showSequenceInfo then
                CleveRoids.Print(string.format("|cFFAA66FF超时重置|r 序列: %s (超时 %.1fs)", 
                    sequence.args, sequence.reset.secs))
            end
            CleveRoids.ResetSequence(sequence)
            
            -- 触发动作条图标更新，显示重置后的第一个技能
            for slot, actions in CleveRoids.Actions do
                if actions.sequence == sequence then
                    CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                    break
                end
            end
        end
        
        -- 检查队列窗口状态
        if sequence.queueStartTime > 0 and not sequence.canQueue and time >= sequence.queueStartTime then
            sequence.canQueue = true
            if CleveRoids.showSequenceInfo then
                CleveRoids.LogWithTime(string.format("|cFF00AAFF队列窗口开启|r - 可以排队下一个技能 (剩余 %.1fs)", 
                    sequence.queueWindow - (time - sequence.queueStartTime)))
            end
            
            -- 触发动作条图标更新，显示下一个技能
            for slot, actions in CleveRoids.Actions do
                if actions.sequence == sequence then
                    CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                    break
                end
            end
        end
        
        local oldActive = sequence.active
        sequence.active = CleveRoids.TestAction(sequence.cmd, sequence.args)
        
        -- 只在状态变化时输出，避免刷屏
        if CleveRoids.showSequenceInfo and oldActive ~= sequence.active then
            CleveRoids.Print(string.format("|cFFAA66FFOnUpdate|r 序列状态变化: %s → active=%s (索引 %d/%d)", 
                sequence.args, tostring(sequence.active), sequence.index, table.getn(sequence.list)))
        end
    end

    for guid,cast in CleveRoids.spell_tracking do
        if time > cast.expires then
            CleveRoids.spell_tracking[guid] = nil
        end
    end


    CleveRoids.IndexActionBars()
end

CleveRoids.Hooks.GameTooltip.SetAction = GameTooltip.SetAction
function GameTooltip.SetAction(self, slot)
    local actions = CleveRoids.GetAction(slot)

    if actions and (actions.active or actions.tooltip) then
        local tt = actions.active or actions.tooltip

        if tt.spell then
            GameTooltip:SetSpell(tt.spell.spellSlot, tt.spell.bookType)
            local rank = tt.spell.rank or tt.spell.highest.rank
            GameTooltipTextRight1:SetText("|cff808080" .. rank .."|r")
            GameTooltipTextRight1:Show()
            GameTooltip:Show()
        elseif tt.item then
            GameTooltip:SetHyperlink(tt.item.link)
            GameTooltip:Show()
        else

        end
    else
        CleveRoids.Hooks.GameTooltip.SetAction(self, slot)
    end
end

CleveRoids.Hooks.PickupAction = PickupAction
function PickupAction(slot)
    CleveRoids.ClearAction(slot)
    CleveRoids.ClearSlot(CleveRoids.actionSlots, slot)
    CleveRoids.ClearAction(CleveRoids.reactiveSlots, slot)
    return CleveRoids.Hooks.PickupAction(slot)
end

CleveRoids.Hooks.ActionHasRange = ActionHasRange
function ActionHasRange(slot)
    local actions = CleveRoids.GetAction(slot)
    if actions and actions.active then
        return (1 and actions.active.inRange ~= -1 or nil)
    else
        return CleveRoids.Hooks.ActionHasRange(slot)
    end
end

CleveRoids.Hooks.IsActionInRange = IsActionInRange
function IsActionInRange(slot, unit)
    local actions = CleveRoids.GetAction(slot)
    if actions and actions.active and actions.active.type == "spell" then
        return actions.active.inRange
    else
        return CleveRoids.Hooks.IsActionInRange(slot, unit)
    end
end

CleveRoids.Hooks.IsUsableAction = IsUsableAction
function IsUsableAction(slot, unit)
    local actions = CleveRoids.GetAction(slot)
    if actions and actions.active then
        return actions.active.usable, actions.active.oom
    else
        return CleveRoids.Hooks.IsUsableAction(slot, unit)
    end
end

CleveRoids.Hooks.IsCurrentAction = IsCurrentAction
function IsCurrentAction(slot)
    local active = CleveRoids.GetActiveAction(slot)

    if not active then
        return CleveRoids.Hooks.IsCurrentAction(slot)
    else
        local name
        if active.spell then
            local rank = active.spell.rank or active.spell.highest.rank
            name = active.spell.name..(rank and ("("..rank..")"))
        elseif active.item then
            name = active.item.name
        end

        return CleveRoids.Hooks.IsCurrentAction(CleveRoids.GetProxyActionSlot(name) or slot)
    end
end

CleveRoids.Hooks.GetActionTexture = GetActionTexture
function GetActionTexture(slot)
    local actions = CleveRoids.GetAction(slot)

    if actions and (actions.active or actions.tooltip) then
        -- 队列模式：如果是castsequence且在队列窗口期，显示下一个技能的图标
        if actions.sequence and actions.sequence.canQueue and not actions.sequence.nextQueued then
            local nextIndex = actions.sequence.index + 1
            if nextIndex <= table.getn(actions.sequence.list) then
                local nextAction = actions.sequence.list[nextIndex]
                if nextAction and nextAction.texture then
                    return nextAction.texture
                end
            else
                -- 序列即将重置，显示第一个技能
                local firstAction = actions.sequence.list[1]
                if firstAction and firstAction.texture then
                    return firstAction.texture
                end
            end
        end
        
        local proxySlot = (actions.active and actions.active.spell) and CleveRoids.GetProxyActionSlot(actions.active.spell.name)
        if proxySlot and CleveRoids.Hooks.GetActionTexture(proxySlot) ~= actions.active.spell.texture then
            return CleveRoids.Hooks.GetActionTexture(proxySlot)
        else
            return (actions.active and actions.active.texture) or (actions.tooltip and actions.tooltip.texture) or CleveRoids.unknownTexture
        end
    end
    return CleveRoids.Hooks.GetActionTexture(slot)
end

-- TODO: Look into https://github.com/Stanzilla/WoWUIBugs/issues/47 if needed
CleveRoids.Hooks.GetActionCooldown = GetActionCooldown
function GetActionCooldown(slot)
    local actions = CleveRoids.GetAction(slot)
    if actions and actions.active then
        local a = actions.active
        if a.spell then
            return GetSpellCooldown(a.spell.spellSlot, a.spell.bookType)
        elseif a.item then
            if a.item.bagID and a.item.slot then
                return GetContainerItemCooldown(a.item.bagID, a.item.slot)
            elseif a.item.inventoryID then
                return GetInventoryItemCooldown("player", a.item.inventoryID)
            end
        end
        return 0, 0, 0
    else
        return CleveRoids.Hooks.GetActionCooldown(slot)
    end
end

CleveRoids.Hooks.GetActionCount = GetActionCount
function GetActionCount(slot)
    local action = CleveRoids.GetAction(slot)
    local count
    if action and action.active then
        if action.active.item then
            count = action.active.item.count
        elseif action.active.spell and action.active.spell.reagent then
            local reagent = CleveRoids.GetItem(action.active.spell.reagent)
            count = reagent and reagent.count
        end
    end

    return count or CleveRoids.Hooks.GetActionCount(slot)
end

CleveRoids.Hooks.IsConsumableAction = IsConsumableAction
function IsConsumableAction(slot)
    local action = CleveRoids.GetAction(slot)
    if action and action.active then
        if action.active.item and
            (CleveRoids.countedItemTypes[action.active.item.type]
            or CleveRoids.countedItemTypes[action.active.item.name])
        then
            return 1
        elseif action.active.spell and action.active.spell.reagent then
            return 1
        else
            return
        end
    end

    return CleveRoids.Hooks.IsConsumableAction(slot)
end


-- Dummy Frame to hook ADDON_LOADED event in order to preserve compatiblity with other AddOns like SuperMacro
CleveRoids.Frame = CreateFrame("GameTooltip")

CleveRoids.Frame.costFontString = CleveRoids.Frame:CreateFontString()
CleveRoids.Frame.rangeFontString = CleveRoids.Frame:CreateFontString()
CleveRoids.Frame.reagentFontString = CleveRoids.Frame:CreateFontString()
CleveRoids.Frame:AddFontStrings(CleveRoids.Frame:CreateFontString(), CleveRoids.Frame:CreateFontString())
CleveRoids.Frame:AddFontStrings(CleveRoids.Frame.costFontString, CleveRoids.Frame.rangeFontString)
CleveRoids.Frame:AddFontStrings(CleveRoids.Frame:CreateFontString(), CleveRoids.Frame:CreateFontString())
CleveRoids.Frame:AddFontStrings(CleveRoids.Frame.reagentFontString, CleveRoids.Frame:CreateFontString())

CleveRoids.Frame:SetScript("OnUpdate", CleveRoids.OnUpdate)
CleveRoids.Frame:SetScript("OnEvent", function(...)
    CleveRoids.Frame[event](this,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10)
end)

CleveRoids.Frame:RegisterEvent("PLAYER_LOGIN")
CleveRoids.Frame:RegisterEvent("ADDON_LOADED")
CleveRoids.Frame:RegisterEvent("SPELLCAST_CHANNEL_START")
CleveRoids.Frame:RegisterEvent("SPELLCAST_CHANNEL_STOP")
-- CleveRoids.Frame:RegisterEvent("SPELLCAST_START")
-- CleveRoids.Frame:RegisterEvent("SPELLCAST_STOP")
-- CleveRoids.Frame:RegisterEvent("SPELLCAST_INTERRUPTED")
-- CleveRoids.Frame:RegisterEvent("SPELLCAST_FAILED")
CleveRoids.Frame:RegisterEvent("UNIT_CASTEVENT")
CleveRoids.Frame:RegisterEvent("PLAYER_ENTER_COMBAT")
CleveRoids.Frame:RegisterEvent("PLAYER_LEAVE_COMBAT")
-- CleveRoids.Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
CleveRoids.Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
CleveRoids.Frame:RegisterEvent("START_AUTOREPEAT_SPELL")
CleveRoids.Frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
-- CleveRoids.Frame:RegisterEvent("UI_ERROR_MESSAGE")
CleveRoids.Frame:RegisterEvent("UPDATE_MACROS")
CleveRoids.Frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
CleveRoids.Frame:RegisterEvent("SPELLS_CHANGED")
CleveRoids.Frame:RegisterEvent("BAG_UPDATE")
CleveRoids.Frame:RegisterEvent("UNIT_INVENTORY_CHANGED")

function CleveRoids.Frame:PLAYER_LOGIN()
    _, CleveRoids.playerClass = UnitClass("player")
    _, CleveRoids.playerGuid = UnitExists("player")
    CleveRoids.IndexSpells()
    CleveRoids.IndexItems()
    CleveRoids.IndexActionBars()
    CleveRoids.ready = true
    CleveRoids.showSequenceInfo = false  -- 默认关闭日志输出
    CleveRoids.sequenceLogStartTime = GetTime() -- 记录开始时间
    CleveRoids.Print("|cFF4477FFCleveR|r|cFFFFFFFFoid Macros|r |cFF00FF00Loaded|r - See the README.")
    CleveRoids.Print("castsequence 队列功能已启用，使用 |cFFFFFF00/seqshow on|r 开启调试日志")
end

function CleveRoids.Frame:ADDON_LOADED(addon)
    if addon ~= "CleveRoidMacros" then
        return
    end

    CleveRoids.InitializeExtensions()

    if SuperMacroFrame then
        local hooks = {
            cast = { action = CleveRoids.DoCast },
            target = { action = CleveRoids.DoTarget },
            use = { action = CleveRoids.DoUse },
            castsequence = { action = CleveRoids.DoCastSequence }
        }

        -- Hook SuperMacro's RunLine to stay compatible
        CleveRoids.Hooks.RunLine = RunLine
        CleveRoids.RunLine = function(...)
            for i = 1, arg.n do
                local intercepted = false
                local text = arg[i]

                for k,v in pairs(hooks) do
                    local begin, _end = string.find(text, "^/"..k.."%s+[!%[]")
                    if begin then
                        local msg = string.sub(text, _end)
                        v.action(msg)
                        intercepted = true
                        break
                    end
                end

                if not intercepted then
                    CleveRoids.Hooks.RunLine(text)
                end
            end
        end
        RunLine = CleveRoids.RunLine
    end
end

function CleveRoids.Frame:UNIT_CASTEVENT(caster,target,action,spell_id,cast_time)
    if action == "MAINHAND" or action == "OFFHAND" then return end

    -- handle cast spell tracking
    local cast = CleveRoids.spell_tracking[caster]
    if cast_time > 0 and action == "START" or action == "CHANNEL" then
        CleveRoids.spell_tracking[caster] = { spell_id = spell_id, expires = GetTime() + cast_time/1000, type = action }
    elseif cast
        and (
            (cast.spell_id == spell_id and (action == "FAIL" or action == "CAST"))
            or (GetTime() > cast.expires)
        )
    then
        CleveRoids.spell_tracking[caster] = nil
    end

    -- handle cast sequence
    if CleveRoids.currentSequence and caster == CleveRoids.playerGuid then
        local active = CleveRoids.GetCurrentSequenceAction(CleveRoids.currentSequence)

        local name, rank = SpellInfo(spell_id)
        local isSeqSpell = (active.action == name or active.action == (name.."("..rank..")"))
        
        
        -- 对于 FAIL/INTERRUPTED，即使技能名不匹配也要处理，因为可能是当前序列的技能
        local shouldHandle = isSeqSpell or (action == "FAIL" or action == "INTERRUPTED")
        
        if shouldHandle then
            local status = CleveRoids.currentSequence.status
            local currentTime = GetTime()
            
            if status == 0 and (action == "START" or action == "CHANNEL") and cast_time > 0 then
                CleveRoids.currentSequence.status = 1
                CleveRoids.currentSequence.expires = currentTime + cast_time/1000
                
                -- 计算队列窗口：在技能即将完成前开始队列窗口
                CleveRoids.currentSequence.queueStartTime = currentTime + (cast_time/1000) - CleveRoids.currentSequence.queueWindow
                CleveRoids.currentSequence.canQueue = false  -- 初始不能排队
                CleveRoids.currentSequence.nextQueued = false  -- 重置排队状态
                
                CleveRoids.LogWithTime(string.format("|cFF66CCFF开始施法|r %s - 持续 %.1fs, 队列窗口将在 %.1fs 后开启", 
                    name, cast_time/1000, (cast_time/1000) - CleveRoids.currentSequence.queueWindow))
                    
            elseif (status == 0 and action == "CAST" and cast_time == 0)
                or (status == 1 and action == "CAST" and CleveRoids.currentSequence.expires)
            then
                CleveRoids.currentSequence.status = 2
                CleveRoids.currentSequence.lastUpdate = currentTime
                
                -- 如果技能已排队，检查是否是预期的技能
                if CleveRoids.currentSequence.nextQueued then
                    CleveRoids.LogWithTime(string.format("|cFF00FF00技能完成|r %s - 已排队的下一个技能生效", name))
                    -- 重置排队状态，为下一轮准备
                    CleveRoids.currentSequence.nextQueued = false
                    CleveRoids.currentSequence.canQueue = false
                    CleveRoids.currentSequence.queueStartTime = 0
                else
                    CleveRoids.LogWithTime(string.format("|cFF00CCAA技能完成|r %s - 推进序列", name))
                    CleveRoids.AdvanceSequence(CleveRoids.currentSequence)
                end
                
                CleveRoids.currentSequence = nil
                
            elseif action == "INTERRUPTED" or action == "FAIL" then
                -- 技能被打断或失败，重置整个序列
                CleveRoids.LogWithTime(string.format("|cFFFF3333技能%s|r %s - 重置序列", 
                    action == "INTERRUPTED" and "被打断" or "失败", name or "unknown"))
                
                CleveRoids.ResetSequence(CleveRoids.currentSequence)
                CleveRoids.currentSequence = nil
                
                -- 触发动作条图标更新
                for slot, actions in CleveRoids.Actions do
                    if actions.sequence then
                        CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                    end
                end
            end
        end
    end
end

function CleveRoids.Frame:SPELLCAST_CHANNEL_START()
    CleveRoids.CurrentSpell.type = "channeled"
end

function CleveRoids.Frame:SPELLCAST_CHANNEL_STOP()
    CleveRoids.CurrentSpell.type = ""
    CleveRoids.CurrentSpell.spellName = ""
end

function CleveRoids.Frame:PLAYER_ENTER_COMBAT()
    CleveRoids.CurrentSpell.autoAttack = true
    CleveRoids.CurrentSpell.autoAttackLock = false
end

function CleveRoids.Frame:PLAYER_LEAVE_COMBAT()
    CleveRoids.CurrentSpell.autoAttack = false
    CleveRoids.CurrentSpell.autoAttackLock = false
    for _, sequence in pairs(CleveRoids.Sequences) do
        if CleveRoids.currentSequence ~= sequence and sequence.index > 1 and sequence.reset.combat then
            CleveRoids.ResetSequence(sequence)
            
            -- 触发动作条图标更新
            for slot, actions in CleveRoids.Actions do
                if actions.sequence == sequence then
                    CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                    break
                end
            end
        end
    end
end

-- just a secondary check, shouldn't matter much
function CleveRoids.Frame:PLAYER_TARGET_CHANGED()
    CleveRoids.CurrentSpell.autoAttack = false
    CleveRoids.CurrentSpell.autoAttackLock = false

    for _, sequence in pairs(CleveRoids.Sequences) do
        if CleveRoids.currentSequence ~= sequence and sequence.index > 1 and sequence.reset.target then
            CleveRoids.ResetSequence(sequence)
            
            -- 触发动作条图标更新
            for slot, actions in CleveRoids.Actions do
                if actions.sequence == sequence then
                    CleveRoids.SendEventForAction(slot, "ACTIONBAR_SLOT_CHANGED", slot)
                    break
                end
            end
        end
    end
end

function CleveRoids.Frame:UPDATE_MACROS()
    CleveRoids.currentSequence = nil
    CleveRoids.ParsedMsg = {}
    CleveRoids.Macros = {}
    CleveRoids.Actions = {}
    CleveRoids.Sequences = {}
    CleveRoids.IndexSpells()
    CleveRoids.IndexTalents()
    CleveRoids.IndexActionBars()
end

function CleveRoids.Frame:SPELLS_CHANGED()
    CleveRoids.Frame:UPDATE_MACROS()
end

function CleveRoids.Frame:ACTIONBAR_SLOT_CHANGED()
    CleveRoids.ClearAction(arg1)
    CleveRoids.IndexActionSlot(arg1)
end

function CleveRoids.Frame:BAG_UPDATE()
    CleveRoids.IndexItems()
end

function CleveRoids.Frame:UNIT_INVENTORY_CHANGED()
    if arg1 ~= "player" then
        return
    end
    CleveRoids.IndexItems()
end

-- just a secondary check
-- function CleveRoids.Frame:PLAYER_REGEN_ENABLED()
--     CleveRoids.CurrentSpell.autoAttack = false
-- end

function CleveRoids.Frame:START_AUTOREPEAT_SPELL()
    local _, className = UnitClass("player")
    if className == "HUNTER" then
        CleveRoids.CurrentSpell.autoShot = true
    else
        CleveRoids.CurrentSpell.wand = true
    end
end

function CleveRoids.Frame:STOP_AUTOREPEAT_SPELL()
    local _, className = UnitClass("player")
    if className == "HUNTER" then
        CleveRoids.CurrentSpell.autoShot = false
    else
        CleveRoids.CurrentSpell.wand = false
    end
end


CleveRoids.Hooks.SendChatMessage = SendChatMessage
function SendChatMessage(msg, ...)
    if msg and string.find(msg, "^#showtooltip") then
        return
    end
    CleveRoids.Hooks.SendChatMessage(msg, unpack(arg))
end

CleveRoids.RegisterActionEventHandler = function(fn)
    if type(fn) == "function" then
        table.insert(CleveRoids.actionEventHandlers, fn)
    end
end

CleveRoids.RegisterMouseOverResolver = function(fn)
    if type(fn) == "function" then
        table.insert(CleveRoids.mouseOverResolvers, fn)
    end
end


-- Bandaid so pfUI doesn't need to be edited
-- pfUI/modules/thirdparty-vanilla.lua:914
CleverMacro = true