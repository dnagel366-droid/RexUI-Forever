-- ============================================================
-- RexUI_Config – Widgets.lua
-- Wiederverwendbare Elemente der Konfiguration
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI
or not RexUI.ConfigUI then
    return
end

local ConfigUI =
    RexUI.ConfigUI

local function T(text)
    return RexUI:LocalizeText(text)
end

local function AttachTooltip(frame, text)
    if not frame or not text or text == "" then
        return
    end

    frame.TooltipText = T(text)
end

local function ShowTooltip(frame)
    if not frame or not frame.TooltipText then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(frame.TooltipText)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- ------------------------------------------------------------
-- ÜBERSCHRIFT
-- ------------------------------------------------------------

function ConfigUI:CreateHeader(parent, text, x, y)

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", x or 20, y or -20)
    header:SetText(T(text or ""))
    header:SetTextColor(RexUI:GetColor("highlight"))

    return header
end

-- ------------------------------------------------------------
-- BESCHREIBUNG
-- ------------------------------------------------------------

function ConfigUI:CreateDescription(parent, text, x, y)

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", x or 20, y or -50)
    desc:SetWidth(540)
    desc:SetJustifyH("LEFT")
    desc:SetText(T(text or ""))
    desc:SetTextColor(RexUI:GetColor("mutedText"))

    return desc
end

-- ------------------------------------------------------------
-- TRENNLINIE
-- ------------------------------------------------------------

function ConfigUI:CreateDivider(parent, x, y, width)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", x or 20, y or -80)
    line:SetSize(width or 540, 1)
    line:SetColorTexture(RexUI:GetColor("border"))
    line:SetAlpha(0.45)

    return line
end

-- ------------------------------------------------------------
-- BUTTON
-- ------------------------------------------------------------

function ConfigUI:CreateButton(parent, text, x, y, width, height, callback, tooltip)

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 160, height or 30)
    button:SetPoint("TOPLEFT", x or 20, y or -100)

    button.Background = button:CreateTexture(nil, "BACKGROUND")
    button.Background:SetAllPoints(button)
    button.Background:SetColorTexture(
    0.20,
    0.05,
    0.28,
    1
)

    button.Border = button:CreateTexture(nil, "BORDER")
    button.Border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.Border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.Border:SetColorTexture(RexUI:GetColor("border"))
    button.Border:SetAlpha(0.35)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.Text:SetPoint("CENTER")
    button.Text:SetText(T(text or "Button"))
    button.Text:SetTextColor(RexUI:GetColor("text"))

    button:SetScript("OnEnter", function(self)
        self.Background:SetColorTexture(
    0.35,
    0.10,
    0.45,
    1
)
        self.Background:SetAlpha(0.18)
        self.Text:SetTextColor(RexUI:GetColor("highlight"))
        ShowTooltip(self)
    end)

    button:SetScript("OnLeave", function(self)
        self.Background:SetColorTexture(RexUI:GetColor("panel"))
        self.Background:SetAlpha(1)
        self.Text:SetTextColor(RexUI:GetColor("text"))
        HideTooltip()
    end)

    button:SetScript("OnClick", function()
        if callback then
            callback()
        end
    end)

    AttachTooltip(button, tooltip)

    return button
end

-- ------------------------------------------------------------
-- CHECKBOX
-- ------------------------------------------------------------

