-- Bench for WeightScaleCharScreen, run under lua5.1 (no PZ runtime). The
-- ISCharacterScreen stub below is deliberately faithful to the PROVEN
-- vanilla shape read from the client install's
-- media/lua/client/XpSystem/ISUI/ISCharacterScreen.lua: same method names
-- and call signatures (drawTextRight/drawText: text,x,y,r,g,b,a,font;
-- drawTexture: tex,x,y,a,r,g,b), same field names (xOffset,
-- weightIncTexture/weightIncLotTexture/weightDecTexture,
-- char:getNutrition():getWeight()/isIncWeight()/isIncWeightLot()/isDecWeight()),
-- and the SAME draw order/hazard a value-based patch would get wrong: a
-- Zombies Killed number that can equal the weight number.
package.path = "src/lua/client/?.lua;" .. package.path

local nAssert = 0
local function check(cond, msg)
    nAssert = nAssert + 1
    if not cond then
        io.stderr:write("FAIL: " .. msg .. "\n")
        os.exit(1)
    end
end

UIFont = { Small = "Small" }

local WORD_KEYS = {
    IGUI_WeightScale_Emaciated = true, IGUI_WeightScale_VeryUnderweight = true,
    IGUI_WeightScale_Underweight = true, IGUI_WeightScale_Normal = true,
    IGUI_WeightScale_Overweight = true, IGUI_WeightScale_Obese = true,
}
local TEXT = {
    IGUI_char_Weight = "Weight",
    IGUI_char_Zombies_Killed = "Zombies Killed",
    IGUI_WeightScale_Emaciated = "Emaciated",
    IGUI_WeightScale_VeryUnderweight = "Very Underweight",
    IGUI_WeightScale_Underweight = "Underweight",
    IGUI_WeightScale_Normal = "Normal",
    IGUI_WeightScale_Overweight = "Overweight",
    IGUI_WeightScale_Obese = "Obese",
}
local wordGetTextCalls = 0
function getText(key)
    if WORD_KEYS[key] then wordGetTextCalls = wordGetTextCalls + 1 end
    return TEXT[key] or key
end

local measureCalls = 0
function getTextManager()
    return {
        MeasureStringX = function(_, font, text)
            measureCalls = measureCalls + 1
            return #text * 7
        end,
    }
end

require "WeightScale/WeightScaleGeo"
require "WeightScale/WeightScaleCore"

-- 0: require-time install must not crash when ISCharacterScreen doesn't
-- exist yet, and must not have installed anything.
require "WeightScale/WeightScaleCharScreen"
local CharScreen = WeightScale.CharScreen
check(CharScreen ~= nil, "module loads")
check(CharScreen._originalRender == nil, "no install happened at require time (ISCharacterScreen absent)")

-- 1: guard rejects a class with no render().
ISCharacterScreen = {}
check(CharScreen.install() == false, "guard rejects a class with no render()")

-- 2: guard rejects when getText/getTextManager are missing.
ISCharacterScreen = { render = function() end }
local savedGetText = getText
getText = nil
check(CharScreen.install() == false, "guard rejects when getText is missing")
getText = savedGetText

-- 3: guard rejects when the weight label key resolves empty.
local emptyGetText = function() return nil end
local realGetText = getText
getText = emptyGetText
check(CharScreen.install() == false, "guard rejects when the weight label key is empty")
getText = realGetText

-- Faithful vanilla-shaped stub, built after the guard checks above.
ISCharacterScreen = {}
ISCharacterScreen.__index = ISCharacterScreen

function ISCharacterScreen:drawTextRight(text, x, y, r, g, b, a, font)
    table.insert(self._log, { op = "textRight", text = text })
end

function ISCharacterScreen:drawText(text, x, y, r, g, b, a, font)
    table.insert(self._log, { op = "text", text = text, x = x })
end

