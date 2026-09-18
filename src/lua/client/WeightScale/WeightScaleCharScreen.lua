-- Info tab (task 2026-09-18): the owner wants the vanilla "Weight 80" line to
-- show the weight CATEGORY in words instead of the number, so a player needs
-- a scale to know the number. ISCharacterScreen:render() (client install,
-- media/lua/client/XpSystem/ISUI/ISCharacterScreen.lua) is one long vanilla
-- function that draws many labelled numbers with the same font and colour
-- (Weight, Zombies Killed, Survived For...), so matching by string or by
-- value is wrong: a Zombies Killed count equal to the weight number must NOT
-- be swapped. Instead this shadows two of the PANEL'S OWN draw methods
-- (drawTextRight, drawText, drawTexture) for the duration of one render()
-- call only, and discriminates by ORDER: it watches for the exact vanilla
-- weight LABEL text, then swaps only the very next drawText call, which by
-- vanilla's own source order (proven above) is always the weight value and
-- nothing else. Wraps are restored via pcall even if render() throws.
require "WeightScale/WeightScaleCore"

WeightScale = WeightScale or {}
WeightScale.CharScreen = WeightScale.CharScreen or {}
local CharScreen = WeightScale.CharScreen

-- One vanilla trait-label key per band id, PROVEN in the client install's
-- media/lua/shared/Translate/EN/UI.json (docs/API-COMPAT.md "Info tab weight
-- words"): the game's own five weight-trait names, so every game language
-- gets a correct word for free through getText. "normal" has no fitting
-- vanilla weight-specific term (only unrelated "Normal" strings in other
-- domains: temperature, fish, chum...), so it uses this mod's own key.
CharScreen.WORD_KEY = {
    emaciated  = "UI_trait_emaciated",
    tresMaigre = "UI_trait_veryunderweight",
    maigre     = "UI_trait_underweight",
    normal     = "IGUI_WeightScale_Normal",
    surpoids   = "UI_trait_overweight",
    obese      = "UI_trait_obese",
}

-- Recomputes the word (and its measured width, for the trend arrow) only
-- when the band changes: zero per-frame allocation on the common case of a
-- player's weight sitting still inside one band while the tab stays open.
-- Cached on the screen instance itself so each local player's own Info tab
-- (splitscreen, task point 4) keeps its own word.
function CharScreen.wordFor(screenSelf, weightKg)
    local band = WeightScale.Core.bandOf(weightKg)
    if screenSelf._wsLastBandId ~= band.id then
        screenSelf._wsLastBandId = band.id
        local key = CharScreen.WORD_KEY[band.id] or CharScreen.WORD_KEY.normal
        local word = getText(key)
        screenSelf._wsLastWord = word
        screenSelf._wsLastWordWidth = getTextManager():MeasureStringX(UIFont.Small, word)
    end
    return screenSelf._wsLastWord
end

-- Trap functions are created ONCE at install time, not per render call: they
-- read/write only fields on `self` (the ISCharacterScreen instance), so no
-- closure is allocated per frame.
local function trapDrawTextRight(self, text, ...)
    if text == CharScreen._weightLabel then
        self._wsExpectWeight = true
    end
    return self._wsPrevDrawTextRight(self, text, ...)
end

local function trapDrawText(self, text, x, y, r, g, b, a, font)
    if self._wsExpectWeight then
        self._wsExpectWeight = false
        local nutrition = self.char and self.char.getNutrition and self.char:getNutrition()
        local w = nutrition and nutrition.getWeight and nutrition:getWeight()
        if type(w) == "number" then
            local word = CharScreen.wordFor(self, w)
            return self._wsPrevDrawText(self, word, x, y, r, g, b, a, font)
        end
        -- no char/nutrition: leave whatever vanilla was about to draw alone.
    end
    return self._wsPrevDrawText(self, text, x, y, r, g, b, a, font)
end

-- The trend arrow's x is vanilla-computed from the NUMBER's measured width
-- (a local inside render(), out of reach), which is too narrow for a longer
-- word: reposition it from our own cached word width instead (task point 3).
local function trapDrawTexture(self, tex, x, y, a, r, g, b)
    if tex == self.weightIncTexture or tex == self.weightIncLotTexture or tex == self.weightDecTexture then
        x = self.xOffset + (self._wsLastWordWidth or 0) + 13
    end
    return self._wsPrevDrawTexture(self, tex, x, y, a, r, g, b)
end

local function wrappedRender(self, ...)
    self._wsPrevDrawTextRight = self.drawTextRight
    self._wsPrevDrawText = self.drawText
    self._wsPrevDrawTexture = self.drawTexture
    self._wsExpectWeight = false
    self.drawTextRight = trapDrawTextRight
    self.drawText = trapDrawText
    self.drawTexture = trapDrawTexture

    local ok, err = pcall(CharScreen._originalRender, self, ...)

    self.drawTextRight = self._wsPrevDrawTextRight
    self.drawText = self._wsPrevDrawText
    self.drawTexture = self._wsPrevDrawTexture
    self._wsPrevDrawTextRight = nil
    self._wsPrevDrawText = nil
    self._wsPrevDrawTexture = nil

    if not ok then error(err, 0) end
end

-- Fail-safe install (task point 5): only patches what is proven to exist on
-- THIS client install. If ISCharacterScreen, its render(), getText/
-- getTextManager, or the weight label key are missing (another build, or
-- another mod replaced the screen), do nothing: vanilla stays untouched.
function CharScreen.install()
    if type(ISCharacterScreen) ~= "table" then return false end
    if type(ISCharacterScreen.render) ~= "function" then return false end
    if type(getText) ~= "function" or type(getTextManager) ~= "function" then return false end
    local weightLabel = getText("IGUI_char_Weight")
    if type(weightLabel) ~= "string" or weightLabel == "" then return false end

    CharScreen._weightLabel = weightLabel
    CharScreen._originalRender = ISCharacterScreen.render
    ISCharacterScreen.render = wrappedRender
    return true
end

CharScreen.install()
