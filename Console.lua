--[[
	Author: Dennis Werner Garske (DWG) / brian / Mewtiny
	License: MIT License
]]
local _G = _G or getfenv(0)
local CleveRoids = _G.CleveRoids or {}

SLASH_PETATTACK1 = "/petattack"

SlashCmdList.PETATTACK = function(msg) CleveRoids.DoPetAttack(msg); end

SLASH_RELOAD1 = "/rl"

SlashCmdList.RELOAD = function() ReloadUI(); end

SLASH_USE1 = "/use"

SlashCmdList.USE = CleveRoids.DoUse

SLASH_EQUIP1 = "/equip"

SlashCmdList.EQUIP = CleveRoids.DoUse
-- take back supermacro and pfUI /equip
SlashCmdList.SMEQUIP = CleveRoids.DoUse
SlashCmdList.PFEQUIP = CleveRoids.DoUse

SLASH_EQUIPMH1 = "/equipmh"
SlashCmdList.EQUIPMH = CleveRoids.DoEquipMainhand

SLASH_EQUIPOH1 = "/equipoh"
SlashCmdList.EQUIPOH = CleveRoids.DoEquipOffhand

SLASH_UNSHIFT1 = "/unshift"

SlashCmdList.UNSHIFT = CleveRoids.DoUnshift

-- TODO make this conditional too
SLASH_CANCELAURA1 = "/cancelaura"
SLASH_CANCELAURA2 = "/unbuff"

SlashCmdList.CANCELAURA = CleveRoids.CancelAura

SLASH_STARTATTACK1 = "/startattack"

SlashCmdList.STARTATTACK = function(msg)
    if not UnitExists("target") or UnitIsDead("target") then TargetNearestEnemy() end

    if not CleveRoids.CurrentSpell.autoAttack and not CleveRoids.CurrentSpell.autoAttackLock and UnitExists("target") and UnitCanAttack("player","target") then
        CleveRoids.CurrentSpell.autoAttackLock = true

        -- time a reset in case an attack could not be started.
        -- handled in CleveRoids.OnUpdate()
        CleveRoids.autoAttackLockElapsed = GetTime()
        AttackTarget()
    end
end

SLASH_STOPATTACK1 = "/stopattack"

SlashCmdList.STOPATTACK = function(msg)
    if CleveRoids.CurrentSpell.autoAttack and UnitExists("target") then
        AttackTarget()
        CleveRoids.CurrentSpell.autoAttack = false
    end
end

SLASH_STOPCASTING1 = "/stopcasting"

SlashCmdList.STOPCASTING = SpellStopCasting

CleveRoids.Hooks.CAST_SlashCmd = SlashCmdList.CAST
CleveRoids.CAST_SlashCmd = function(msg)
    -- get in there first, i.e do a PreHook
    if CleveRoids.DoCast(msg) then
        return
    end
    -- if there was nothing for us to handle pass it to the original
    CleveRoids.Hooks.CAST_SlashCmd(msg)
end

SlashCmdList.CAST = CleveRoids.CAST_SlashCmd

CleveRoids.Hooks.TARGET_SlashCmd = SlashCmdList.TARGET
CleveRoids.TARGET_SlashCmd = function(msg)
    msg = CleveRoids.Trim(msg)
    if CleveRoids.DoTarget(msg) then
        return
    end
    CleveRoids.Hooks.TARGET_SlashCmd(msg)
end
SlashCmdList.TARGET = CleveRoids.TARGET_SlashCmd


SLASH_CASTSEQUENCE1 = "/castsequence"
SlashCmdList.CASTSEQUENCE = function(msg)
    msg = CleveRoids.Trim(msg)
    local sequence = CleveRoids.GetSequence(msg)
    if not sequence then return end
    if not sequence.active then return end

    -- 记录操作日志
    local currentSpellStatus = CleveRoids.CheckSpellCast("player") and "施法中" or "空闲"
    CleveRoids.LogWithTime(string.format("|cFF66CCFF按键|r /castsequence - 当前状态: %s, 序列索引: %d/%d", 
        currentSpellStatus, sequence.index, table.getn(sequence.list)))

    CleveRoids.DoCastSequence(sequence)
end


SLASH_RUNMACRO1 = "/runmacro"
SlashCmdList.RUNMACRO = function(msg)
    return CleveRoids.ExecuteMacroByName(CleveRoids.Trim(msg))