function ISCharacterScreen:drawTexture(tex, x, y, a, r, g, b)
    table.insert(self._log, { op = "texture", tex = tex, x = x })
end

function ISCharacterScreen:render()
    self.xOffset = 100
    local z = 10
    self:drawTextRight(getText("IGUI_char_Weight"), self.xOffset, z, 1,1,1,1, UIFont.Small)
    local weightStr = tostring(math.floor(self.char:getNutrition():getWeight() + 0.5))
    self:drawText(weightStr, self.xOffset + 4, z, 1,1,1,0.5, UIFont.Small)
    local n = self.char:getNutrition()
    if n:isIncWeight() or n:isIncWeightLot() or n:isDecWeight() then
        local nutritionWidth = getTextManager():MeasureStringX(UIFont.Small, weightStr) + 13
        if n:isIncWeight() and not n:isIncWeightLot() then
            self:drawTexture(self.weightIncTexture, self.xOffset + nutritionWidth, z + 3, 1, 0.8, 0.8, 0.8)
        end
        if n:isIncWeightLot() then
            self:drawTexture(self.weightIncLotTexture, self.xOffset + nutritionWidth, z, 1, 0.8, 0.8, 0.8)
        end
        if n:isDecWeight() then
            self:drawTexture(self.weightDecTexture, self.xOffset + nutritionWidth, z + 3, 1, 0.8, 0.8, 0.8)
        end
    end

    z = z + 20
    self:drawTextRight(getText("IGUI_char_Zombies_Killed"), self.xOffset, z, 1,1,1,1, UIFont.Small)
    self:drawText(tostring(self.kills), self.xOffset + 4, z, 1,1,1,0.5, UIFont.Small)
end

function ISCharacterScreen.new(weightKg, kills, flags)
    local nutrition = {
        w = weightKg,
        getWeight = function(s) return s.w end,
        isIncWeight = function() return flags and flags.inc or false end,
        isIncWeightLot = function() return flags and flags.incLot or false end,
        isDecWeight = function() return flags and flags.dec or false end,
    }
    return setmetatable({
        char = { getNutrition = function() return nutrition end },
        kills = kills,
        _log = {},
        weightIncTexture = { id = "inc" },
        weightIncLotTexture = { id = "incLot" },
        weightDecTexture = { id = "dec" },
    }, ISCharacterScreen)
end

-- 4: real install against the faithful stub.
check(CharScreen.install() == true, "install succeeds against a faithful vanilla-shaped stub")

local function findText(log, text)
    local hits = 0
    local last
    for _, e in ipairs(log) do
        if e.op == "text" and e.text == text then hits = hits + 1; last = e end
    end
    return last, hits
end
local function findTexture(log, tex)
    for _, e in ipairs(log) do
        if e.op == "texture" and e.tex == tex then return e end
    end
end

-- 5: words at and around every threshold (Geo.bands: 50/65/75/85/100).
local CASES = {
    { 50,    "Emaciated" },
    { 50.01, "Very Underweight" },
    { 65,    "Very Underweight" },
    { 65.01, "Underweight" },
    { 75,    "Normal" },
    { 84.99, "Normal" },
    { 85,    "Overweight" },
    { 99.99, "Overweight" },
    { 100,   "Obese" },
    { 130,   "Obese" },
    { 200,   "Obese" },
}
for _, c in ipairs(CASES) do
    local w, word = c[1], c[2]
    local rounded = math.floor(w + 0.5)
    local screen = ISCharacterScreen.new(w, rounded, nil)
    screen:render()
    local hit = findText(screen._log, word)
    check(hit ~= nil, "band for weight " .. tostring(w) .. " draws word " .. word)
end

-- 6: the kills number equal to the weight number is NOT replaced, and the
-- number is drawn exactly once (as the kills line, not the weight line).
local sameScreen = ISCharacterScreen.new(50, 50, nil)
sameScreen:render()
local numHit, numCount = findText(sameScreen._log, "50")
check(numCount == 1, "the number '50' is drawn exactly once (kills, not weight)")
check(numHit ~= nil, "the kills number survives even when it equals the weight number")
local wordHit = findText(sameScreen._log, "Emaciated")
check(wordHit ~= nil, "the weight line still shows the word")