function ConfigUI:CreateCheckbox(parent, text, x, y, checked, callback, tooltip)

    local box = CreateFrame("Button", nil, parent)
    box:SetSize(48, 24)
    box:SetPoint("TOPLEFT", x or 20, y or -100)

    box.Background = box:CreateTexture(nil, "BACKGROUND")
    box.Background:SetAllPoints(box)
    box.Background:SetColorTexture(0.08, 0.03, 0.12, 0.95)

    box.Border = box:CreateTexture(nil, "BORDER")
    box.Border:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    box.Border:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    box.Border:SetColorTexture(0.45, 0.12, 0.65, 0.70)
    box.Border:SetAlpha(0.85)

    box.Checked = checked == true

    box.Knob = box:CreateTexture(nil, "ARTWORK")
    box.Knob:SetSize(16, 16)
    box.Knob:SetColorTexture(0.74, 0.66, 0.82, 1)

    box.StateText = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.StateText:SetPoint("CENTER", 0, 0)

    box.Label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.Label:SetPoint("LEFT", box, "RIGHT", 14, 0)
    box.Label:SetText(T(text or ""))
    box.Label:SetTextColor(RexUI:GetColor("text"))

    local function Refresh()
        box.Knob:ClearAllPoints()

        if box.Checked then
            box.Background:SetColorTexture(0.26, 0.07, 0.34, 0.95)
            box.Border:SetColorTexture(0.75, 0.20, 1.00, 0.90)
            box.Knob:SetPoint("RIGHT", box, "RIGHT", -5, 0)
            box.Knob:SetColorTexture(0.85, 0.25, 1.00, 1)
            box.StateText:SetText(T("AN"))
            box.StateText:SetTextColor(1, 1, 1, 0.85)
        else
            box.Background:SetColorTexture(0.08, 0.03, 0.12, 0.95)
            box.Border:SetColorTexture(0.45, 0.12, 0.65, 0.70)
            box.Knob:SetPoint("LEFT", box, "LEFT", 5, 0)
            box.Knob:SetColorTexture(0.52, 0.45, 0.58, 1)
            box.StateText:SetText("")
            box.StateText:SetTextColor(1, 1, 1, 0)
        end
    end

    Refresh()

    box:SetScript("OnEnter", function(self)
        self.Border:SetAlpha(1)
        self.Label:SetTextColor(RexUI:GetColor("highlight"))
        ShowTooltip(self)
    end)

    box:SetScript("OnLeave", function(self)
        self.Border:SetAlpha(0.85)
        self.Label:SetTextColor(RexUI:GetColor("text"))
        HideTooltip()
    end)

    box:SetScript("OnClick", function(self)

        self.Checked = not self.Checked
        Refresh()

        if callback then
            callback(self.Checked)
        end
    end)

    AttachTooltip(box, tooltip)

    return box
end
-- ------------------------------------------------------------
-- TOGGLE (alias for CreateCheckbox)
-- ------------------------------------------------------------

ConfigUI.CreateToggle = ConfigUI.CreateCheckbox

-- ------------------------------------------------------------
-- COLOR PICKER
-- ------------------------------------------------------------

function ConfigUI:CreateColorPicker(parent, text, x, y, color, callback, tooltip, showHex, allowOpacity)
    color = color or { r = 1, g = 1, b = 1, a = 1 }
    local baseLabel = T(text or "")

    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(42, 24)
    button:SetPoint("TOPLEFT", x or 20, y or -100)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.04, 0.02, 0.06, 1)
    button:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.85)

    button.Swatch = button:CreateTexture(nil, "ARTWORK")
    button.Swatch:SetPoint("TOPLEFT", 4, -4)
    button.Swatch:SetPoint("BOTTOMRIGHT", -4, 4)

    button.Label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.Label:SetPoint("LEFT", button, "RIGHT", 12, 0)
    button.Label:SetText(baseLabel)
    button.Label:SetTextColor(RexUI:GetColor("text"))

    if showHex then
        button.Label:ClearAllPoints()
        button.Label:SetPoint("TOPLEFT", button, "TOPRIGHT", 12, 1)
        button.HexLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.HexLabel:SetPoint("TOPLEFT", button, "TOPRIGHT", 12, -13)
        button.HexLabel:SetTextColor(0.62, 0.62, 0.62, 1)
    end

    local function Refresh()
        button.Swatch:SetColorTexture(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
        if showHex then
            local function Byte(value)
                value = math.max(0, math.min(1, tonumber(value) or 1))
                return math.floor(value * 255 + 0.5)
            end
            button.HexLabel:SetFormattedText("#%02X%02X%02X",
                Byte(color.r), Byte(color.g), Byte(color.b))
        end
    end

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.75, 0.20, 1.00, 1)
        self.Label:SetTextColor(RexUI:GetColor("highlight"))
        ShowTooltip(self)
    end)

    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.85)
        self.Label:SetTextColor(RexUI:GetColor("text"))
        HideTooltip()
    end)

    button:SetScript("OnClick", function()
        if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end

        ColorPickerFrame:SetFrameStrata("TOOLTIP")
        ColorPickerFrame:SetFrameLevel(1000)
        ColorPickerFrame:SetClampedToScreen(true)
        ColorPickerFrame:ClearAllPoints()
        ColorPickerFrame:SetPoint("CENTER", UIParent, "CENTER", 310, 0)

        local original = { r = color.r or 1, g = color.g or 1, b = color.b or 1, a = color.a or 1 }
        local settingUp = true

        local function ApplyColor()
            if settingUp then return end
            color.r, color.g, color.b = ColorPickerFrame:GetColorRGB()
            if allowOpacity and ColorPickerFrame.GetColorAlpha then
                color.a = ColorPickerFrame:GetColorAlpha()
            end
            Refresh()
            if callback then callback(color) end
        end

        local function RestoreColor()
            color.r, color.g, color.b, color.a = original.r, original.g, original.b, original.a
            Refresh()
            if callback then callback(color) end
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = original.r,
            g = original.g,
            b = original.b,
            opacity = original.a,
            hasOpacity = allowOpacity == true,
            swatchFunc = ApplyColor,
            opacityFunc = allowOpacity and ApplyColor or nil,
            cancelFunc = RestoreColor,
        })
        settingUp = false
    end)

    AttachTooltip(button, tooltip)
    Refresh()
    return button
