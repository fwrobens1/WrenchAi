local function pickFont(names, fallback)
    for _, name in ipairs(names) do
        local ok, value = pcall(function()
            return Enum.Font[name]
        end)
        if ok and value then
            return value
        end
    end
    return fallback
end

return {
    bg = Color3.fromRGB(15, 15, 17),
    surface = Color3.fromRGB(22, 22, 25),
    surfaceAlt = Color3.fromRGB(29, 29, 33),
    surfaceHi = Color3.fromRGB(38, 38, 43),
    line = Color3.fromRGB(45, 45, 51),
    lineSoft = Color3.fromRGB(33, 33, 38),
    text = Color3.fromRGB(244, 244, 246),
    muted = Color3.fromRGB(154, 154, 163),
    faint = Color3.fromRGB(106, 106, 115),
    accent = Color3.fromRGB(100, 118, 250),
    accentDeep = Color3.fromRGB(78, 95, 236),
    accentSoft = Color3.fromRGB(27, 31, 62),
    user = Color3.fromRGB(46, 46, 52),
    ok = Color3.fromRGB(70, 211, 154),
    warn = Color3.fromRGB(245, 184, 75),
    err = Color3.fromRGB(255, 107, 107),
    errFill = Color3.fromRGB(41, 21, 24),
    code = Color3.fromRGB(10, 10, 12),
    white = Color3.fromRGB(255, 255, 255),
    font = pickFont({ "BuilderSans", "Gotham" }, Enum.Font.Gotham),
    fontMedium = pickFont({ "BuilderSansMedium", "GothamMedium" }, Enum.Font.Gotham),
    fontBold = pickFont({ "BuilderSansBold", "GothamBold" }, Enum.Font.GothamBold),
    fontCode = pickFont({ "RobotoMono", "Code" }, Enum.Font.Code),
    radiusWindow = 20,
    radiusCard = 14,
    radiusControl = 12,
}