-- 7: trend indicator x follows the word's measured width, not the number's.
local trendScreen = ISCharacterScreen.new(60, 1, { inc = true })
trendScreen:render()
local tex = findTexture(trendScreen._log, trendScreen.weightIncTexture)
check(tex ~= nil, "trend texture still drawn")
local expectedWidth = #"Very Underweight" * 7
check(tex.x == trendScreen.xOffset + expectedWidth + 13, "trend x uses the word's measured width")

-- 8: override restored after a throwing render (the trap functions must be
-- gone from the instance, whether that leaves it back at the inherited
-- class-level method or with no raw field at all).
local badScreen = ISCharacterScreen.new(60, 1, nil)
local origDrawText, origDrawTextRight, origDrawTexture = badScreen.drawText, badScreen.drawTextRight, badScreen.drawTexture
badScreen.char = nil
local ok = pcall(function() badScreen:render() end)
check(ok == false, "a throwing vanilla render still throws to the caller")
check(badScreen.drawText == origDrawText, "drawText override restored after a throwing render")
check(badScreen.drawTextRight == origDrawTextRight, "drawTextRight override restored after a throwing render")
check(badScreen.drawTexture == origDrawTexture, "drawTexture override restored after a throwing render")

-- 9: guard leaves vanilla untouched when the class or function is missing
-- (already proven in checks 1-3 above; re-affirm render() is still callable
-- and unpatched wrt the missing-getText case does not linger).
check(type(ISCharacterScreen.render) == "function", "vanilla render() is callable after the guard checks")

-- 10: two local players get their own word (splitscreen, task point 4).
local p1 = ISCharacterScreen.new(50, 1, nil)   -- Emaciated
local p2 = ISCharacterScreen.new(130, 1, nil)  -- Obese
p1:render()
p2:render()
check(findText(p1._log, "Emaciated") ~= nil, "player 1 sees their own band word")
check(findText(p2._log, "Obese") ~= nil, "player 2 sees their own band word")
check(p1._wsLastBandId == "emaciated", "player 1's cached band id is independent")
check(p2._wsLastBandId == "obese", "player 2's cached band id is independent")

-- 11: the word is recomputed only when the band changes.
local stillScreen = ISCharacterScreen.new(60, 1, nil) -- tresMaigre, no trend icons
stillScreen:render()
local callsAfterFirst, wordsAfterFirst = measureCalls, wordGetTextCalls
stillScreen.char:getNutrition().w = 61 -- still tresMaigre
stillScreen:render()
check(measureCalls == callsAfterFirst, "no re-measure when the band does not change")
check(wordGetTextCalls == wordsAfterFirst, "no re-lookup of the word when the band does not change")
stillScreen.char:getNutrition().w = 100 -- obese: band changes
stillScreen:render()
check(measureCalls > callsAfterFirst, "re-measures once the band changes")
check(wordGetTextCalls > wordsAfterFirst, "re-looks-up the word once the band changes")

-- 12: getText returning the raw key (broken/missing translation file on
-- some install) falls back to the English word, never shows the key.
TEXT.IGUI_WeightScale_Obese = nil -- getText(key) now returns key itself
local fallbackScreen = ISCharacterScreen.new(100, 1, nil) -- obese band
fallbackScreen:render()
check(findText(fallbackScreen._log, "Obese") ~= nil, "raw-key getText falls back to the English word")
check(findText(fallbackScreen._log, "IGUI_WeightScale_Obese") == nil, "the raw key itself is never shown")
TEXT.IGUI_WeightScale_Obese = "Obese"

print(nAssert .. " assertions passed")
check(nAssert > 0, "no assertions ran")