end

-- ------------------------------------------------------------
-- DROPDOWN
-- ------------------------------------------------------------

function ConfigUI:CreateDropdown(parent, text, x, y, width, options, currentValue, callback, tooltip)

    local button = self:CreateButton(parent, text or "", x, y, width or 220, 30, nil, tooltip)
    button.Options = options or {}
    button.CurrentValue = currentValue

    local function GetLabel(value)
        for _, option in ipairs(button.Options) do
            if option.value == value then
                return T(option.label)
            end
        end

        return tostring(value or "-")
    end

    local function Refresh()
        if button.Text then
            button.Text:SetText(T(text or "") .. ": " .. GetLabel(button.CurrentValue))
        end
    end

    button:SetScript("OnClick", function(self)
        if #self.Options == 0 then return end

        local index = 1
        for optionIndex, option in ipairs(self.Options) do
            if option.value == self.CurrentValue then
                index = optionIndex
                break
            end
        end

        index = index + 1
        if index > #self.Options then
            index = 1
        end

        self.CurrentValue = self.Options[index].value
        Refresh()

        if callback then
            callback(self.CurrentValue)
        end
    end)

    Refresh()

    return button
end

-- ------------------------------------------------------------
-- ECHTES AUSWAHLMENÜ
-- ------------------------------------------------------------

function ConfigUI:CreateMenuDropdown(parent, text, x, y, width, options, currentValue, callback, tooltip)
    local button = self:CreateButton(parent, "", x, y, width or 260, 30, nil, tooltip)
    button.Options = options or {}
    button.CurrentValue = currentValue

    -- Schriftunabhaengiger Auswahlpfeil. Das fruehere Unicode-Zeichen
    -- erschien mit einigen WoW-Schriften nur als gelbes Quadrat.
    button.DropdownArrow = CreateFrame("Frame", nil, button)
    button.DropdownArrow:SetSize(14, 14)
    button.DropdownArrow:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.DropdownArrow:EnableMouse(false)

    local arrowLeft = button.DropdownArrow:CreateTexture(nil, "OVERLAY")
    arrowLeft:SetColorTexture(1, 0.82, 0, 1)
    arrowLeft:SetSize(7, 2)
    arrowLeft:SetPoint("CENTER", button.DropdownArrow, "CENTER", -2, 0)
    arrowLeft:SetRotation(math.rad(-45))

    local arrowRight = button.DropdownArrow:CreateTexture(nil, "OVERLAY")
    arrowRight:SetColorTexture(1, 0.82, 0, 1)
    arrowRight:SetSize(7, 2)
    arrowRight:SetPoint("CENTER", button.DropdownArrow, "CENTER", 2, 0)
    arrowRight:SetRotation(math.rad(45))

    button.Text:ClearAllPoints()
    button.Text:SetPoint("LEFT", button, "LEFT", 12, 0)
    button.Text:SetPoint("RIGHT", button.DropdownArrow, "LEFT", -6, 0)
    button.Text:SetJustifyH("CENTER")

    local function GetLabel(value)
        for _, option in ipairs(button.Options) do
            if option.value == value then return T(option.label) end
        end
        return tostring(value or "-")
    end

    local function Refresh()
        if button.Text then
            button.Text:SetText(T(text or "") .. ":  " .. GetLabel(button.CurrentValue))
        end
    end

    local function Select(value)
        button.CurrentValue = value
        Refresh()
        if callback then callback(value) end
    end

    button:SetScript("OnClick", function(self)
        if #self.Options == 0 then return end
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                rootDescription:CreateTitle(T(text or "Datentext auswählen"))
                for _, option in ipairs(self.Options) do
                    local value = option.value
                    local label = option.label
                    rootDescription:CreateRadio(
                        T(label),
                        function() return self.CurrentValue == value end,
                        function() Select(value) end
                    )
                end
            end)
        else
            local index = 1
            for optionIndex, option in ipairs(self.Options) do
                if option.value == self.CurrentValue then index = optionIndex break end
            end
            index = index % #self.Options + 1
            Select(self.Options[index].value)
        end
    end)

    button.RefreshSelection = Refresh
    Refresh()
    return button