end

SLASH_RETARGET1 = "/retarget"
SlashCmdList.RETARGET = function(msg)
    CleveRoids.DoRetarget()
end

SLASH_SEQDEBUG1 = "/seqdebug"
SlashCmdList.SEQDEBUG = function(msg)
    if CleveRoids.currentSequence then
        local seq = CleveRoids.currentSequence
        CleveRoids.Print(string.format("序列状态 - 索引: %d/%d, 状态: %d", 
            seq.index, table.getn(seq.list), seq.status))
    else
        CleveRoids.Print("当前没有活动的 castsequence")
    end
end

SLASH_SEQSHOW1 = "/seqshow"
SlashCmdList.SEQSHOW = function(msg)
    if msg == "on" or msg == "1" then
        CleveRoids.showSequenceInfo = true
        CleveRoids.sequenceLogStartTime = GetTime() -- 记录开始时间
        CleveRoids.Print("|cFF00FF00开启|r castsequence 调试日志")
    elseif msg == "off" or msg == "0" then
        CleveRoids.showSequenceInfo = false
        CleveRoids.Print("|cFFFF0000关闭|r castsequence 调试日志")
    else
        CleveRoids.showSequenceInfo = not CleveRoids.showSequenceInfo
        if CleveRoids.showSequenceInfo then
            CleveRoids.sequenceLogStartTime = GetTime() -- 记录开始时间
        end
        CleveRoids.Print(string.format("castsequence 调试日志: %s", 
            CleveRoids.showSequenceInfo and "|cFF00FF00开启|r" or "|cFFFF0000关闭|r"))
    end
end

SLASH_SEQQUEUE1 = "/seqqueue"
SlashCmdList.SEQQUEUE = function(msg)
    if CleveRoids.currentSequence then
        local seq = CleveRoids.currentSequence
        local currentTime = GetTime()
        CleveRoids.Print(string.format("|cFF66CCFF队列状态|r"))
        CleveRoids.Print(string.format("  索引: %d/%d", seq.index, table.getn(seq.list)))
        CleveRoids.Print(string.format("  状态: %d", seq.status))
        CleveRoids.Print(string.format("  队列窗口: %.1fs", seq.queueWindow))
        CleveRoids.Print(string.format("  可排队: %s", seq.canQueue and "|cFF00FF00是|r" or "|cFFFF0000否|r"))
        CleveRoids.Print(string.format("  已排队: %s", seq.nextQueued and "|cFF00FF00是|r" or "|cFFFF0000否|r"))
        if seq.queueStartTime > 0 then
            local timeToQueue = seq.queueStartTime - currentTime
            if timeToQueue > 0 then
                CleveRoids.Print(string.format("  队列开启倒计时: %.1fs", timeToQueue))
            else
                CleveRoids.Print(string.format("  队列已开启: %.1fs", -timeToQueue))
            end
        else
            CleveRoids.Print("  队列窗口: 未激活")
        end
    else
        CleveRoids.Print("当前没有活动的 castsequence")
    end
end

SLASH_SEQTEST1 = "/seqtest"
SlashCmdList.SEQTEST = function(msg)
    CleveRoids.Print("|cFFFFAA00测试队列功能|r")
    CleveRoids.Print("使用宏: |cFFAAFFAA#showtooltip")
    CleveRoids.Print("/castsequence reset=6/target 火球术, 奥术溃裂|r")
    CleveRoids.Print("测试步骤:")
    CleveRoids.Print("1. 开始施法火球术")
    CleveRoids.Print("2. 在施法快结束时再次按下宏按钮")
    CleveRoids.Print("3. 观察是否能排队奥术溃裂")
    CleveRoids.Print("4. 检查动作条图标是否更新")
    CleveRoids.Print("使用 |cFFAAFFAA/seqqueue|r 查看队列状态")
end

-- 添加带时间戳的日志函数
function CleveRoids.LogWithTime(msg)
    if not CleveRoids.showSequenceInfo then return end
    local relativeTime = CleveRoids.sequenceLogStartTime and (GetTime() - CleveRoids.sequenceLogStartTime) or GetTime()
    CleveRoids.Print(string.format("|cFFCCCCCC[+%.1fs]|r %s", relativeTime, msg))
end