end
-- ------------------------------------------------------------
-- SLIDER
-- ------------------------------------------------------------

function ConfigUI:CreateSlider(parent, text, x, y, minValue, maxValue, value, step, callback, tooltip)

    minValue = minValue or 0
    maxValue = maxValue or 100
    step = step or 1

    local function normalizeValue(rawValue)
        local finalValue =
            tonumber(rawValue)
            or minValue

        finalValue =
            math.max(
                minValue,
                math.min(maxValue, finalValue)
            )

        if step and step >= 1 then
            finalValue =
                math.floor(finalValue + 0.5)
        else
            finalValue =
                tonumber(
                    string.format("%.2f", finalValue)
                )
        end

        return finalValue
    end

    value =
        normalizeValue(value)

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", x or 20, y or -100)
    label:SetText(T(text or ""))
    label:SetTextColor(RexUI:GetColor("text"))

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x or 20, (y or -100) - 28)
    slider:SetWidth(220)

    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(value)

    local lastCallbackValue = value

    slider.Text:SetText("")
    slider.Low:SetText("")
    slider.High:SetText("")

    -- --------------------------------------------------------
    -- VALUE BOX
    -- --------------------------------------------------------

    local valueBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")

    valueBox:SetSize(55, 24)

    valueBox:SetPoint(
        "LEFT",
        slider,
        "RIGHT",
        18,
        0
    )

    valueBox:SetAutoFocus(false)

    valueBox:SetFontObject("GameFontNormal")

    valueBox:SetTextInsets(6, 6, 0, 0)

    valueBox:SetText(
        tostring(value)
    )

    valueBox:SetBackdrop({

        bgFile = "Interface\\Buttons\\WHITE8X8",

        edgeFile = "Interface\\Buttons\\WHITE8X8",

        edgeSize = 1,
    })

    valueBox:SetBackdropColor(
        0.08,
        0.02,
        0.12,
        1
    )

    valueBox:SetBackdropBorderColor(
        0.45,
        0.12,
        0.65,
        0.90
    )

    valueBox:SetTextColor(
        1,
        1,
        1,
        1
    )

    -- --------------------------------------------------------
    -- SLIDER UPDATE
    -- --------------------------------------------------------

    slider:SetScript("OnValueChanged", function(self, newValue)

        local finalValue =
            normalizeValue(newValue)

        if finalValue == lastCallbackValue then
            return
        end
        lastCallbackValue = finalValue

        valueBox:SetText(
            tostring(finalValue)
        )

        if callback then
            callback(finalValue)
        end
    end)

    -- --------------------------------------------------------
    -- EDITBOX UPDATE
    -- --------------------------------------------------------

    valueBox:SetScript("OnEnterPressed", function(self)

        local entered =
            tonumber(self:GetText())

        if not entered then
            return
        end

        slider:SetValue(
            normalizeValue(entered)
        )

        self:ClearFocus()
    end)

    valueBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(normalizeValue(slider:GetValue())))
        self:ClearFocus()
    end)

    slider:SetScript("OnEnter", function(self)
        ShowTooltip(self)
    end)

    slider:SetScript("OnLeave", function()
        HideTooltip()
    end)

    AttachTooltip(slider, tooltip)

    return slider
end
