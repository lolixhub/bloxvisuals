local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

if getgenv and getgenv().BloxVisualsCleanup then
    pcall(getgenv().BloxVisualsCleanup)
end

local connections = {}
local created     = {}
local function track(obj) table.insert(created, obj) return obj end
local function connect(sig, fn) local c = sig:Connect(fn) table.insert(connections, c) return c end

local State = {
    preset       = nil,
    aura         = nil,
    auraRainbow  = true,
    auraSize     = 1,
    sky          = nil,
    skyboxId     = nil,
    skySpin      = 0,
    clockLock    = false,
    clock        = 14,
    sparkDensity = 2,
    streakRainbow = false,
    trail        = false,
    outline      = false,
    snow         = false,
    hud          = true,
    notify       = true,
    menuBlur     = true,
    rainbowSpeed = 0.15,
    linkDist     = 16,
    starDensity  = 2,
    starRainbow  = false,
    accRainbow   = true,
    wingSize     = 1,
    theme        = "Mono",
}

local Original = {
    ClockTime              = Lighting.ClockTime,
    Brightness             = Lighting.Brightness,
    Ambient                = Lighting.Ambient,
    OutdoorAmbient         = Lighting.OutdoorAmbient,
    ColorShift_Top         = Lighting.ColorShift_Top,
    FogEnd                 = Lighting.FogEnd,
    FogColor               = Lighting.FogColor,
    ExposureCompensation   = Lighting.ExposureCompensation,
    FieldOfView            = Camera.FieldOfView,
}

local function hue() return (tick() * State.rainbowSpeed) % 1 end
local function rainbow(offset) return Color3.fromHSV((hue() + (offset or 0)) % 1, 0.85, 1) end

-- Accent colors live in Theme (defined with the UI); auras can follow them instead of the rainbow
local AuraTint = { a = Color3.fromRGB(240, 240, 245), b = Color3.fromRGB(170, 172, 185) }
local function auraColor(offset)
    if State.auraRainbow then return rainbow(offset) end
    local k = (math.sin((tick() * State.rainbowSpeed * 6) + (offset or 0) * 12) + 1) / 2
    return AuraTint.a:Lerp(AuraTint.b, k)
end

-- Accessories (and Nova Step): one colour for the whole piece that shifts over time, never white.
-- With "Rainbow Accessories" off it follows the theme; the grey Mono theme falls back to purple → pink.
local ACC_FALLBACK = { a = Color3.fromRGB(150, 100, 255), b = Color3.fromRGB(255, 95, 200) }
local function accColor()
    if State.accRainbow then return Color3.fromHSV(hue(), 0.9, 1) end
    local t = AuraTint
    local _, sa = t.a:ToHSV()
    local _, sb = t.b:ToHSV()
    if sa < 0.25 and sb < 0.25 then t = ACC_FALLBACK end
    local k = (math.sin(tick() * State.rainbowSpeed * 6) + 1) / 2
    return t.a:Lerp(t.b, k)
end
local function shade(c, d) return Color3.new(c.R * d, c.G * d, c.B * d) end

local CC =track(Instance.new("ColorCorrectionEffect"))
CC.Name = "BV_ColorCorrection"; CC.Enabled = false; CC.Parent = Lighting

local Bloom = track(Instance.new("BloomEffect"))
Bloom.Name = "BV_Bloom"; Bloom.Intensity = 1.2; Bloom.Size = 36; Bloom.Threshold = 0.9
Bloom.Enabled = false; Bloom.Parent = Lighting

local Rays = track(Instance.new("SunRaysEffect"))
Rays.Name = "BV_SunRays"; Rays.Intensity = 0.12; Rays.Spread = 0.8
Rays.Enabled = false; Rays.Parent = Lighting

local DoF = track(Instance.new("DepthOfFieldEffect"))
DoF.Name = "BV_DoF"; DoF.FarIntensity = 0.35; DoF.FocusDistance = 40
DoF.InFocusRadius = 60; DoF.NearIntensity = 0; DoF.Enabled = false; DoF.Parent = Lighting

local MenuBlur = track(Instance.new("BlurEffect"))
MenuBlur.Name = "BV_MenuBlur"; MenuBlur.Size = 0; MenuBlur.Parent = Lighting

local Presets = {
    ["Neon Night"] = {
        ClockTime = 0, Brightness = 2, Ambient = Color3.fromRGB(60, 30, 110),
        OutdoorAmbient = Color3.fromRGB(90, 50, 160), FogEnd = 1800,
        FogColor = Color3.fromRGB(40, 10, 80), ExposureCompensation = 0.3,
        cc = { Saturation = 0.35, Contrast = 0.15, TintColor = Color3.fromRGB(220, 200, 255) },
    },
    ["Sunset"] = {
        ClockTime = 17.8, Brightness = 2.5, Ambient = Color3.fromRGB(120, 70, 50),
        OutdoorAmbient = Color3.fromRGB(200, 120, 80), FogEnd = 2500,
        FogColor = Color3.fromRGB(255, 150, 100), ExposureCompensation = 0.2,
        cc = { Saturation = 0.25, Contrast = 0.1, TintColor = Color3.fromRGB(255, 225, 200) },
    },
    ["Ocean Dream"] = {
        ClockTime = 13, Brightness = 3, Ambient = Color3.fromRGB(60, 110, 140),
        OutdoorAmbient = Color3.fromRGB(110, 170, 210), FogEnd = 3000,
        FogColor = Color3.fromRGB(120, 200, 255), ExposureCompensation = 0.1,
        cc = { Saturation = 0.3, Contrast = 0.05, TintColor = Color3.fromRGB(210, 240, 255) },
    },
    ["Sakura"] = {
        ClockTime = 9, Brightness = 2.8, Ambient = Color3.fromRGB(140, 90, 110),
        OutdoorAmbient = Color3.fromRGB(230, 170, 200), FogEnd = 2200,
        FogColor = Color3.fromRGB(255, 190, 220), ExposureCompensation = 0.15,
        cc = { Saturation = 0.2, Contrast = 0.05, TintColor = Color3.fromRGB(255, 225, 240) },
    },
}

local function applyPreset(p)
    for k, v in pairs(p) do
        if k ~= "cc" then pcall(function() Lighting[k] = v end) end
    end
    CC.Enabled = true
    for k, v in pairs(p.cc) do CC[k] = v end
end

local function restoreLighting()
    State.preset = nil
    for k, v in pairs(Original) do
        if k ~= "FieldOfView" then pcall(function() Lighting[k] = v end) end
    end
    CC.Enabled = false
end

local function same(a, b)
    if typeof(a) == "number" and typeof(b) == "number" then return math.abs(a - b) < 1e-3 end
    if typeof(a) == "Color3" and typeof(b) == "Color3" then
        return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
    end
    return a == b
end

local function holdPreset()
    if State.clockLock and not same(Lighting.ClockTime, State.clock) then Lighting.ClockTime = State.clock end
    local p = State.preset and Presets[State.preset]
    if not p then return end
    for k, v in pairs(p) do
        if k ~= "cc" and not (k == "ClockTime" and State.clockLock) and not same(Lighting[k], v) then
            pcall(function() Lighting[k] = v end)
        end
    end
    if not CC.Enabled then CC.Enabled = true end
end

connect(Lighting.Changed, function(prop)
    if prop == "ClockTime" and State.clockLock then
        if not same(Lighting.ClockTime, State.clock) then Lighting.ClockTime = State.clock end
        return
    end
    local p = State.preset and Presets[State.preset]
    if p and prop ~= "cc" and p[prop] ~= nil and not same(Lighting[prop], p[prop]) then
        pcall(function() Lighting[prop] = p[prop] end)
    end
end)

---------------------------------------------------------------- skies
-- Procedural skies: Sky + Atmosphere + Terrain clouds, no external assets needed.
-- The game's own Sky / Atmosphere are parked (Parent = nil) and put back on reset.
local SkyPresets, BVSky, applySky, applySkyboxId, restoreSky
do
SkyPresets = {
    ["Starry Night"] = {
        sky = { StarCount = 5000, CelestialBodiesShown = true, MoonAngularSize = 18, SunAngularSize = 8 },
        atmo = { Density = 0.25, Offset = 0.1, Color = Color3.fromRGB(110, 120, 180), Decay = Color3.fromRGB(40, 40, 95), Glare = 0, Haze = 0.6 },
        clouds = { Cover = 0.25, Density = 0.3, Color = Color3.fromRGB(120, 130, 190) },
        time = 0,
    },
    ["Dreamy Pink"] = {
        sky = { StarCount = 1500, CelestialBodiesShown = true, MoonAngularSize = 14, SunAngularSize = 16 },
        atmo = { Density = 0.35, Offset = 0.2, Color = Color3.fromRGB(255, 185, 225), Decay = Color3.fromRGB(205, 120, 210), Glare = 1.6, Haze = 2 },
        clouds = { Cover = 0.6, Density = 0.5, Color = Color3.fromRGB(255, 215, 238) },
        time = 17.4,
    },
    ["Blood Moon"] = {
        sky = { StarCount = 3000, CelestialBodiesShown = true, MoonAngularSize = 30, SunAngularSize = 6 },
        atmo = { Density = 0.42, Offset = 0.15, Color = Color3.fromRGB(255, 75, 75), Decay = Color3.fromRGB(95, 10, 22), Glare = 2, Haze = 2.6 },
        clouds = { Cover = 0.5, Density = 0.55, Color = Color3.fromRGB(125, 22, 32) },
        time = 23.5,
    },
    ["Thunderstorm"] = {
        sky = { StarCount = 0, CelestialBodiesShown = false },
        atmo = { Density = 0.48, Offset = 0, Color = Color3.fromRGB(140, 146, 158), Decay = Color3.fromRGB(78, 84, 96), Glare = 0, Haze = 3.2 },
        clouds = { Cover = 0.92, Density = 0.85, Color = Color3.fromRGB(88, 92, 104) },
        time = 15,
    },
    ["Clear Sky"] = {
        sky = { StarCount = 3000, CelestialBodiesShown = true, MoonAngularSize = 11, SunAngularSize = 21 },
        atmo = { Density = 0.28, Offset = 0.25, Color = Color3.fromRGB(175, 205, 255), Decay = Color3.fromRGB(105, 140, 200), Glare = 0.6, Haze = 1 },
        clouds = { Cover = 0.42, Density = 0.4, Color = Color3.fromRGB(255, 255, 255) },
        time = 12,
    },
    ["Aurora"] = {
        sky = { StarCount = 4500, CelestialBodiesShown = true, MoonAngularSize = 12, SunAngularSize = 6 },
        atmo = { Density = 0.3, Offset = 0.1, Color = Color3.fromRGB(110, 255, 200), Decay = Color3.fromRGB(70, 60, 180), Glare = 3, Haze = 1.8 },
        clouds = { Cover = 0.35, Density = 0.35, Color = Color3.fromRGB(120, 255, 210) },
        time = 1,
    },
}

local Skies = { parked = {}, clouds = nil, cloudsOrig = nil, cloudsOwned = false }

BVSky = track(Instance.new("Sky"))
BVSky.Name = "BV_Sky"
local BVAtmo = track(Instance.new("Atmosphere"))
BVAtmo.Name = "BV_Atmosphere"

local SKY_FACES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
local DEFAULT_FACES = {}
for _, f in ipairs(SKY_FACES) do DEFAULT_FACES[f] = BVSky[f] end

local function parkGameSky()
    for _, c in ipairs(Lighting:GetChildren()) do
        if (c:IsA("Sky") or c:IsA("Atmosphere")) and c ~= BVSky and c ~= BVAtmo then
            table.insert(Skies.parked, c)
            c.Parent = nil
        end
    end
end

local CLOUD_PROPS = { "Cover", "Density", "Color", "Enabled" }
local function getClouds()
    if Skies.clouds and Skies.clouds.Parent then return Skies.clouds end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    local c = terrain:FindFirstChildOfClass("Clouds")
    if c then
        Skies.cloudsOrig = {}
        for _, k in ipairs(CLOUD_PROPS) do Skies.cloudsOrig[k] = c[k] end
        Skies.cloudsOwned = false
    else
        c = Instance.new("Clouds")
        c.Name = "BV_Clouds"
        c.Parent = terrain
        Skies.cloudsOwned = true
    end
    Skies.clouds = c
    return c
end

function applySky(name)
    local p = SkyPresets[name]
    if not p then return end
    State.sky = name
    parkGameSky()
    for _, f in ipairs(SKY_FACES) do BVSky[f] = DEFAULT_FACES[f] end
    for k, v in pairs(p.sky) do pcall(function() BVSky[k] = v end) end
    for k, v in pairs(p.atmo) do pcall(function() BVAtmo[k] = v end) end
    BVSky.Parent, BVAtmo.Parent = Lighting, Lighting
    local c = getClouds()
    if c then
        c.Enabled = true
        for k, v in pairs(p.clouds) do pcall(function() c[k] = v end) end
    end
    if p.time and not State.preset and not State.clockLock then Lighting.ClockTime = p.time end
end

-- Any decal / texture id pasted by the user, put on all six faces
function applySkyboxId(id)
    parkGameSky()
    local asset = "rbxassetid://" .. id
    for _, f in ipairs(SKY_FACES) do BVSky[f] = asset end
    BVSky.Parent = Lighting
    State.sky = "Custom"
    State.skyboxId = id
end

function restoreSky()
    State.sky = nil
    BVSky.Parent, BVAtmo.Parent = nil, nil
    for _, c in ipairs(Skies.parked) do pcall(function() c.Parent = Lighting end) end
    Skies.parked = {}
    local c = Skies.clouds
    if c then
        if Skies.cloudsOwned then c:Destroy()
        elseif Skies.cloudsOrig then for k, v in pairs(Skies.cloudsOrig) do pcall(function() c[k] = v end) end end
    end
    Skies.clouds, Skies.cloudsOrig = nil, nil
    pcall(function() BVSky.SkyboxOrientation = Vector3.zero end)
end
end -- skies
RunService:BindToRenderStep("BV_HoldPreset", Enum.RenderPriority.Last.Value, holdPreset)

local RNG = Random.new()
local TAU = math.pi * 2
local function rnd(a, b) return RNG:NextNumber(a, b) end
local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end

local FxFolder = track(Instance.new("Folder"))
FxFolder.Name = "BV_FX"; FxFolder.Parent = workspace

local function basePart(parent, props, anchored)
    local p = Instance.new("Part")
    if props and props.Shape then p.Shape = props.Shape end
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = anchored, false, false, false
    p.Massless, p.CastShadow = true, false
    p.Material = Enum.Material.Neon
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Size = Vector3.new(0.2, 0.2, 0.2)
    for k, v in pairs(props or {}) do if k ~= "Shape" then p[k] = v end end
    p.Parent = parent
    return p
end
local function fxPart(parent, props) return basePart(parent, props, false) end
local function worldPart(parent, props) return basePart(parent, props, true) end

local function weld(p0, p1, c0)
    local w = Instance.new("Weld")
    w.Part0, w.Part1, w.C0 = p0, p1, c0
    w.Parent = p1
    return w
end

local function hostPart(name)
    local p = worldPart(FxFolder, { Name = name, Transparency = 1, CFrame = CFrame.new() })
    return p
end

-- Effect slots: name -> { root, update }, switched on/off by toggles
local function makeSlots(builders, getArg)
    local slots = { active = {}, on = {} }
    function slots.build(name)
        local cur = slots.active[name]
        if cur then slots.active[name] = nil pcall(function() cur.root:Destroy() end) end
        if not slots.on[name] then return end
        local arg = getArg and getArg()
        if getArg and not arg then return end
        local ok, root, update = pcall(builders[name], arg)
        if ok and root then
            slots.active[name] = { root = root, update = update }
        elseif not ok then
            warn("[BloxVisuals] " .. name .. ": " .. tostring(root))
        end
    end
    function slots.set(name, v) slots.on[name] = v slots.build(name) end
    function slots.step(dt, t)
        for _, s in pairs(slots.active) do pcall(s.update, dt, t) end
    end
    function slots.clear()
        for name, s in pairs(slots.active) do
            slots.active[name] = nil
            pcall(function() s.root:Destroy() end)
        end
    end
    return slots
end

local Acc, World

local AccBuilders = {}

---------------------------------------------------------------- accessories
do
-- Ellipsoid feather: a thin part with a sphere mesh stretched along its local Y
local function feather(parent, size, transparency)
    local p = fxPart(parent, { Size = size, Transparency = transparency or 0 })
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Sphere
    m.Parent = p
    return p
end

local function wedgePart(parent, props)
    local w = Instance.new("WedgePart")
    w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch = false, false, false, false
    w.Massless, w.CastShadow = true, false
    w.Material = Enum.Material.Neon
    w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for k, v in pairs(props or {}) do w[k] = v end
    w.Parent = parent
    return w
end

-- Any triangle as two wedges: returns cframe/size for both halves
local function triangleCFrames(a, b, c, th)
    local ab, ac, bc = b - a, c - a, c - b
    local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
    if abd > acd and abd > bcd then c, a = a, c
    elseif acd > bcd and acd > abd then a, b = b, a end
    ab, ac, bc = b - a, c - a, c - b
    local right = ac:Cross(ab).Unit
    local up = bc:Cross(right).Unit
    local back = bc.Unit
    local height = math.abs(ab:Dot(up))
    return CFrame.fromMatrix((a + b) / 2, right, up, back), Vector3.new(th, height, math.abs(ab:Dot(back))),
           CFrame.fromMatrix((a + c) / 2, -right, up, -back), Vector3.new(th, height, math.abs(ac:Dot(back)))
end

local function bezier(a, b, c, u)
    local v = 1 - u
    return a * (v * v) + b * (2 * v * u) + c * (u * u)
end

-- Head accessories copy the head's LocalTransparencyModifier so they vanish in first person
local function fpSync(root, head)
    local parts, last = {}, nil
    for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then table.insert(parts, d) end end
    return function()
        local m = head.LocalTransparencyModifier
        if m ~= last then
            last = m
            for _, p in ipairs(parts) do p.LocalTransparencyModifier = m end
        end
    end
end

-- Feathered angel wings. Each wing is a curved arm (the leading edge) with three layers of ellipsoid
-- feathers fanned along it: short coverts on top, secondaries along the forearm, long primaries at the
-- tip. They breathe slowly while idle, open up and beat harder while running or in the air.
AccBuilders.wings = function(char)
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not torso then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = Instance.new("Folder"); root.Name = "BV_Wings"; root.Parent = char
    local k = State.wingSize * 0.75
    -- leading edge in wing space: X = outwards, Y = up, the wing lies in the XY plane, +Z = behind
    local P0, P1, P2 = Vector3.new(0.15, 0, 0), Vector3.new(1.5, 2.1, 0) * k, Vector3.new(4.3, 1.5, 0) * k
    local PRIM_LEN = { 2.5, 2.8, 3.1, 3.3, 3.35, 3.15, 2.75 }
    local wings, colored, tips = {}, {}, {}

    for _, s in ipairs({ 1, -1 }) do
        local pivot = fxPart(root, { Transparency = 1 })
        local base = CFrame.new(s * 0.3, torso.Size.Y * 0.2, torso.Size.Z / 2 + 0.12)
        table.insert(wings, { weld = weld(torso, pivot, base), base = base, s = s, pivot = pivot })
        local mirror = Vector3.new(s, 1, 1)
        local function edge(u) return bezier(P0, P1, P2, u) * mirror end
        -- angle: 0 = feather hangs straight down, 90 = points straight outwards
        local function place(part, u, angle, len, z)
            weld(pivot, part, CFrame.new(edge(u) + Vector3.new(0, 0, z))
                * CFrame.Angles(0, 0, s * math.rad(angle)) * CFrame.new(0, -len / 2, 0))
        end

        -- primaries: the long fan at the wing tip
        for i, len0 in ipairs(PRIM_LEN) do
            local f = (i - 1) / (#PRIM_LEN - 1)
            local u, len = 0.56 + f * 0.44, len0 * k
            local p = feather(root, Vector3.new(0.42 * k, len, 0.06), 0.4)
            place(p, u, 36 + f * 60, len, 0)
            table.insert(colored, { part = p, dim = 0.85 })
            if i == #PRIM_LEN then table.insert(tips, { part = p, len = len }) end
        end
        -- secondaries: along the forearm, hanging down
        for i = 1, 8 do
            local f = (i - 1) / 7
            local len = (1.75 + 0.85 * f) * k
            local p = feather(root, Vector3.new(0.5 * k, len, 0.06), 0.45)
            place(p, 0.04 + f * 0.5, 4 + f * 30, len, 0.04)
            table.insert(colored, { part = p, dim = 0.75 })
        end
        -- coverts: short, brighter layer on top of the arm
        for i = 1, 11 do
            local f = (i - 1) / 10
            local len = (0.95 + 0.4 * f) * k
            local p = feather(root, Vector3.new(0.46 * k, len, 0.07), 0.32)
            place(p, 0.03 + f * 0.92, 8 + f * 75, len, 0.09)
            table.insert(colored, { part = p, dim = 1 })
        end
        -- the arm itself: tapered bone along the leading edge
        for i = 0, 9 do
            local u0, u1 = i / 10, (i + 1) / 10
            local a, b = edge(u0), edge(u1)
            local th = (0.26 - 0.15 * u0) * k
            local p = feather(root, Vector3.new(th, th, (b - a).Magnitude + th), 0.25)
            weld(pivot, p, CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0, 0.11), b + Vector3.new(0, 0, 0.11)))
            table.insert(colored, { part = p, dim = 1 })
        end
    end

    -- glowing streaks from the wing tips + falling feather dust
    local trails = {}
    for _, tip in ipairs(tips) do
        local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, -tip.len / 2, 0); a0.Parent = tip.part
        local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -tip.len / 2 + 0.7 * k, 0); a1.Parent = tip.part
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Lifetime = 0.35
        tr.LightEmission = 1
        tr.LightInfluence = 0
        tr.FaceCamera = true
        tr.Enabled = false
        tr.Transparency = NumberSequence.new({ kp(0, 0.3), kp(1, 1) })
        tr.WidthScale = NumberSequence.new({ kp(0, 1), kp(1, 0) })
        tr.Parent = tip.part
        local dust = Instance.new("ParticleEmitter")
        dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        dust.Rate = 7
        dust.Lifetime = NumberRange.new(0.9, 1.5)
        dust.Speed = NumberRange.new(0.2, 0.8)
        dust.SpreadAngle = Vector2.new(180, 180)
        dust.Acceleration = Vector3.new(0, -2.5, 0)
        dust.LightEmission = 0.4
        dust.LightInfluence = 0
        dust.Size = NumberSequence.new({ kp(0, 0.22 * k), kp(1, 0) })
        dust.Transparency = NumberSequence.new({ kp(0, 0.15), kp(1, 1) })
        dust.Parent = tip.part
        table.insert(trails, { trail = tr, dust = dust })
    end
    local light = Instance.new("PointLight")
    light.Range = 11; light.Brightness = 1.2; light.Shadows = false; light.Parent = wings[1].pivot

    local energy, phase, started = 0, 0, false
    return root, function(dt, t)
        local vel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
        local air = hum and hum.FloorMaterial == Enum.Material.Air
        local run = math.clamp(Vector3.new(vel.X, 0, vel.Z).Magnitude / 20, 0, 1)
        energy += ((air and 1 or run * 0.55) - energy) * math.min(dt * 3, 1)
        phase += dt * (1.7 + energy * 5.5)
        local lift = math.sin(phase) * (0.1 + energy * 0.42) + energy * 0.12
        local fold = math.rad(26) * (1 - energy * 0.7) + math.cos(phase) * (0.05 + energy * 0.12)
        for _, w in ipairs(wings) do
            w.weld.C0 = w.base * CFrame.Angles(0, -w.s * fold, 0) * CFrame.Angles(0, 0, w.s * lift)
        end
        local col = accColor()
        for _, c in ipairs(colored) do c.part.Color = shade(col, c.dim) end
        local seq = ColorSequence.new(col)
        for _, tr in ipairs(trails) do
            tr.trail.Color = seq
            tr.dust.Color = seq
            -- one frame late so the streak doesn't start from the world origin
            tr.trail.Enabled = started and energy > 0.25
        end
        started = true
        light.Color = col
    end
end

-- China hat in the style of PvP client cosmetics (Pulse / Rise / Vape): a wide translucent cone built
-- from real triangles, the colour flowing around the brim, a solid outline ring, faint ribs and a tip.
AccBuilders.hat = function(char)
    local head = char:FindFirstChild("Head")
    if not head then return end
    local root = Instance.new("Folder"); root.Name = "BV_Hat"; root.Parent = char
    local N, RIBS = 30, 10
    local R = head.Size.Y * 1.6
    local rimY = head.Size.Y / 2 - 0.1
    local apex = Vector3.new(0, rimY + R * 0.42, 0)
    Acc.hatTop = apex.Y
    local segs, rim = {}, {}
    for i = 1, N do
        local a0, a1 = (i - 1) / N * TAU, i / N * TAU
        local p0 = Vector3.new(math.cos(a0) * R, rimY, math.sin(a0) * R)
        local p1 = Vector3.new(math.cos(a1) * R, rimY, math.sin(a1) * R)
        local c1, s1, c2, s2 = triangleCFrames(apex, p0, p1, 0.03)
        local w1 = wedgePart(root, { Size = s1, Transparency = 0.5 })
        local w2 = wedgePart(root, { Size = s2, Transparency = 0.5 })
        weld(head, w1, c1)
        weld(head, w2, c2)
        table.insert(segs, w1)
        table.insert(segs, w2)
        local e = fxPart(root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new((p1 - p0).Magnitude + 0.05, 0.08, 0.08), Transparency = 0.25 })
        weld(head, e, CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.pi / 2, 0))
        rim[i] = e
    end
    local ribs = {}
    for i = 1, RIBS do
        local a = (i - 1) / RIBS * TAU
        local p = Vector3.new(math.cos(a) * R, rimY, math.sin(a) * R)
        local r = fxPart(root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new((p - apex).Magnitude, 0.035, 0.035), Transparency = 0.4 })
        weld(head, r, CFrame.lookAt((p + apex) / 2, p) * CFrame.Angles(0, math.pi / 2, 0))
        ribs[i] = r
    end
    local tip = fxPart(root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.16, Transparency = 0.25 })
    weld(head, tip, CFrame.new(apex + Vector3.new(0, 0.02, 0)))
    local sync = fpSync(root, head)

    return root, function()
        local c = accColor()
        local dark = shade(c, 0.8)
        for _, p in ipairs(segs) do p.Color = c end
        for _, p in ipairs(rim) do p.Color = c end
        for _, p in ipairs(ribs) do p.Color = dark end
        tip.Color = c
        sync()
    end
end

-- Halo: a smooth ring of cylinders with a soft outer glow, floating and slowly bobbing over the head
-- (sits above the China hat when both are on)
AccBuilders.halo = function(char)
    local head = char:FindFirstChild("Head")
    if not head then return end
    local root = Instance.new("Folder"); root.Name = "BV_Halo"; root.Parent = char
    local pivot = fxPart(root, { Transparency = 1 })
    local w = weld(head, pivot, CFrame.new(0, 2, 0))
    local N, R = 32, head.Size.Y * 0.8
    local segs = {}
    for i = 1, N do
        local th = (i - 0.5) / N * TAU
        local len = TAU * R / N * 1.1
        local cf = CFrame.Angles(0, th, 0) * CFrame.new(R, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
        local core = fxPart(root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 0.11, 0.11), Transparency = 0.3 })
        local halo = fxPart(root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 0.32, 0.32), Transparency = 0.85 })
        weld(pivot, core, cf)
        weld(pivot, halo, cf)
        segs[i] = { core = core, glow = halo }
    end
    local disk = fxPart(root, { Transparency = 1, Size = Vector3.new(R * 2, 0.05, R * 2) })
    weld(pivot, disk, CFrame.new())
    local dust = Instance.new("ParticleEmitter")
    dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    dust.Rate = 5
    dust.Lifetime = NumberRange.new(0.8, 1.4)
    dust.Speed = NumberRange.new(0.1, 0.4)
    dust.SpreadAngle = Vector2.new(180, 180)
    dust.Acceleration = Vector3.new(0, -1.2, 0)
    dust.LightEmission = 0.4
    dust.LightInfluence = 0
    dust.Size = NumberSequence.new({ kp(0, 0.16), kp(1, 0) })
    dust.Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) })
    dust.Parent = disk
    local light = Instance.new("PointLight")
    light.Range = 7; light.Brightness = 1.4; light.Shadows = false; light.Parent = pivot
    local sync = fpSync(root, head)

    return root, function(_, t)
        local top = Acc.active.hat and Acc.hatTop or head.Size.Y / 2
        local y = top + 0.7 + math.sin(t * 2) * 0.07
        w.C0 = CFrame.new(0, y, 0) * CFrame.Angles(math.rad(-8), 0, 0) * CFrame.Angles(0, t * 0.8, 0)
        local c = accColor()
        for _, s in ipairs(segs) do
            s.core.Color = c
            s.glow.Color = c
        end
        dust.Color = ColorSequence.new(c)
        light.Color = c
        sync()
    end
end
end -- accessories

---------------------------------------------------------------- auras
-- One aura at a time. "Rainbow Colors" off = accent colors (fire / lightning / void keep their own palette)
local AuraBuilders = {}
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local function csk(t, c) return ColorSequenceKeypoint.new(t, c) end
local emitter
do
local FIRE  = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

function emitter(parent, props)
    local e = Instance.new("ParticleEmitter")
    e.LightInfluence = 0
    for k, v in pairs(props) do e[k] = v end
    e.Parent = parent
    return e
end

local function glow(parent, range, brightness, color)
    local l = Instance.new("PointLight")
    l.Range, l.Brightness, l.Shadows = range, brightness, false
    if color then l.Color = color end
    l.Parent = parent
    return l
end

local function makeTrail(part, half, life)
    local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, half, 0); a0.Parent = part
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -half, 0); a1.Parent = part
    local tr = Instance.new("Trail")
    tr.Attachment0, tr.Attachment1 = a0, a1
    tr.Lifetime = life
    tr.LightEmission = 1
    tr.LightInfluence = 0
    tr.FaceCamera = true
    tr.Enabled = false
    tr.Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) })
    tr.WidthScale = NumberSequence.new({ kp(0, 1), kp(1, 0) })
    tr.Parent = part
    return tr
end

-- Invisible box welded to the root part; particles spawn from its volume
local function bodyShell(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local s = State.auraSize
    local shell = fxPart(char, { Name = "BV_Aura", Transparency = 1, Size = Vector3.new(2.6, 5, 1.6) * s })
    weld(hrp, shell, CFrame.new(0, -0.4, 0))
    return shell, hrp
end

local function liveRoot(char)
    local hrp = char.Parent and char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or (hum and hum.Health <= 0) then return end
    return hrp
end

AuraBuilders.rainbow = function(char)
    local shell = bodyShell(char)
    if not shell then return end
    local s = State.auraSize
    local e = emitter(shell, {
        Texture = SPARK, Rate = 35, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 3),
        SpreadAngle = Vector2.new(180, 180), LightEmission = 1, RotSpeed = NumberRange.new(-90, 90),
        Size = NumberSequence.new({ kp(0, 0.6 * s), kp(0.5, 0.9 * s), kp(1, 0) }),
        Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) }),
    })
    local light = glow(shell, 14, 2)
    return shell, function()
        e.Color = ColorSequence.new(auraColor(), auraColor(0.2))
        light.Color = auraColor()
    end
end

local FIRE_SEQ  = ColorSequence.new({
    csk(0, Color3.fromRGB(255, 240, 160)), csk(0.35, Color3.fromRGB(255, 140, 40)), csk(1, Color3.fromRGB(160, 20, 10)),
})
local EMBER_SEQ = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 30))

AuraBuilders.fire = function(char)
    local shell = bodyShell(char)
    if not shell then return end
    local s = State.auraSize
    local flames = emitter(shell, {
        Texture = FIRE, Rate = 65, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(2, 4),
        EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12), Acceleration = Vector3.new(0, 6, 0),
        LightEmission = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
        Size = NumberSequence.new({ kp(0, 1.4 * s), kp(0.6, 0.9 * s), kp(1, 0) }),
        Transparency = NumberSequence.new({ kp(0, 0.35), kp(0.7, 0.55), kp(1, 1) }),
        Color = FIRE_SEQ,
    })
    local embers = emitter(shell, {
        Texture = SPARK, Rate = 18, Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(3, 6),
        EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, 2, 0),
        LightEmission = 1, Size = NumberSequence.new({ kp(0, 0.25 * s), kp(1, 0) }),
        Transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) }), Color = EMBER_SEQ,
    })
    local light = glow(shell, 16, 2.5, Color3.fromRGB(255, 140, 50))
    return shell, function(_, t)
        if State.auraRainbow then
            flames.Color = ColorSequence.new(Color3.new(1, 1, 1), rainbow())
            embers.Color = ColorSequence.new(rainbow(0.1), rainbow(0.3))
            light.Color = rainbow()
        elseif flames.Color ~= FIRE_SEQ then
            flames.Color, embers.Color = FIRE_SEQ, EMBER_SEQ
            light.Color = Color3.fromRGB(255, 140, 50)
        end
        light.Brightness = 2.2 + math.sin(t * 17) * 0.4 + math.sin(t * 7.3) * 0.3
    end
end

-- Zig-zag electric arcs jumping off the body
AuraBuilders.lightning = function(char)
    local shell = bodyShell(char)
    if not shell then return end
    local s = State.auraSize
    local ARCS, PTS = 4, 5
    local ELECTRIC = Color3.fromRGB(140, 220, 255)
    local arcs = {}
    for i = 1, ARCS do
        local arc = { pts = {}, beams = {}, next = rnd(0, 0.2), on = false }
        for p = 1, PTS do
            local a = Instance.new("Attachment"); a.Parent = shell
            arc.pts[p] = a
        end
        for p = 1, PTS - 1 do
            local b = Instance.new("Beam")
            b.Attachment0, b.Attachment1 = arc.pts[p], arc.pts[p + 1]
            b.FaceCamera = true
            b.LightEmission = 1
            b.LightInfluence = 0
            b.Segments = 1
            b.Width0 = 0.14 * s * (1 - (p - 1) / PTS)
            b.Width1 = 0.14 * s * (1 - p / PTS)
            b.Enabled = false
            b.Parent = shell
            arc.beams[p] = b
        end
        arcs[i] = arc
    end
    local sparks = emitter(shell, {
        Texture = SPARK, Rate = 22, Lifetime = NumberRange.new(0.15, 0.35), Speed = NumberRange.new(4, 9),
        SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
        Size = NumberSequence.new({ kp(0, 0.3 * s), kp(1, 0) }), Transparency = NumberSequence.new(0.1),
    })
    local light = glow(shell, 14, 1.5, ELECTRIC)

    local function strike(arc)
        local start = Vector3.new(rnd(-1, 1), rnd(-2.2, 2.2), rnd(-0.7, 0.7)) * s
        local dir = Vector3.new(rnd(-1, 1), rnd(-0.6, 0.8), rnd(-1, 1))
        if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
        local finish = start + dir.Unit * rnd(1.6, 3.2) * s
        for p, a in ipairs(arc.pts) do
            local k = (p - 1) / (PTS - 1)
            local jitter = (p == 1 or p == PTS) and Vector3.zero
                or Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) * 0.45 * s
            a.Position = start:Lerp(finish, k) + jitter
        end
    end

    return shell, function(dt, t)
        local col = State.auraRainbow and rainbow() or ELECTRIC
        local seq = ColorSequence.new(Color3.new(1, 1, 1), col)
        local flash = 0
        for i, arc in ipairs(arcs) do
            arc.next -= dt
            if arc.next <= 0 then
                arc.on = not arc.on
                if arc.on then strike(arc) arc.next = rnd(0.05, 0.11) else arc.next = rnd(0.02, 0.18) end
                for _, b in ipairs(arc.beams) do b.Enabled = arc.on end
            end
            if arc.on then
                flash += 1
                for _, b in ipairs(arc.beams) do b.Color = seq end
            end
        end
        sparks.Color = seq
        light.Color = col
        light.Brightness = 0.8 + flash * 0.6
    end
end

-- Three tilted orbit rings of glowing orbs with trails (atom style)
AuraBuilders.galaxy = function(char)
    if not char:FindFirstChild("HumanoidRootPart") then return end
    local root = Instance.new("Folder"); root.Name = "BV_Aura"; root.Parent = FxFolder
    local s = State.auraSize
    local rings, orbs = {}, {}
    for r = 1, 3 do
        local ring = {
            tilt = CFrame.Angles(0, math.rad((r - 1) * 60), 0) * CFrame.Angles(math.rad(65), 0, 0),
            speed = (r % 2 == 0 and -1 or 1) * (1.5 + r * 0.35),
        }
        rings[r] = ring
        for i = 1, 4 do
            local p = worldPart(root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.38 * s })
            table.insert(orbs, { ring = ring, part = p, trail = makeTrail(p, 0.12 * s, 0.4), phase = i / 4 * TAU, off = r * 0.2 + i * 0.05 })
        end
    end
    local core = worldPart(root, { Transparency = 1 })
    local light = glow(core, 12, 1.8)
    local started = false
    return root, function(_, t)
        local hrp = liveRoot(char)
        if not hrp then
            for _, o in ipairs(orbs) do o.part.Transparency = 1 o.trail.Enabled = false end
            light.Enabled, started = false, false
            return
        end
        local center = CFrame.new(hrp.Position)
        core.CFrame = center
        light.Enabled = true
        light.Color = auraColor()
        local R = 2.7 * s
        for _, o in ipairs(orbs) do
            local a = o.phase + t * o.ring.speed
            o.part.CFrame = center * o.ring.tilt * CFrame.new(math.cos(a) * R, 0, math.sin(a) * R)
            o.part.Transparency = 0
            local c = auraColor(o.off)
            o.part.Color = c
            o.trail.Color = ColorSequence.new(c)
        end
        -- enable trails one frame late so they don't streak from the world origin
        if started then for _, o in ipairs(orbs) do o.trail.Enabled = true end end
        started = true
    end
end

-- Two strands of orbs climbing a helix around the player
AuraBuilders.spiral = function(char)
    if not char:FindFirstChild("HumanoidRootPart") then return end
    local root = Instance.new("Folder"); root.Name = "BV_Aura"; root.Parent = FxFolder
    local s = State.auraSize
    local N = 16
    local orbs = {}
    for i = 1, N do
        local p = worldPart(root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.28 * s })
        orbs[i] = { part = p, trail = makeTrail(p, 0.09 * s, 0.25), u = (i - 1) / N * 2 % 1, strand = i % 2 }
    end
    local core = worldPart(root, { Transparency = 1 })
    local light = glow(core, 11, 1.6)
    local started = false
    return root, function(dt, t)
        local hrp = liveRoot(char)
        if not hrp then
            for _, o in ipairs(orbs) do o.part.Transparency = 1 o.trail.Enabled = false end
            light.Enabled, started = false, false
            return
        end
        local base = hrp.Position
        core.CFrame = CFrame.new(base)
        light.Enabled = true
        light.Color = auraColor()
        for _, o in ipairs(orbs) do
            local prev = o.u
            o.u = (o.u + dt * 0.35) % 1
            if o.u < prev then o.trail:Clear() end
            local a = o.u * TAU * 2 + t * 1.5 + o.strand * math.pi
            local r = (1.9 - 0.6 * o.u) * s
            local y = (-2.8 + o.u * 6) * s
            o.part.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
            local edge = math.min(o.u, 1 - o.u) * 6
            o.part.Transparency = 1 - math.clamp(edge, 0, 1)
            local c = auraColor(o.u * 0.5)
            o.part.Color = c
            o.trail.Color = ColorSequence.new(c)
        end
        if started then for _, o in ipairs(orbs) do o.trail.Enabled = true end end
        started = true
    end
end

local VOID_PURPLE = Color3.fromRGB(140, 40, 255)
local VOID_SMOKE  = ColorSequence.new(Color3.fromRGB(45, 0, 80), Color3.fromRGB(5, 0, 12))
local VOID_WISPS  = ColorSequence.new(Color3.fromRGB(190, 90, 255), Color3.fromRGB(255, 60, 200))

AuraBuilders.void = function(char)
    local shell = bodyShell(char)
    if not shell then return end
    local s = State.auraSize
    emitter(shell, {
        Texture = SMOKE, Rate = 28, Lifetime = NumberRange.new(1.6, 2.6), Speed = NumberRange.new(0.5, 1.5),
        EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, 1.5, 0),
        LightEmission = 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
        Size = NumberSequence.new({ kp(0, 1.2 * s), kp(0.5, 2.4 * s), kp(1, 3 * s) }),
        Transparency = NumberSequence.new({ kp(0, 1), kp(0.2, 0.45), kp(1, 1) }),
        Color = VOID_SMOKE,
    })
    local wisps = emitter(shell, {
        Texture = SPARK, Rate = 14, Lifetime = NumberRange.new(0.8, 1.5), Speed = NumberRange.new(1, 2),
        SpreadAngle = Vector2.new(180, 180), LightEmission = 1, Acceleration = Vector3.new(0, 1, 0),
        Size = NumberSequence.new({ kp(0, 0.35 * s), kp(1, 0) }),
        Transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) }), Color = VOID_WISPS,
    })
    local light = glow(shell, 12, 2, VOID_PURPLE)
    return shell, function(_, t)
        if State.auraRainbow then
            wisps.Color = ColorSequence.new(rainbow(), rainbow(0.3))
            light.Color = rainbow()
        elseif wisps.Color ~= VOID_WISPS then
            wisps.Color, light.Color = VOID_WISPS, VOID_PURPLE
        end
        light.Brightness = 1.6 + math.sin(t * 2.4) * 0.5
    end
end
end -- auras

local WorldBuilders = {}

-- Nova Step: every jump leaves a launch ring on the ground and a short trail of booster rings
-- under the feet; every landing slams a shockwave into the ground: a flash disk, two expanding
-- rings and shards bouncing away. A longer / faster fall gives a bigger impact.
WorldBuilders.novaStep = function()
    local root = Instance.new("Folder"); root.Name = "BV_NovaStep"; root.Parent = FxFolder
    local host = worldPart(root, { Transparency = 1 })
    local sparks = emitter(host, {
        Texture = SPARK, Rate = 0, Lifetime = NumberRange.new(0.35, 0.7), Speed = NumberRange.new(6, 12),
        EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80), LightEmission = 0.5,
        Drag = 3, Acceleration = Vector3.new(0, -16, 0),
        Size = NumberSequence.new({ kp(0, 0.35), kp(1, 0) }),
        Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) }),
    })
    local light = Instance.new("PointLight")
    light.Range = 14; light.Brightness = 0; light.Shadows = false; light.Parent = host

    local RING = 26
    local ringPool, shardPool, diskPool, live = {}, {}, {}, {}
    local flash, feet = 0, nil

    local function add(delay, life, step, free)
        table.insert(live, { age = -delay, life = life, step = step, free = free })
    end

    -- ring on the ground around `center` (a point or a function returning one), growing r0 -> r1
    local function ring(center, delay, life, r0, r1, thick, rise, t0)
        local segs = table.remove(ringPool)
        if not segs then
            segs = {}
            for i = 1, RING do segs[i] = worldPart(root, { Transparency = 1 }) end
        end
        local c
        add(delay, life, function(k, col)
            if not c then c = typeof(center) == "function" and center() or center end
            local e = 1 - (1 - k) ^ 3
            local radius = r0 + (r1 - r0) * e
            local segLen = TAU * radius / RING * 1.08
            local cf = CFrame.new(c + Vector3.new(0, 0.06 + rise * e, 0))
            local th = thick * (1 - k * 0.6)
            for i, s in ipairs(segs) do
                s.Size = Vector3.new(th, th * 0.5, segLen)
                s.CFrame = cf * CFrame.Angles(0, i / RING * TAU, 0) * CFrame.new(radius, 0, 0)
                s.Transparency = t0 + (1 - t0) * k
                s.Color = col
            end
        end, function()
            for _, s in ipairs(segs) do s.Transparency = 1 end
            table.insert(ringPool, segs)
        end)
    end

    local function disk(center, life, d1)
        local p = table.remove(diskPool) or worldPart(root, { Shape = Enum.PartType.Cylinder, Transparency = 1 })
        add(0, life, function(k, col)
            local d = 0.6 + (d1 - 0.6) * (1 - (1 - k) ^ 2)
            p.Size = Vector3.new(0.05, d, d)
            p.CFrame = CFrame.new(center + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2)
            p.Transparency = 0.45 + 0.55 * k
            p.Color = col
        end, function()
            p.Transparency = 1
            table.insert(diskPool, p)
        end)
    end

    local function shard(pos, vel, groundY, life)
        local p = table.remove(shardPool) or worldPart(root, { Transparency = 1 })
        local spin = Vector3.new(rnd(-12, 12), rnd(-12, 12), rnd(-12, 12))
        local sz = rnd(0.14, 0.26)
        add(0, life, function(k, col, dt)
            vel += Vector3.new(0, -45 * dt, 0)
            pos += vel * dt
            if pos.Y < groundY + sz / 2 then
                pos = Vector3.new(pos.X, groundY + sz / 2, pos.Z)
                vel = Vector3.new(vel.X * 0.5, math.abs(vel.Y) * 0.3, vel.Z * 0.5)
            end
            local a = k * life
            p.Size = Vector3.new(sz, sz, sz * 2.2) * (1 - k * 0.5)
            p.CFrame = CFrame.new(pos) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
            p.Transparency = 0.25 + 0.75 * k
            p.Color = col
        end, function()
            p.Transparency = 1
            table.insert(shardPool, p)
        end)
    end

    local function burst(at, n)
        host.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0))
        sparks:Emit(n)
    end

    local function onJump(at)
        ring(at, 0, 0.45, 0.5, 2.6, 0.2, 0.05, 0.2)
        for i = 1, 3 do
            ring(function() return feet end, i * 0.06, 0.35, 0.7, 1.5, 0.12, -0.3, 0.35)
        end
        burst(at, 14)
        flash = math.max(flash, 0.8)
    end

    local function onLand(at, power)
        ring(at, 0, 0.55, 0.4, 4.2 * power, 0.26, 0, 0.1)
        ring(at, 0.07, 0.5, 0.3, 2.8 * power, 0.16, 0.6 * power, 0.3)
        disk(at, 0.32, 3.6 * power)
        for _ = 1, math.floor(6 + 6 * power) do
            local a = rnd(0, TAU)
            local dir = Vector3.new(math.cos(a), 0, math.sin(a))
            shard(at + dir * 0.4 + Vector3.new(0, 0.2, 0),
                dir * rnd(7, 13) * power + Vector3.new(0, rnd(7, 12) * power, 0), at.Y, rnd(0.5, 0.8))
        end
        burst(at, math.floor(14 + 16 * power))
        flash = math.max(flash, 1 + power)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local wasAir, airTime, minVY = false, 0, 0

    return root, function(dt)
        local col = accColor()
        flash = math.max(flash - dt * 5, 0)
        light.Brightness = flash * 1.5
        light.Color = col
        sparks.Color = ColorSequence.new(col)

        for i = #live, 1, -1 do
            local fx = live[i]
            fx.age += dt
            if fx.age >= 0 then
                local k = fx.age / fx.life
                if k >= 1 then
                    fx.free()
                    table.remove(live, i)
                else
                    fx.step(k, col, dt)
                end
            end
        end

        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then wasAir = false return end

        params.FilterDescendantsInstances = { char, FxFolder }
        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -12, 0), params)
        local drop = hum.RigType == Enum.HumanoidRigType.R15
            and (hum.HipHeight + hrp.Size.Y / 2) or (hrp.Size.Y / 2 + 2)
        feet = Vector3.new(hrp.Position.X, hrp.Position.Y - drop, hrp.Position.Z)
        local ground = Vector3.new(feet.X, hit and hit.Position.Y or feet.Y, feet.Z)

        local air = hum.FloorMaterial == Enum.Material.Air
        local vy = hrp.AssemblyLinearVelocity.Y
        if air and not wasAir then
            airTime, minVY = 0, 0
            if vy > 12 then onJump(ground) end
        elseif air then
            airTime += dt
            minVY = math.min(minVY, vy)
        elseif wasAir and airTime > 0.15 then
            onLand(ground, math.clamp(0.55 + -minVY / 70 + airTime * 0.25, 0.6, 1.6))
        end
        wasAir = air
    end
end

-- World-anchored fields. Space is cut into boxes ("cells"); each cell owns a few particles whose
-- position is a pure function of (cell, index, time). Nothing is glued to the camera, so when you
-- move fast you fly through particles that are already there instead of dragging them along.
local function hash(x, y, z, k)
    local n = math.sin(x * 127.1 + y * 311.7 + z * 74.7 + k * 19.19) * 43758.5453
    return n - math.floor(n)
end

local function fieldCells(f)
    return (2 * f.radius + 1) ^ 2 * (2 * f.layers + 1)
end

-- fn(x, y, z, origin, cam) for every cell around the camera
local function eachCell(f, fn)
    local c = Camera.CFrame.Position
    local S, H, R, V = f.cell, f.height, f.radius, f.layers
    local cx, cy, cz = math.floor(c.X / S), math.floor(c.Y / H), math.floor(c.Z / S)
    for x = cx - R, cx + R do
        for z = cz - R, cz + R do
            for y = cy - V, cy + V do
                fn(x, y, z, Vector3.new(x * S, y * H, z * S), c)
            end
        end
    end
end

-- 1 well inside the covered area, 0 at its border, so cells coming and going don't pop
local function edgeFade(f, pos, c)
    local d = pos - c
    local horiz = math.sqrt(d.X * d.X + d.Z * d.Z)
    return math.clamp(math.min(
        (f.radius * f.cell - horiz) / (f.cell * 0.8),
        (f.layers * f.height - math.abs(d.Y)) / (f.height * 0.5)
    ), 0, 1)
end

-- Falling particles (snowflakes / petals / sparks)
local function driftBuilder(o)
    return function()
        local host = hostPart(o.name)
        local S, H = o.cell, o.height
        local pool = {}
        for i = 1, fieldCells(o) * o.maxPer do
            local a = Instance.new("Attachment"); a.Parent = host
            local bb = Instance.new("BillboardGui")
            bb.LightInfluence = 0
            bb.MaxDistance = 160
            bb.Adornee = a
            bb.Enabled = false
            bb.Parent = a
            pool[i] = { a = a, bb = bb, vis = o.make(bb), size = 0 }
        end
        return host, function(_, t)
            local per = o.per and math.min(o.per(), o.maxPer) or o.maxPer
            local used = 0
            eachCell(o, function(x, y, z, origin, cam)
                for k = 1, per do
                    used += 1
                    local p = pool[used]
                    local r1, r2, r3, r4 = hash(x, y, z, k), hash(x, y, z, k + 0.31), hash(x, y, z, k + 0.57), hash(x, y, z, k + 0.83)
                    local fall = o.fall[1] + (o.fall[2] - o.fall[1]) * r3
                    local phase = r4 * TAU
                    local sway = (0.4 + 0.6 * r2) * o.sway
                    local lx = (r1 * S + o.wind.X * t) % S
                    local lz = (r2 * S + o.wind.Z * t) % S
                    local ly = H - ((t * fall + r4 * H) % H)
                    local pos = origin + Vector3.new(
                        lx + math.sin(t * 0.9 + phase) * sway,
                        ly,
                        lz + math.cos(t * 0.7 + phase * 1.3) * sway
                    )
                    -- fade where a particle wraps inside its cell (top/bottom, wind edges)
                    local alpha = edgeFade(o, pos, cam)
                        * math.clamp(math.min(ly, H - ly) / 2, 0, 1)
                        * math.clamp(math.min(lx, S - lx, lz, S - lz) / 1.5, 0, 1)
                    if alpha <= 0.01 then
                        if p.bb.Enabled then p.bb.Enabled = false end
                    else
                        if not p.bb.Enabled then p.bb.Enabled = true end
                        p.a.Position = pos
                        local sz = o.size[1] + (o.size[2] - o.size[1]) * r3
                        if p.size ~= sz then p.size = sz p.bb.Size = UDim2.fromScale(sz, sz) end
                        p.seed, p.phase, p.spin = r1, phase, (r2 * 2 - 1) * o.spin
                        o.animate(p, t, alpha)
                    end
                end
            end)
            for i = used + 1, #pool do
                if pool[i].bb.Enabled then pool[i].bb.Enabled = false end
            end
        end
    end
end

WorldBuilders.snowflakes = driftBuilder({
    name = "BV_Snowflakes", cell = 18, height = 26, radius = 3, layers = 1, maxPer = 1,
    size = { 0.35, 0.8 }, fall = { 2, 4.2 }, spin = 1.2, sway = 1.2, wind = Vector3.new(0.6, 0, 0.3),
    make = function(bb)
        local l = Instance.new("TextLabel")
        l.Text = "❄"
        l.TextScaled = true
        l.Font = Enum.Font.GothamBold
        l.TextColor3 = Color3.fromRGB(235, 245, 255)
        l.TextStrokeColor3 = Color3.fromRGB(150, 200, 255)
        l.TextStrokeTransparency = 0.55
        l.BackgroundTransparency = 1
        l.Size = UDim2.fromScale(1, 1)
        l.Parent = bb
        return l
    end,
    animate = function(p, t, alpha)
        p.vis.Rotation = math.deg(p.phase) + t * p.spin * 60
        p.vis.TextTransparency = 1 - alpha
        p.vis.TextStrokeTransparency = 1 - alpha * 0.45
    end,
})

WorldBuilders.sakura = driftBuilder({
    name = "BV_Sakura", cell = 20, height = 26, radius = 3, layers = 1, maxPer = 1,
    size = { 0.35, 0.6 }, fall = { 1.2, 2.6 }, spin = 1.6, sway = 2.2, wind = Vector3.new(1.8, 0, 0.9),
    make = function(bb)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromScale(0.5, 0.5)
        f.Size = UDim2.fromScale(1, 0.62)
        f.BackgroundColor3 = Color3.new(1, 1, 1)
        f.BorderSizePixel = 0
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0.5, 0); cr.Parent = f
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(Color3.fromRGB(255, 160, 195), Color3.fromRGB(255, 235, 243))
        g.Rotation = 90
        g.Parent = f
        f.Parent = bb
        return f
    end,
    animate = function(p, t, alpha)
        p.vis.Rotation = math.deg(p.phase) + t * p.spin * 70
        -- petal "flipping" in the air
        p.vis.Size = UDim2.fromScale(0.2 + 0.8 * math.abs(math.cos(t * (1.5 + p.seed * 1.7) + p.phase)), 0.62)
        p.vis.BackgroundTransparency = 1 - alpha
    end,
})

-- Glowing rainbow sparks (replaces the old camera-following ParticleEmitter)
WorldBuilders.sparks = driftBuilder({
    name = "BV_Sparks", cell = 18, height = 30, radius = 3, layers = 1, maxPer = 3,
    per = function() return State.sparkDensity end,
    size = { 0.25, 0.5 }, fall = { 6, 10 }, spin = 0, sway = 0.4, wind = Vector3.new(1.5, 0, 0.8),
    make = function(bb)
        local glowF = Instance.new("Frame")
        glowF.Size = UDim2.fromScale(1, 1)
        glowF.BorderSizePixel = 0
        glowF.BackgroundColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", glowF).CornerRadius = UDim.new(0.5, 0)
        glowF.Parent = bb
        local core = Instance.new("Frame")
        core.AnchorPoint = Vector2.new(0.5, 0.5)
        core.Position = UDim2.fromScale(0.5, 0.5)
        core.Size = UDim2.fromScale(0.4, 0.4)
        core.BorderSizePixel = 0
        core.BackgroundColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", core).CornerRadius = UDim.new(0.5, 0)
        core.Parent = glowF
        return { glow = glowF, core = core }
    end,
    animate = function(p, t, alpha)
        p.vis.glow.BackgroundColor3 = rainbow(p.seed * 0.5)
        p.vis.glow.BackgroundTransparency = 1 - alpha * 0.45
        p.vis.core.BackgroundTransparency = 1 - alpha
    end,
})

-- Wind streaks: thin curved lines that swoosh through the air and fade
local STREAK_WIND = Vector3.new(1, 0, 0.35).Unit
WorldBuilders.streaks = function()
    local host = hostPart("BV_Streaks")
    local F = { cell = 26, height = 14, radius = 3, layers = 1 }
    local pool = {}
    for i = 1, fieldCells(F) do
        local a0 = Instance.new("Attachment"); a0.Parent = host
        local a1 = Instance.new("Attachment"); a1.Parent = host
        pcall(function() a0.Axis, a1.Axis = Vector3.yAxis, Vector3.yAxis end)
        local b = Instance.new("Beam")
        b.Attachment0, b.Attachment1 = a0, a1
        b.FaceCamera = true
        b.LightEmission = 1
        b.LightInfluence = 0
        b.Segments = 12
        b.Width0, b.Width1 = 0.02, 0.1
        b.Enabled = false
        b.Parent = host
        pool[i] = { a0 = a0, a1 = a1, b = b }
    end
    local WHITE_SEQ = ColorSequence.new(Color3.fromRGB(225, 240, 255))
    local SPEED, LIFE = 22, 1.3
    return host, function(_, t)
        local used = 0
        eachCell(F, function(x, y, z, origin, cam)
            used += 1
            local s = pool[used]
            local r1, r2, r3 = hash(x, y, z, 1), hash(x, y, z, 1.37), hash(x, y, z, 1.71)
            local period = 2.8 + r1 * 3
            local ph = (t + r2 * period) % period
            if ph > LIFE then
                if s.b.Enabled then s.b.Enabled = false end
                return
            end
            local u = ph / LIFE
            local dir = (STREAK_WIND + Vector3.new(0, (r3 - 0.5) * 0.15, (r3 - 0.5) * 0.6)).Unit
            local start = origin + Vector3.new(r1 * F.cell, r2 * F.height, r3 * F.cell) - dir * (SPEED * LIFE * 0.5)
            local head = start + dir * (SPEED * LIFE * u)
            local env = math.sin(u * math.pi)
            local tail = head - dir * (0.5 + 7 * env)
            local alpha = edgeFade(F, head, cam) * env
            if alpha <= 0.01 then
                if s.b.Enabled then s.b.Enabled = false end
                return
            end
            s.a0.Position, s.a1.Position = tail, head
            local bend = (r2 - 0.5) * 2.4
            s.b.CurveSize0, s.b.CurveSize1 = bend, bend
            s.b.Transparency = NumberSequence.new({ kp(0, 1), kp(0.6, 1 - alpha * 0.6), kp(1, 1 - alpha * 0.85) })
            s.b.Color = State.streakRainbow and ColorSequence.new(rainbow(r1), rainbow(r1 + 0.15)) or WHITE_SEQ
            if not s.b.Enabled then s.b.Enabled = true end
        end)
        for i = used + 1, #pool do
            if pool[i].b.Enabled then pool[i].b.Enabled = false end
        end
    end
end

-- Constellations: a world-anchored star field linked by lines. Every grid cell owns a few stars whose
-- position is a pure function of the cell, so they are already in place before you get there. The field
-- reaches ~120 studs around the camera (fading out only at the far border, never popping in front of you)
-- and links are searched only between neighbouring cells, so it stays cheap at high density.
WorldBuilders.constellations = function()
    local host = hostPart("BV_Constellations")
    local F = { cell = 30, height = 26, radius = 4, layers = 2 }
    local PER, BEAMS, MAX_DEG, A = 3, 420, 3, 2.5
    local NX, NY = 2 * F.radius + 1, 2 * F.layers + 1
    local STAR = Color3.fromRGB(200, 215, 255)
    local LINE = ColorSequence.new(Color3.fromRGB(225, 232, 255))
    local REACH, BAND   = F.radius * F.cell, F.cell * 1.3
    local VREACH, VBAND = F.layers * F.height, F.height * 0.9

    local function slotOf(dx, dy, dz)
        return ((dx + F.radius) * NY + (dy + F.layers)) * NX + (dz + F.radius) + 1
    end
    -- cells nearest the camera first, so close stars always win the beam budget
    local cells = {}
    for dx = -F.radius, F.radius do
        for dy = -F.layers, F.layers do
            for dz = -F.radius, F.radius do
                local dyS = dy * F.height / F.cell
                table.insert(cells, { dx = dx, dy = dy, dz = dz, slot = slotOf(dx, dy, dz), d = dx * dx + dyS * dyS + dz * dz })
            end
        end
    end
    table.sort(cells, function(a, b) return a.d < b.d end)
    -- forward half of the 26 neighbours: every pair of adjacent cells is checked exactly once
    for _, c in ipairs(cells) do
        c.nb = {}
        for a = -1, 1 do
            for b = -1, 1 do
                for d = -1, 1 do
                    if a > 0 or (a == 0 and (b > 0 or (b == 0 and d > 0))) then
                        local x, y, z = c.dx + a, c.dy + b, c.dz + d
                        if math.abs(x) <= F.radius and math.abs(y) <= F.layers and math.abs(z) <= F.radius then
                            table.insert(c.nb, slotOf(x, y, z))
                        end
                    end
                end
            end
        end
    end

    local nodes, beams = {}, {}
    for i = 1, #cells * PER do
        local a = Instance.new("Attachment"); a.Parent = host
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0.9, 6, 0.9, 6) -- grows up close, stays a visible dot far away
        bb.LightInfluence = 0
        bb.MaxDistance = 400
        bb.Adornee = a
        bb.Enabled = false
        bb.Parent = a
        local glowF = Instance.new("Frame")
        glowF.Size = UDim2.fromScale(1, 1)
        glowF.BackgroundColor3 = STAR
        glowF.BackgroundTransparency = 1
        glowF.BorderSizePixel = 0
        Instance.new("UICorner", glowF).CornerRadius = UDim.new(0.5, 0)
        glowF.Parent = bb
        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.fromScale(0.5, 0.5)
        dot.Size = UDim2.fromScale(0.42, 0.42)
        dot.BackgroundColor3 = Color3.new(1, 1, 1)
        dot.BackgroundTransparency = 1
        dot.BorderSizePixel = 0
        Instance.new("UICorner", dot).CornerRadius = UDim.new(0.5, 0)
        dot.Parent = bb
        nodes[i] = { a = a, bb = bb, glow = glowF, dot = dot, fade = 0, deg = 0, pos = Vector3.zero }
    end
    for i = 1, BEAMS do
        local b = Instance.new("Beam")
        b.FaceCamera = true
        b.Width0, b.Width1 = 0.08, 0.08
        b.LightEmission = 1
        b.LightInfluence = 0
        b.Segments = 1
        b.Color = LINE
        b.Enabled = false
        b.Parent = host
        beams[i] = { b = b }
    end
    -- beam transparency in 21 steps, so links don't allocate a NumberSequence every frame
    local TSEQ = {}
    for i = 0, 20 do TSEQ[i] = NumberSequence.new(1 - i / 20 * 0.8) end

    local used, maxD, maxD2, rbOn = 0, 16, 256, false
    local function tryLink(ni, nj)
        if used >= BEAMS or ni.deg >= MAX_DEG or nj.deg >= MAX_DEG or nj.fade <= 0 then return end
        local v = ni.pos - nj.pos
        local m = v:Dot(v)
        if m >= maxD2 then return end
        used += 1
        local e = beams[used]
        local b = e.b
        local lvl = math.floor((1 - math.sqrt(m) / maxD) * math.min(ni.fade, nj.fade) * 20 + 0.5)
        if b.Attachment0 ~= ni.a then b.Attachment0 = ni.a end
        if b.Attachment1 ~= nj.a then b.Attachment1 = nj.a end
        if e.lvl ~= lvl then e.lvl = lvl b.Transparency = TSEQ[lvl] end
        if rbOn then
            b.Color = ColorSequence.new(ni.glow.BackgroundColor3, nj.glow.BackgroundColor3)
            e.rb = true
        elseif e.rb ~= false then
            b.Color, e.rb = LINE, false
        end
        if not b.Enabled then b.Enabled = true end
        ni.deg += 1
        nj.deg += 1
    end

    local frame = 0
    return host, function(_, t)
        frame += 1
        local cam = Camera.CFrame.Position
        local S, H = F.cell, F.height
        local cx, cy, cz = math.floor(cam.X / S), math.floor(cam.Y / H), math.floor(cam.Z / S)
        local per = math.clamp(State.starDensity, 1, PER)
        local rb = State.starRainbow
        local phase = frame % 3

        for _, c in ipairs(cells) do
            local x, y, z = cx + c.dx, cy + c.dy, cz + c.dz
            local origin = Vector3.new(x * S, y * H, z * S)
            local base = (c.slot - 1) * PER
            for k = 1, PER do
                local id = base + k
                local n = nodes[id]
                n.deg = 0
                if k > per then
                    n.fade = 0
                    if n.bb.Enabled then n.bb.Enabled = false end
                else
                    local r1, r2, r3 = hash(x, y, z, 2 + k), hash(x, y, z, 2.37 + k), hash(x, y, z, 2.71 + k)
                    local pos = origin + Vector3.new(
                        (0.12 + 0.76 * r1) * S + math.sin(t * 0.13 + r3 * TAU) * A,
                        (0.12 + 0.76 * r2) * H + math.sin(t * 0.11 + r1 * TAU) * A * 0.5,
                        (0.12 + 0.76 * r3) * S + math.cos(t * 0.17 + r2 * TAU) * A
                    )
                    n.pos = pos
                    local d = pos - cam
                    local fade = math.clamp(math.min(
                        (REACH - math.sqrt(d.X * d.X + d.Z * d.Z)) / BAND,
                        (VREACH - math.abs(d.Y)) / VBAND
                    ), 0, 1)
                    if fade <= 0.01 then
                        n.fade = 0
                        if n.bb.Enabled then n.bb.Enabled = false end
                    else
                        n.fade = fade
                        -- the drift is slow, so a star is rewritten every 3rd frame unless it just
                        -- moved to a new cell (camera crossed a border) or just became visible
                        local moved = n.cx ~= x or n.cy ~= y or n.cz ~= z
                        if moved or id % 3 == phase or not n.bb.Enabled then
                            n.cx, n.cy, n.cz = x, y, z
                            n.a.Position = pos
                            local tw = 0.7 + 0.3 * math.sin(t * (1.2 + r2 * 2.5) + r3 * TAU)
                            n.dot.BackgroundTransparency = 1 - fade * tw
                            n.glow.BackgroundTransparency = 1 - fade * 0.3 * tw
                            if rb then
                                n.glow.BackgroundColor3, n.rb = rainbow(r1), true
                            elseif n.rb ~= false then
                                n.glow.BackgroundColor3, n.rb = STAR, false
                            end
                            if not n.bb.Enabled then n.bb.Enabled = true end
                        end
                    end
                end
            end
        end

        used, maxD, rbOn = 0, State.linkDist, rb
        maxD2 = maxD * maxD
        for _, c in ipairs(cells) do
            if used >= BEAMS then break end
            local base = (c.slot - 1) * PER
            for i = 1, per do
                local ni = nodes[base + i]
                if ni.fade > 0 then
                    for j = i + 1, per do tryLink(ni, nodes[base + j]) end
                    for _, s in ipairs(c.nb) do
                        local b2 = (s - 1) * PER
                        for j = 1, per do tryLink(ni, nodes[b2 + j]) end
                    end
                end
            end
        end
        for i = used + 1, BEAMS do
            local b = beams[i].b
            if b.Enabled then b.Enabled = false end
        end
    end
end

Acc   = makeSlots(AccBuilders, function() return LP.Character end)
World = makeSlots(WorldBuilders)
local Aura = makeSlots(AuraBuilders, function() return LP.Character end)

local function setAura(name)
    State.aura = name
    for k in pairs(Aura.on) do Aura.on[k] = false Aura.build(k) end
    if name then Aura.set(name, true) end
end

local auraRebuild = 0
local function rebuildAuraSoon()
    auraRebuild += 1
    local id = auraRebuild
    task.delay(0.25, function()
        if id == auraRebuild and State.aura then Aura.build(State.aura) end
    end)
end

local CharFX = {}

local function clearCharFX()
    for _, v in pairs(CharFX) do if typeof(v) == "Instance" then v:Destroy() end end
    CharFX = {}
end

local function buildCharFX(char)
    clearCharFX()
    local root = char:WaitForChild("HumanoidRootPart", 10)
    if not root then return end

    local a0 = Instance.new("Attachment"); a0.Name = "BV_T0"; a0.Position = Vector3.new(0, 1.2, 0); a0.Parent = root
    local a1 = Instance.new("Attachment"); a1.Name = "BV_T1"; a1.Position = Vector3.new(0, -1.2, 0); a1.Parent = root
    CharFX.a0, CharFX.a1 = a0, a1

    local trail = Instance.new("Trail")
    trail.Name = "BV_Trail"
    trail.Attachment0, trail.Attachment1 = a0, a1
    trail.Lifetime = 0.55
    trail.MinLength = 0.05
    trail.LightEmission = 1
    trail.FaceCamera = true
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    trail.Enabled = State.trail
    trail.Parent = root
    CharFX.trail = trail

    local hl = Instance.new("Highlight")
    hl.Name = "BV_Outline"
    hl.FillTransparency = 0.85
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
    hl.Enabled = State.outline
    hl.Adornee = char
    hl.Parent = char
    CharFX.outline = hl

    char:WaitForChild("Head", 5)
    for name in pairs(Acc.on) do Acc.build(name) end
    if State.aura then Aura.build(State.aura) end
end

if LP.Character then task.spawn(buildCharFX, LP.Character) end
connect(LP.CharacterAdded, function(c) task.spawn(buildCharFX, c) end)

local LOGO     = "rbxassetid://89295771390146"
local VERSION  = "v4.0"
local MENU_KEY = Enum.KeyCode.Insert

local function guiParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then
        local test = Instance.new("Folder")
        if pcall(function() test.Parent = core end) then test:Destroy() return core end
    end
    return LP:WaitForChild("PlayerGui")
end

local Theme = {
    bg       = Color3.fromRGB(15, 16, 21),
    panel    = Color3.fromRGB(8, 8, 10),
    group    = Color3.fromRGB(11, 11, 14),
    row      = Color3.fromRGB(20, 21, 26),
    hover    = Color3.fromRGB(29, 30, 37),
    stroke   = Color3.fromRGB(32, 34, 42),
    strokeHi = Color3.fromRGB(72, 74, 86),
    text     = Color3.fromRGB(236, 237, 242),
    sub      = Color3.fromRGB(138, 140, 152),
    off      = Color3.fromRGB(48, 50, 60),
    ink      = Color3.fromRGB(10, 10, 12),
    accent   = Color3.fromRGB(240, 240, 245),
    accent2  = Color3.fromRGB(170, 172, 185),
}

local Themes = {
    { name = "Mono",    desc = "White → silver",  a = Color3.fromRGB(240, 240, 245), b = Color3.fromRGB(170, 172, 185) },
    { name = "Purple",   desc = "Purple → pink",   a = Color3.fromRGB(150, 100, 255), b = Color3.fromRGB(255, 95, 200) },
    { name = "Ocean",   desc = "Blue → cyan",     a = Color3.fromRGB(60, 140, 255),  b = Color3.fromRGB(80, 235, 255) },
    { name = "Mint",    desc = "Green → lime",    a = Color3.fromRGB(50, 215, 150),  b = Color3.fromRGB(185, 255, 120) },
    { name = "Crimson", desc = "Red → orange",    a = Color3.fromRGB(255, 65, 95),   b = Color3.fromRGB(255, 170, 70) },
}

local WHITE = Color3.new(1, 1, 1)

local function new(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, ch in ipairs(children or {}) do ch.Parent = o end
    return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end
local function tween(o, t, props, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local accentGrads, accentHooks = {}, {}
local function accentSeq()
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Theme.accent),
        ColorSequenceKeypoint.new(0.5, Theme.accent2),
        ColorSequenceKeypoint.new(1,   Theme.accent),
    })
end
local function accentGrad(parent, rotation)
    local g = new("UIGradient", { Color = accentSeq(), Rotation = rotation or 0, Parent = parent })
    table.insert(accentGrads, g)
    return g
end
local function onAccent(fn) table.insert(accentHooks, fn) fn() end
local function setTheme(t)
    Theme.accent, Theme.accent2 = t.a, t.b
    AuraTint.a, AuraTint.b = t.a, t.b
    local seq = accentSeq()
    for _, g in ipairs(accentGrads) do g.Color = seq end
    for _, fn in ipairs(accentHooks) do fn() end
end

local cleanup
local visible = false

local Screen = track(new("ScreenGui", {
    Name = "BloxVisuals", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}))
Screen.Parent = guiParent()

local NotifyHolder = new("Frame", {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.fromOffset(250, 400), BackgroundTransparency = 1, Parent = Screen,
}, {
    new("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
    }),
})

local notifyCount = 0
local function notify(title, text, good)
    if not State.notify then return end
    notifyCount += 1
    local slot = new("Frame", {
        Size = UDim2.fromOffset(250, 54), BackgroundTransparency = 1,
        LayoutOrder = notifyCount, Parent = NotifyHolder,
    })
    local card = new("Frame", {
        Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(280, 0),
        BackgroundColor3 = Theme.panel, BackgroundTransparency = 0.04, BorderSizePixel = 0, Parent = slot,
    }, { corner(8), new("UIStroke", { Color = Theme.stroke }) })

    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 1, -18), Position = UDim2.fromOffset(9, 9),
        BackgroundColor3 = good == false and Theme.off or WHITE, BorderSizePixel = 0, Parent = card,
    }, { corner(2) })
    if good ~= false then new("UIGradient", { Color = accentSeq(), Rotation = 90, Parent = bar }) end

    new("TextLabel", {
        Text = title, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.text,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 9), Size = UDim2.new(1, -30, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
    })
    new("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.sub,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 27), Size = UDim2.new(1, -30, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
    })
    local prog = new("Frame", {
        Size = UDim2.new(1, -16, 0, 2), Position = UDim2.new(0, 8, 1, -4),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = card,
    }, { corner(1), new("UIGradient", { Color = accentSeq() }) })

    local duration = 2.6
    tween(card, 0.45, { Position = UDim2.fromOffset(0, 0) })
    tween(prog, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
    task.delay(duration, function()
        tween(card, 0.35, { Position = UDim2.fromOffset(280, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.35)
        slot:Destroy()
    end)
end

---------------------------------------------------------------- configs
-- Every control registers itself (key = its title) with a getter and a setter. A config is
-- { version, values = { [key] = value } } saved as JSON in BloxVisuals/configs via the executor's file API.
-- Kept in one table: the main chunk is close to Luau's 200-locals limit.
local Config = {
    items = {}, byKey = {},
    ROOT = "BloxVisuals", DIR = "BloxVisuals/configs", AUTO = "BloxVisuals/autoload.txt",
    fs = (writefile and readfile and isfile and isfolder and makefolder and listfiles) ~= nil,
}

function Config.register(key, get, set)
    if Config.byKey[key] then return end
    local it = { key = key, get = get, set = set }
    Config.byKey[key] = it
    table.insert(Config.items, it)
end

function Config.clean(name)
    name = tostring(name or ""):gsub("[^%w%s%-_]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return name:sub(1, 32)
end

function Config.path(name) return Config.DIR .. "/" .. name .. ".json" end

function Config.ensureDirs()
    if not isfolder(Config.ROOT) then makefolder(Config.ROOT) end
    if not isfolder(Config.DIR) then makefolder(Config.DIR) end
end

function Config.snapshot()
    local values = {}
    for _, it in ipairs(Config.items) do
        local ok, v = pcall(it.get)
        if ok and v ~= nil then values[it.key] = v end
    end
    return { version = 1, values = values }
end

-- Only keys present in the data are touched, so older configs keep working when new options appear
function Config.apply(data)
    local values = type(data) == "table" and data.values
    if type(values) ~= "table" then return false end
    for _, it in ipairs(Config.items) do
        local v = values[it.key]
        if v ~= nil then
            local ok, err = pcall(it.set, v)
            if not ok then warn("[BloxVisuals] config " .. it.key .. ": " .. tostring(err)) end
        end
    end
    return true
end

function Config.encode() return game:GetService("HttpService"):JSONEncode(Config.snapshot()) end
function Config.decode(json)
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(json) end)
    return ok and data or nil
end

function Config.exists(name) return Config.fs and isfile(Config.path(name)) or false end

function Config.save(name)
    Config.ensureDirs()
    writefile(Config.path(name), Config.encode())
end

function Config.load(name)
    if not Config.exists(name) then return false end
    return Config.apply(Config.decode(readfile(Config.path(name))))
end

function Config.delete(name)
    if not delfile or not Config.exists(name) then return false end
    local wasAuto = Config.getAuto() == name
    delfile(Config.path(name))
    if wasAuto then Config.setAuto(nil) end
    return true
end

function Config.list()
    local out = {}
    if not Config.fs or not isfolder(Config.DIR) then return out end
    for _, p in ipairs(listfiles(Config.DIR)) do
        local n = p:match("([^/\\]+)%.json$")
        if n then table.insert(out, n) end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

function Config.getAuto()
    if not Config.fs or not isfile(Config.AUTO) then return end
    local n = Config.clean(readfile(Config.AUTO))
    if n ~= "" and Config.exists(n) then return n end
end

function Config.setAuto(name)
    Config.ensureDirs()
    writefile(Config.AUTO, name or "")
end

-- Window layout: sidebar | content | player preview
local W, H          = 920, 560
local GAP           = 8
local SIDE, RIGHT   = 180, 220
local CENTER_X      = GAP * 2 + SIDE
local CENTER_W      = W - SIDE - RIGHT - GAP * 4
local RIGHT_X       = W - GAP - RIGHT
local PANEL_H       = H - GAP * 2
local PREVIEW_Y     = 70
local PREVIEW_H     = PANEL_H - PREVIEW_Y - 44

local Holder = new("Frame", {
    Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = Screen,
})
local WinScale = new("UIScale", { Scale = 0.92, Parent = Holder })

local baseScale = 1
local function fitScale()
    local vp = Camera.ViewportSize
    baseScale = math.clamp(math.min((vp.X - 40) / W, (vp.Y - 40) / H), 0.45, 1)
    if visible then WinScale.Scale = baseScale end
end
fitScale()
connect(Camera:GetPropertyChangedSignal("ViewportSize"), fitScale)

new("TextButton", { Modal = true, Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(0, 0), Parent = Holder })

local Shadow = new("ImageLabel", {
    Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 1,
    ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 70, 1, 70), BackgroundTransparency = 1, ZIndex = 0, Parent = Holder,
})

local Main = new("CanvasGroup", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.bg, BorderSizePixel = 0,
    GroupTransparency = 1, ZIndex = 1, Parent = Holder,
}, { corner(12) })

local Outline = new("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = Holder,
}, { corner(12) })
local OutlineStroke = new("UIStroke", { Color = Theme.stroke, Thickness = 1, Transparency = 1, Parent = Outline })

local function Panel(x, w)
    return new("Frame", {
        Position = UDim2.fromOffset(x, GAP), Size = UDim2.fromOffset(w, PANEL_H),
        BackgroundColor3 = Theme.panel, BorderSizePixel = 0, Parent = Main,
    }, { corner(10), new("UIStroke", { Color = Theme.stroke }) })
end
local function Divider(parent, y, inset)
    return new("Frame", {
        Size = UDim2.new(1, -(inset or 0) * 2, 0, 1), Position = UDim2.new(0, inset or 0, 0, y),
        BackgroundColor3 = Theme.stroke, BorderSizePixel = 0, Parent = parent,
    })
end

local Side   = Panel(GAP, SIDE)
local Center = Panel(CENTER_X, CENTER_W)
local Right  = Panel(RIGHT_X, RIGHT)

---------------------------------------------------------------- sidebar
local Brand = new("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, Parent = Side })
new("ImageLabel", {
    Image = LOGO, ScaleType = Enum.ScaleType.Fit, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14),
    Size = UDim2.fromOffset(124, 124), Parent = Brand,
})

local TabList = new("Frame", {
    Position = UDim2.fromOffset(14, 154), Size = UDim2.new(1, -28, 1, -240),
    BackgroundTransparency = 1, Parent = Side,
}, { new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

Divider(Side, PANEL_H - 74, 14)
local UserCard = new("Frame", {
    Position = UDim2.new(0, 14, 1, -64), Size = UDim2.new(1, -28, 0, 52),
    BackgroundTransparency = 1, Parent = Side,
})
local Avatar = new("ImageLabel", {
    Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 0, 0.5, -20),
    BackgroundColor3 = Theme.row, Image = "", Parent = UserCard,
}, { corner(20), new("UIStroke", { Color = Theme.strokeHi }) })
new("TextLabel", {
    Text = LP.DisplayName, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.text,
    BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 8), Size = UDim2.new(1, -52, 0, 17),
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = UserCard,
})
new("TextLabel", {
    Text = "@" .. LP.Name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.sub,
    BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 27), Size = UDim2.new(1, -52, 0, 15),
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = UserCard,
})
task.spawn(function()
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    if ok and img then Avatar.Image = img end
end)

---------------------------------------------------------------- content
local TopBar = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, Parent = Center })
local PageTitle = new("TextLabel", {
    Text = "", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Theme.text,
    BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 9), Size = UDim2.new(1, -240, 0, 17),
    TextXAlignment = Enum.TextXAlignment.Left, Parent = TopBar,
})
local PageDesc = new("TextLabel", {
    Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.sub,
    BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 27), Size = UDim2.new(1, -240, 0, 14),
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = TopBar,
})

local SearchBox = new("TextBox", {
    Text = "", PlaceholderText = "Search...", PlaceholderColor3 = Theme.sub, ClearTextOnFocus = false,
    Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.text,
    BackgroundColor3 = Theme.row, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -48, 0.5, 0), Size = UDim2.fromOffset(150, 30),
    TextXAlignment = Enum.TextXAlignment.Right, Parent = TopBar,
}, { corner(6), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

-- Magnifier icon drawn from frames
local SearchIcon = new("TextButton", {
    Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(28, 28), Parent = TopBar,
})
new("Frame", {
    Size = UDim2.fromOffset(13, 13), Position = UDim2.fromOffset(6, 5),
    BackgroundTransparency = 1, Parent = SearchIcon,
}, { corner(7), new("UIStroke", { Color = Theme.text, Thickness = 2 }) })
new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 7), Position = UDim2.fromOffset(20.5, 20.5),
    Rotation = -45, BackgroundColor3 = Theme.text, BorderSizePixel = 0, Parent = SearchIcon,
}, { corner(1) })
connect(SearchIcon.MouseButton1Click, function() SearchBox:CaptureFocus() end)
connect(SearchBox.Focused, function()
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    tween(SearchBox, 0.2, { BackgroundTransparency = 0 })
end)
connect(SearchBox.FocusLost, function()
    if SearchBox.Text == "" then
        SearchBox.TextXAlignment = Enum.TextXAlignment.Right
        tween(SearchBox, 0.2, { BackgroundTransparency = 1 })
    end
end)

Divider(Center, 50)

-- Animated constellation backdrop behind the groups
local CenterBg = new("Frame", {
    Position = UDim2.fromOffset(0, 51), Size = UDim2.new(1, 0, 1, -51),
    BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 1, Parent = Center,
})
local Pages = new("Frame", {
    Position = UDim2.fromOffset(0, 51), Size = UDim2.new(1, 0, 1, -51),
    BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Parent = Center,
})

local BG_N, BG_L, BG_D = 12, 36, 190
local BgNodes, BgLines = {}, {}
for i = 1, BG_N do
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = CenterBg,
    }, { corner(3) })
    local a = rnd(0, TAU)
    BgNodes[i] = { dot = dot, x = rnd(0, 1), y = rnd(0, 1), vx = math.cos(a) * rnd(0.01, 0.03), vy = math.sin(a) * rnd(0.01, 0.03) }
end
for i = 1, BG_L do
    BgLines[i] = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE, BorderSizePixel = 0,
        Visible = false, Parent = CenterBg,
    })
end
local function stepBackdrop(dt)
    local size = CenterBg.AbsoluteSize
    if size.X < 1 then return end
    for _, n in ipairs(BgNodes) do
        n.x += n.vx * dt
        n.y += n.vy * dt
        if n.x < 0 or n.x > 1 then n.vx = -n.vx n.x = math.clamp(n.x, 0, 1) end
        if n.y < 0 or n.y > 1 then n.vy = -n.vy n.y = math.clamp(n.y, 0, 1) end
        n.px, n.py = n.x * size.X, n.y * size.Y
        n.dot.Position = UDim2.fromOffset(n.px, n.py)
    end
    local k = 0
    for i = 1, BG_N - 1 do
        local a = BgNodes[i]
        for j = i + 1, BG_N do
            if k >= BG_L then break end
            local b = BgNodes[j]
            local dx, dy = b.px - a.px, b.py - a.py
            local d = math.sqrt(dx * dx + dy * dy)
            if d < BG_D then
                k += 1
                local l = BgLines[k]
                l.Visible = true
                l.Size = UDim2.fromOffset(d, 1)
                l.Position = UDim2.fromOffset((a.px + b.px) / 2, (a.py + b.py) / 2)
                l.Rotation = math.deg(math.atan2(dy, dx))
                l.BackgroundTransparency = 0.3 + 0.7 * (d / BG_D)
            end
        end
    end
    for i = k + 1, BG_L do
        if BgLines[i].Visible then BgLines[i].Visible = false end
    end
end

---------------------------------------------------------------- player preview
local RightHead = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, Parent = Right })
new("TextLabel", {
    Text = LP.DisplayName, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.text,
    BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -56, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = RightHead,
})
local CloseBtn = new("TextButton", {
    Text = "✕", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.sub,
    AutoButtonColor = false, BackgroundColor3 = Theme.row, BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(26, 26),
    Parent = RightHead,
}, { corner(6) })
connect(CloseBtn.MouseEnter, function() tween(CloseBtn, 0.2, { TextColor3 = Theme.text, BackgroundTransparency = 0 }) end)
connect(CloseBtn.MouseLeave, function() tween(CloseBtn, 0.2, { TextColor3 = Theme.sub, BackgroundTransparency = 1 }) end)
Divider(Right, 50)

local Brackets = new("Frame", {
    Position = UDim2.fromOffset(26, PREVIEW_Y + 40), Size = UDim2.new(1, -52, 0, PREVIEW_H - 70),
    BackgroundTransparency = 1, Parent = Right,
})
for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
    local anchor = Vector2.new(c[1], c[2])
    for _, sz in ipairs({ UDim2.fromOffset(24, 2), UDim2.fromOffset(2, 24) }) do
        new("Frame", {
            AnchorPoint = anchor, Position = UDim2.fromScale(c[1], c[2]), Size = sz,
            BackgroundColor3 = Theme.text, BorderSizePixel = 0, Parent = Brackets,
        })
    end
end
new("TextLabel", {
    Text = "ID: " .. LP.UserId .. "   |   " .. VERSION, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.sub,
    BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(1, 0, 0, 24), Parent = Right,
})

-- The viewport lives outside the CanvasGroup and fades on its own
local Viewport = new("ViewportFrame", {
    Position = UDim2.fromOffset(RIGHT_X, GAP + PREVIEW_Y), Size = UDim2.fromOffset(RIGHT, PREVIEW_H),
    BackgroundTransparency = 1, ImageTransparency = 1,
    Ambient = Color3.fromRGB(150, 150, 160), LightColor = WHITE, LightDirection = Vector3.new(-0.4, -1, -0.7),
    ZIndex = 3, Parent = Holder,
})
local PreviewCam = new("Camera", { FieldOfView = 35, Parent = Viewport })
Viewport.CurrentCamera = PreviewCam

local Preview = { model = nil, offset = CFrame.new() }
local STRIP = {
    "LuaSourceContainer", "ParticleEmitter", "Trail", "Beam", "Light", "Highlight", "BillboardGui", "SurfaceGui",
    "Sound", "ForceField", "Decal", "Texture", "Clothing", "ShirtGraphic", "SurfaceAppearance", "BodyColors",
}
local function refreshPreview(char)
    if Preview.model then Preview.model:Destroy() Preview.model = nil end
    char = char or LP.Character
    if not char then return end
    local ok, clone = pcall(function()
        local was = char.Archivable
        char.Archivable = true
        local c = char:Clone()
        char.Archivable = was
        return c
    end)
    if not ok or not clone then return end

    for _, d in ipairs(clone:GetDescendants()) do
        if d.Parent then
            local strip = d.Name:sub(1, 3) == "BV_"
            for _, cls in ipairs(STRIP) do if strip or d:IsA(cls) then strip = true break end end
            if strip then d:Destroy() end
        end
    end
    -- White silhouette, like the reference design
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.Color = Color3.fromRGB(236, 236, 240)
            d.Material = Enum.Material.SmoothPlastic
            if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
        elseif d:IsA("SpecialMesh") then
            d.TextureId = ""
        elseif d:IsA("Humanoid") then
            d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end

    clone:PivotTo(CFrame.new())
    local box, size = clone:GetBoundingBox()
    Preview.offset = CFrame.new(-box.Position)
    clone.Parent = Viewport
    Preview.model = clone

    local half = math.rad(PreviewCam.FieldOfView / 2)
    local aspect = RIGHT / PREVIEW_H
    local distH = (size.Y / 2) / math.tan(half) * 1.2
    local distW = (math.max(size.X, size.Z) / 2) / (math.tan(half) * aspect) * 1.1
    local dist = math.max(distH, distW) + math.max(size.X, size.Z) / 2
    PreviewCam.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.04, -dist), Vector3.zero)
end
local buildPreview = refreshPreview
refreshPreview = function(char)
    local ok, err = pcall(buildPreview, char)
    if not ok then warn("[BloxVisuals] preview: " .. tostring(err)) end
end
if LP.Character then task.delay(0.5, refreshPreview, LP.Character) end
connect(LP.CharacterAdded, function(c) task.delay(1.5, function() if LP.Character == c then refreshPreview(c) end end) end)

---------------------------------------------------------------- tabs
local Tabs, currentTab = {}, nil

local function selectTab(tab)
    if currentTab == tab then return end
    currentTab = tab
    for _, t in ipairs(Tabs) do
        local on = t == tab
        t.lbl.Text = on and t.name:upper() or t.name
        t.lbl.Font = on and Enum.Font.GothamBold or Enum.Font.GothamMedium
        tween(t.lbl, 0.25, { TextColor3 = on and Theme.text or Theme.sub })
        tween(t.icon, 0.25, { TextColor3 = on and Theme.text or Theme.sub })
        tween(t.ind, 0.25, { BackgroundTransparency = on and 0 or 1 })
        t.page.Visible = on
    end
    PageTitle.Text, PageDesc.Text = tab.name, tab.desc
    PageTitle.TextTransparency, PageDesc.TextTransparency = 1, 1
    tween(PageTitle, 0.3, { TextTransparency = 0 })
    tween(PageDesc, 0.3, { TextTransparency = 0 })
    tab.page.Position = UDim2.fromOffset(0, 14)
    tween(tab.page, 0.35, { Position = UDim2.fromOffset(0, 0) })
end

local function Tab(icon, name, desc)
    local btn = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36), LayoutOrder = #Tabs + 1, Parent = TabList,
    })
    local ind = new("Frame", {
        Size = UDim2.fromOffset(3, 22), Position = UDim2.new(0, -14, 0.5, -11),
        BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = btn,
    }, { corner(2) })
    accentGrad(ind, 90)
    local ico = new("TextLabel", {
        Text = icon, Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = Theme.sub,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0, 22, 1, 0), Parent = btn,
    })
    local lbl = new("TextLabel", {
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Theme.sub,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -38, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
    })
    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.sub, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), Visible = false, Parent = Pages,
    }, {
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
            PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
        }),
    })
    local cols = {}
    for i = 1, 2 do
        cols[i] = new("Frame", {
            BackgroundTransparency = 1, Position = UDim2.new((i - 1) * 0.5, (i - 1) * 5, 0, 0),
            Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = page,
        }, { new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
    end

    local tab = { btn = btn, ind = ind, icon = ico, lbl = lbl, page = page, cols = cols, groups = {}, name = name, desc = desc }
    table.insert(Tabs, tab)
    connect(btn.MouseEnter, function()
        if currentTab ~= tab then tween(lbl, 0.2, { TextColor3 = Theme.text }) tween(ico, 0.2, { TextColor3 = Theme.text }) end
    end)
    connect(btn.MouseLeave, function()
        if currentTab ~= tab then tween(lbl, 0.2, { TextColor3 = Theme.sub }) tween(ico, 0.2, { TextColor3 = Theme.sub }) end
    end)
    connect(btn.MouseButton1Click, function() selectTab(tab) end)
    return tab
end

local order = 0
local function nextOrder() order += 1 return order end

-- Collapsible group box ("Menu ⌄", "Config ⌄" ...)
local function Group(tab, col, title, icon)
    local box = new("Frame", {
        BackgroundColor3 = Theme.group, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = nextOrder(), Parent = tab.cols[col],
    }, {
        corner(8), new("UIStroke", { Color = Theme.stroke }),
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local head = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.panel,
        Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 0, Parent = box,
    }, { corner(8), new("UIStroke", { Color = Theme.strokeHi, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
    local x = 14
    if icon then
        new("TextLabel", {
            Text = icon, Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = Theme.text,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 20, 1, 0), Parent = head,
        })
        x = 38
    end
    new("TextLabel", {
        Text = title, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Theme.text,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -(x + 36), 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
    })
    local chev = new("TextLabel", {
        Text = "›", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.text, Rotation = 90,
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(16, 16), Parent = head,
    })
    local body = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1, Parent = box,
    }, {
        new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        }),
    })
    local g = { box = box, body = body, rows = {}, title = title:lower(), open = true }
    connect(head.MouseButton1Click, function()
        g.open = not g.open
        body.Visible = g.open
        tween(chev, 0.2, { Rotation = g.open and 90 or 0 })
    end)
    table.insert(tab.groups, g)
    return g
end

local function Row(g, o)
    local row = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.row,
        BackgroundTransparency = o.filled and 0 or 1,
        Size = UDim2.new(1, 0, 0, o.height or 34), LayoutOrder = #g.rows + 1, Parent = g.body,
    }, { corner(6) })
    local x = 10
    if o.icon then
        new("TextLabel", {
            Text = o.icon, Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = Theme.sub,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 20, 1, 0), Parent = row,
        })
        x = 34
    end
    local lbl
    if o.title then
        lbl = new("TextLabel", {
            Text = o.title, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = o.color or Theme.text,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -(x + (o.rightPad or 36)), 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
    end
    connect(row.MouseEnter, function()
        tween(row, 0.15, { BackgroundTransparency = 0, BackgroundColor3 = o.filled and Theme.hover or Theme.row })
    end)
    connect(row.MouseLeave, function()
        tween(row, 0.15, { BackgroundTransparency = o.filled and 0 or 1, BackgroundColor3 = Theme.row })
    end)
    table.insert(g.rows, { row = row, key = (o.key or o.title or ""):lower() })
    return row, lbl
end

local function Toggle(g, title, default, callback, icon)
    local row, lbl = Row(g, { title = title, icon = icon })
    local box = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Theme.accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = row,
    }, { corner(4) })
    local boxStroke = new("UIStroke", { Color = Theme.strokeHi, Thickness = 1.5, Parent = box })
    local check = new("TextLabel", {
        Text = "✓", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.ink,
        BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = box,
    })

    local on = default
    local function render(instant)
        local t = instant and 0 or 0.2
        tween(box, t, { BackgroundTransparency = on and 0 or 1, BackgroundColor3 = Theme.accent })
        tween(boxStroke, t, { Color = on and Theme.accent or Theme.strokeHi })
        tween(check, t, { TextTransparency = on and 0 or 1 })
        tween(lbl, t, { TextColor3 = on and Theme.text or Theme.sub })
    end
    onAccent(function() render(true) end)
    local function set(v)
        v = v == true
        if v == on then return end
        on = v
        render()
        callback(v)
    end
    connect(row.MouseButton1Click, function()
        set(not on)
        notify(title, on and "Enabled" or "Disabled", on)
    end)
    Config.register(title, function() return on end, set)
    if default then callback(true) end
    return { set = set }
end

local function Button(g, title, callback, icon)
    local row = Row(g, { title = title, icon = icon, filled = true })
    new("TextLabel", {
        Text = "›", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.sub,
        BackgroundTransparency = 1, Position = UDim2.new(1, -26, 0, 0), Size = UDim2.new(0, 16, 1, 0), Parent = row,
    })
    connect(row.MouseButton1Click, callback)
    return row
end

local function SelectList(g, items, onSelect, initial)
    local entries, selected = {}, initial
    local function refresh()
        for value, e in pairs(entries) do
            local on = value == selected
            tween(e.lbl, 0.2, { TextColor3 = on and Theme.text or Theme.sub })
            tween(e.dot, 0.2, { BackgroundColor3 = on and Theme.accent or Theme.off })
        end
    end
    for _, it in ipairs(items) do
        local row, lbl = Row(g, { title = it.title, icon = it.icon })
        local dot = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Theme.off, BorderSizePixel = 0, Parent = row,
        }, { corner(4) })
        entries[it.value] = { lbl = lbl, dot = dot }
        connect(row.MouseButton1Click, function()
            selected = it.value
            refresh()
            onSelect(it.value, it)
        end)
    end
    onAccent(refresh)
    return { set = function(v) selected = v refresh() end }
end

local function Slider(g, title, min, max, default, callback, suffix)
    local row = Row(g, { key = title, height = 46 })
    new("TextLabel", {
        Text = title, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.text,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -64, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
    local valueLbl = new("TextLabel", {
        Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.accent,
        BackgroundTransparency = 1, Position = UDim2.new(1, -60, 0, 6), Size = UDim2.new(0, 50, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })
    onAccent(function() valueLbl.TextColor3 = Theme.accent end)
    local bar = new("Frame", {
        Size = UDim2.new(1, -20, 0, 3), Position = UDim2.fromOffset(10, 32),
        BackgroundColor3 = Theme.off, BorderSizePixel = 0, Parent = row,
    }, { corner(2) })
    local fill = new("Frame", {
        Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bar,
    }, { corner(2) })
    accentGrad(fill)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = bar,
    }, { corner(5) })

    local dragging, value = false, default
    local function set(v)
        v = math.clamp(math.floor(v + 0.5), min, max)
        value = v
        local a = (v - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.fromScale(a, 0.5)
        valueLbl.Text = tostring(v) .. (suffix or "")
        callback(v)
    end
    local function fromInput(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        set(min + (max - min) * a)
    end
    connect(row.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            tween(knob, 0.15, { Size = UDim2.fromOffset(13, 13) })
            fromInput(i.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            tween(knob, 0.15, { Size = UDim2.fromOffset(10, 10) })
        end
    end)
    connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromInput(i.Position.X)
        end
    end)
    Config.register(title, function() return value end, function(v)
        if type(v) == "number" then set(v) end
    end)
    set(default)
    return { set = set }
end

-- Text field: title on top, box underneath; fires on Enter
local function Input(g, title, placeholder, callback, default)
    local row = Row(g, { key = title, height = 58 })
    new("TextLabel", {
        Text = title, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.text,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })
    local box = new("TextBox", {
        Text = default or "", PlaceholderText = placeholder, PlaceholderColor3 = Theme.sub, ClearTextOnFocus = false,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.text, BackgroundColor3 = Theme.hover,
        Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 24), ClipsDescendants = true,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    }, { corner(6), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
    connect(box.FocusLost, function(enter) if enter then callback(box.Text) end end)
    return box
end

-- Key binder: "Main Keybind  [⌨ | Insert]"
local bindListener
local function Keybind(g, title)
    local row = Row(g, { title = title, color = Theme.sub, rightPad = 110 })
    local pill = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.hover, BorderSizePixel = 0, Parent = row,
    }, {
        corner(6),
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local iconCell = new("Frame", {
        Size = UDim2.fromOffset(30, 28), BackgroundColor3 = Theme.row, BorderSizePixel = 0, LayoutOrder = 1, Parent = pill,
    }, { corner(6) })
    local kb = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 10),
        BackgroundTransparency = 1, Parent = iconCell,
    }, { corner(2), new("UIStroke", { Color = Theme.sub, Thickness = 1.5 }) })
    new("Frame", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(6, 1.5),
        BackgroundColor3 = Theme.sub, BorderSizePixel = 0, Parent = kb,
    })
    local keyLbl = new("TextLabel", {
        Text = MENU_KEY.Name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.text,
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        LayoutOrder = 2, Parent = pill,
    }, { new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })

    connect(row.MouseButton1Click, function()
        keyLbl.Text = "..."
        bindListener = function(kc)
            if kc then
                MENU_KEY = kc
                notify("Keybind", "Menu key: " .. kc.Name)
            end
            keyLbl.Text = MENU_KEY.Name
        end
    end)
    Config.register(title, function() return MENU_KEY.Name end, function(v)
        local ok, kc = pcall(function() return Enum.KeyCode[v] end)
        if ok and kc then
            MENU_KEY = kc
            keyLbl.Text = kc.Name
        end
    end)
end

-- Row of square icon buttons ("Hotkeys" style) with a hint line
local function IconButtons(g, items)
    local keys = {}
    for _, it in ipairs(items) do table.insert(keys, it.title) end
    local holder = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), LayoutOrder = #g.rows + 1, Parent = g.body,
    })
    local strip = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = holder,
    }, {
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local hint = new("TextLabel", {
        Text = "Hover an action", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.sub,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 44), Size = UDim2.new(1, -4, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = holder,
    })
    local n = #items
    for i, it in ipairs(items) do
        local b = new("TextButton", {
            Text = it.glyph, Font = Enum.Font.GothamMedium, TextSize = 17, TextColor3 = Theme.text,
            AutoButtonColor = false, BackgroundColor3 = Theme.row,
            Size = UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), LayoutOrder = i, Parent = strip,
        }, { corner(6) })
        connect(b.MouseEnter, function()
            tween(b, 0.15, { BackgroundColor3 = Theme.hover })
            hint.Text = it.title
        end)
        connect(b.MouseLeave, function()
            tween(b, 0.15, { BackgroundColor3 = Theme.row })
            hint.Text = "Hover an action"
        end)
        connect(b.MouseButton1Click, it.callback)
    end
    table.insert(g.rows, { row = holder, key = table.concat(keys, " "):lower() })
end

-- Search: filters rows / groups by name; jumps to the first tab with matches
local function applySearch(q)
    q = q:lower():gsub("^%s+", ""):gsub("%s+$", "")
    local firstHit
    for _, tab in ipairs(Tabs) do
        local tabHit = false
        for _, g in ipairs(tab.groups) do
            local groupMatch = q == "" or g.title:find(q, 1, true) ~= nil
            local any = false
            for _, r in ipairs(g.rows) do
                local m = groupMatch or r.key:find(q, 1, true) ~= nil
                r.row.Visible = m
                any = any or m
            end
            g.box.Visible = any or groupMatch
            tabHit = tabHit or g.box.Visible
        end
        if tabHit and not firstHit then firstHit = tab end
        tab.hit = tabHit
    end
    if q ~= "" and currentTab and not currentTab.hit and firstHit then selectTab(firstHit) end
end
connect(SearchBox:GetPropertyChangedSignal("Text"), function() applySearch(SearchBox.Text) end)

---------------------------------------------------------------- watermark
local Water = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
    Size = UDim2.fromOffset(260, 30), BackgroundColor3 = Theme.panel, BackgroundTransparency = 0.05,
    BorderSizePixel = 0, Parent = Screen,
}, { corner(8), new("UIStroke", { Color = Theme.stroke }) })
local WaterLine = new("Frame", {
    Size = UDim2.new(1, -16, 0, 2), Position = UDim2.fromOffset(8, 0),
    BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = Water,
}, { corner(1) })
accentGrad(WaterLine)

local WaterRow = new("Frame", {
    Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
    BackgroundTransparency = 1, Parent = Water,
}, {
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    }),
    new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 12) }),
})
connect(WaterRow:GetPropertyChangedSignal("AbsoluteSize"), function()
    Water.Size = UDim2.fromOffset(WaterRow.AbsoluteSize.X, 30)
end)

local function wlabel(text, lo, color, font)
    return new("TextLabel", {
        Text = text, Font = font or Enum.Font.GothamBold, TextSize = 13, TextColor3 = color or Theme.text,
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        RichText = true, LayoutOrder = lo, Parent = WaterRow,
    })
end
new("ImageLabel", {
    Image = LOGO, ScaleType = Enum.ScaleType.Crop, BackgroundColor3 = Theme.row,
    Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = WaterRow,
}, { corner(5) })
accentGrad(wlabel("BloxVisuals", 2, WHITE, Enum.Font.GothamBlack))
wlabel("|", 3, Theme.stroke, Enum.Font.Gotham)
local WFps  = wlabel("— fps", 4)
wlabel("|", 5, Theme.stroke, Enum.Font.Gotham)
local WPing = wlabel("— ms", 6)
wlabel("|", 7, Theme.stroke, Enum.Font.Gotham)
local WTime = wlabel(os.date("%H:%M"), 8, Theme.sub, Enum.Font.GothamMedium)

---------------------------------------------------------------- pages
do
local PAtmos = Tab("◐", "Atmosphere", "World lighting presets")
local PSky   = Tab("☁", "Sky",        "Skies, clouds and time of day")
local PFx    = Tab("✦", "Effects",    "Image post-processing")
local PChar  = Tab("♟", "Character",  "Auras, trail and accessories")
local PWorld = Tab("❄", "World",      "Particles, streaks, sakura, constellations")
local PSet   = Tab("⚙", "Settings",   "Menu, camera and accent")

local gPresets = Group(PAtmos, 1, "Presets")
local presetList = SelectList(gPresets, {
    { title = "Neon Night",  value = "Neon Night" },
    { title = "Sunset",      value = "Sunset" },
    { title = "Ocean Dream", value = "Ocean Dream" },
    { title = "Sakura",      value = "Sakura" },
}, function(name)
    State.preset = name
    applyPreset(Presets[name])
    notify("Atmosphere", "Preset: " .. name)
end)
local function resetLighting()
    restoreLighting()
    presetList.set(nil)
    notify("Atmosphere", "Lighting reset", false)
end
Config.register("Atmosphere Preset", function() return State.preset or false end, function(v)
    if Presets[v] then
        State.preset = v
        applyPreset(Presets[v])
        presetList.set(v)
    elseif State.preset then
        restoreLighting()
        presetList.set(nil)
    end
end)
local gLight = Group(PAtmos, 2, "Lighting")
Button(gLight, "Default Lighting", resetLighting, "↺")

local gSkies = Group(PSky, 1, "Skies")
local skyItems = {}
for _, name in ipairs({ "Clear Sky", "Dreamy Pink", "Starry Night", "Aurora", "Blood Moon", "Thunderstorm" }) do
    if SkyPresets[name] then table.insert(skyItems, { title = name, value = name }) end
end
local skyList = SelectList(gSkies, skyItems, function(name)
    applySky(name)
    notify("Sky", "Sky: " .. name)
end)
local gSkyMisc = Group(PSky, 2, "Skybox")
local skyIdBox = Input(gSkyMisc, "Custom Skybox ID", "Paste decal / image id, Enter", function(text)
    local id = text:match("%d+")
    if not id then notify("Sky", "Enter a numeric asset id", false) return end
    applySkyboxId(id)
    skyList.set(nil)
    notify("Sky", "Custom skybox: " .. id)
end)
Slider(gSkyMisc, "Sky Rotation", 0, 20, 0, function(v) State.skySpin = v end, "°/s")
Button(gSkyMisc, "Default Sky", function()
    restoreSky()
    skyList.set(nil)
    notify("Sky", "Sky reset", false)
end, "↺")
-- the id is registered first so a saved "Custom" sky can be re-applied right after it
Config.register("Custom Skybox ID", function() return State.skyboxId or false end, function(v)
    State.skyboxId = v and tostring(v):match("%d+") or nil
    skyIdBox.Text = State.skyboxId or ""
end)
Config.register("Sky", function() return State.sky or false end, function(v)
    if v == "Custom" and State.skyboxId then
        applySkyboxId(State.skyboxId)
        skyList.set(nil)
    elseif SkyPresets[v] then
        applySky(v)
        skyList.set(v)
    elseif State.sky then
        restoreSky()
        skyList.set(nil)
    end
end)
local gTime = Group(PSky, 2, "Time of Day")
Toggle(gTime, "Lock Time", false, function(v)
    State.clockLock = v
    if not v and not State.preset then Lighting.ClockTime = Original.ClockTime end
end)
Slider(gTime, "Time", 0, 24, 14, function(v) State.clock = v end, ":00")

local gPost = Group(PFx, 1, "Post-processing")
Toggle(gPost, "Bloom", false, function(v) Bloom.Enabled = v end)
Toggle(gPost, "Sun Rays", false, function(v) Rays.Enabled = v end)
Toggle(gPost, "Cinematic Blur", false, function(v) DoF.Enabled = v end)
local gTune = Group(PFx, 2, "Tuning")
Slider(gTune, "Bloom Intensity", 1, 30, 12, function(v) Bloom.Intensity = v / 10 end)

local gAuras = Group(PChar, 1, "Auras")
local auraList = SelectList(gAuras, {
    { title = "None",            value = "none" },
    { title = "Rainbow Sparkle", value = "rainbow" },
    { title = "Fire",            value = "fire" },
    { title = "Lightning",       value = "lightning" },
    { title = "Galaxy Orbit",    value = "galaxy" },
    { title = "Spiral",          value = "spiral" },
    { title = "Void",            value = "void" },
}, function(v, it)
    setAura(v ~= "none" and v or nil)
    notify("Aura", v ~= "none" and it.title or "Disabled", v ~= "none")
end, "none")
Config.register("Aura", function() return State.aura or "none" end, function(v)
    if v ~= "none" and not AuraBuilders[v] then return end
    auraList.set(v)
    v = v ~= "none" and v or nil
    if v ~= State.aura then setAura(v) end
end)
Toggle(gAuras, "Rainbow Colors", true, function(v) State.auraRainbow = v end)
Slider(gAuras, "Aura Size", 5, 20, 10, function(v)
    if State.auraSize ~= v / 10 then
        State.auraSize = v / 10
        rebuildAuraSoon()
    end
end, "0%")

local gCharFx = Group(PChar, 1, "Character FX")
Toggle(gCharFx, "Rainbow Trail", false, function(v)
    State.trail = v
    if CharFX.trail then CharFX.trail.Enabled = v end
end)
Toggle(gCharFx, "Glowing Outline", false, function(v)
    State.outline = v
    if CharFX.outline then CharFX.outline.Enabled = v end
end)
local gRainbow = Group(PChar, 1, "Rainbow")
Slider(gRainbow, "Rainbow Speed", 1, 50, 15, function(v) State.rainbowSpeed = v / 100 end)
local gAcc = Group(PChar, 2, "Accessories")
Toggle(gAcc, "Angel Wings", false, function(v) Acc.set("wings", v) end)
Toggle(gAcc, "China Hat", false, function(v) Acc.set("hat", v) end)
Toggle(gAcc, "Halo", false, function(v) Acc.set("halo", v) end)
Toggle(gAcc, "Nova Step", false, function(v) World.set("novaStep", v) end)
Toggle(gAcc, "Rainbow Accessories", true, function(v) State.accRainbow = v end)
local wingRebuild = 0
Slider(gAcc, "Wing Size", 6, 15, 10, function(v)
    if State.wingSize == v / 10 then return end
    State.wingSize = v / 10
    wingRebuild += 1
    local id = wingRebuild
    task.delay(0.25, function() if id == wingRebuild then Acc.build("wings") end end)
end, "0%")

local gParticles = Group(PWorld, 1, "Particles")
Toggle(gParticles, "Falling Sparks", false, function(v) World.set("sparks", v) end)
Slider(gParticles, "Spark Density", 1, 3, 2, function(v) State.sparkDensity = v end, "x")
Toggle(gParticles, "Snowflakes", false, function(v) World.set("snowflakes", v) end)
Toggle(gParticles, "Sakura Petals", false, function(v) World.set("sakura", v) end)
local gStreaks = Group(PWorld, 2, "Streaks")
Toggle(gStreaks, "Wind Streaks", false, function(v) World.set("streaks", v) end)
Toggle(gStreaks, "Rainbow Streaks", false, function(v) State.streakRainbow = v end)
local gStars = Group(PWorld, 2, "Constellations")
Toggle(gStars, "Constellations", false, function(v) World.set("constellations", v) end)
Slider(gStars, "Link Distance", 8, 30, 16, function(v) State.linkDist = v end)
Slider(gStars, "Star Density", 1, 3, 2, function(v) State.starDensity = v end, "x")
Toggle(gStars, "Rainbow Stars", false, function(v) State.starRainbow = v end)

local gMenu = Group(PSet, 1, "Menu")
Keybind(gMenu, "Main Keybind")
Toggle(gMenu, "Watermark", true, function(v)
    State.hud = v
    Water.Visible = v
end)
Toggle(gMenu, "Notifications", true, function(v) State.notify = v end)
Toggle(gMenu, "Menu Blur", true, function(v)
    State.menuBlur = v
    tween(MenuBlur, 0.25, { Size = v and Holder.Visible and 12 or 0 })
end)
Button(gMenu, "Unload", function() cleanup() end, "⏏")

local gCam = Group(PSet, 1, "Camera")
local fovSlider = Slider(gCam, "Field of View", 50, 120, math.floor(Original.FieldOfView + 0.5), function(v)
    Camera.FieldOfView = v
end, "°")

local gAccent = Group(PSet, 2, "Accent", "⚙")
local themeItems = {}
for i, t in ipairs(Themes) do
    table.insert(themeItems, { title = t.name, value = i })
end
local themeList = SelectList(gAccent, themeItems, function(i)
    State.theme = Themes[i].name
    setTheme(Themes[i])
    notify("Accent", "Active: " .. Themes[i].name)
end, 1)
Config.register("Accent", function() return State.theme end, function(v)
    for i, t in ipairs(Themes) do
        if t.name == v then
            State.theme = v
            setTheme(t)
            themeList.set(i)
        end
    end
end)

local gHot = Group(PSet, 2, "Hotkeys")
IconButtons(gHot, {
    { glyph = "↺", title = "Reset lighting", callback = resetLighting },
    { glyph = "◎", title = "Reset FOV", callback = function()
        fovSlider.set(math.floor(Original.FieldOfView + 0.5))
        notify("Camera", "FOV reset", false)
    end },
    { glyph = "↻", title = "Refresh preview", callback = function() refreshPreview() end },
    { glyph = "✕", title = "Unload script", callback = function() cleanup() end },
})
end -- pages

---------------------------------------------------------------- configs page
do
local PCfg = Tab("▤", "Configs", "Save, load and share your setup")
local gCfg   = Group(PCfg, 1, "Config")
local gShare = Group(PCfg, 1, "Share")
local gSaved = Group(PCfg, 2, "Saved Configs")
local nameBox, refreshSaved
local selected, pendingDelete, pendingAt = nil, nil, 0

local function needFS()
    if Config.fs then return true end
    notify("Config", "Executor has no file functions", false)
end

local function currentName()
    local n = Config.clean(nameBox.Text)
    if n == "" then notify("Config", "Enter a config name", false) return end
    return n
end

local function saveConfig()
    if not needFS() then return end
    local n = currentName()
    if not n then return end
    local ok, err = pcall(Config.save, n)
    if not ok then
        warn("[BloxVisuals] config save: " .. tostring(err))
        notify("Config", "Save failed", false)
        return
    end
    selected, nameBox.Text = n, n
    refreshSaved()
    notify("Config", "Saved: " .. n)
end

local function loadConfig()
    if not needFS() then return end
    local n = currentName()
    if not n then return end
    local ok, res = pcall(Config.load, n)
    if not (ok and res) then notify("Config", "Can't load: " .. n, false) return end
    selected = n
    refreshSaved()
    notify("Config", "Loaded: " .. n)
end

local function deleteConfig()
    if not needFS() then return end
    local n = currentName()
    if not n then return end
    if not Config.exists(n) then notify("Config", "No config named " .. n, false) return end
    -- a second click within 3 s confirms
    if pendingDelete ~= n or tick() - pendingAt > 3 then
        pendingDelete, pendingAt = n, tick()
        notify("Config", "Click Delete again to remove " .. n, false)
        return
    end
    pendingDelete = nil
    local ok, res = pcall(Config.delete, n)
    if not (ok and res) then notify("Config", "Delete failed", false) return end
    if selected == n then selected = nil end
    nameBox.Text = ""
    refreshSaved()
    notify("Config", "Deleted: " .. n, false)
end

local function setAutoload()
    if not needFS() then return end
    local n = currentName()
    if not n then return end
    if not Config.exists(n) then notify("Config", "Save " .. n .. " first", false) return end
    pcall(Config.setAuto, n)
    refreshSaved()
    notify("Config", "Autoload: " .. n)
end

nameBox = Input(gCfg, "Config Name", "Type a name, Enter to save", saveConfig)
Button(gCfg, "Save", saveConfig, "↑")
Button(gCfg, "Load", loadConfig, "↓")
Button(gCfg, "Delete", deleteConfig, "✕")
Button(gCfg, "Set Autoload", setAutoload, "★")
Button(gCfg, "Clear Autoload", function()
    if not needFS() then return end
    pcall(Config.setAuto, nil)
    refreshSaved()
    notify("Config", "Autoload cleared", false)
end, "☆")
Button(gCfg, "Refresh List", function() refreshSaved() end, "↻")
Button(gCfg, "Reset to Defaults", function()
    Config.apply(Config.defaults)
    notify("Config", "Defaults restored", false)
end, "↺")

Button(gShare, "Copy to Clipboard", function()
    local clip = setclipboard or toclipboard
    if not clip then notify("Config", "Clipboard not supported", false) return end
    clip(Config.encode())
    notify("Config", "Copied to clipboard")
end, "⎘")
Input(gShare, "Import Config", "Paste config text, Enter", function(text)
    if Config.apply(Config.decode(text)) then
        notify("Config", "Imported")
    else
        notify("Config", "Invalid config text", false)
    end
end)

-- The saved list is rebuilt from disk; its rows are the only rows of gSaved, so they are dropped wholesale
local savedRows = {}
refreshSaved = function()
    for _, r in ipairs(savedRows) do r:Destroy() end
    savedRows, gSaved.rows = {}, {}
    local names = Config.list()
    if #names == 0 then
        local row = Row(gSaved, {
            title = Config.fs and "No saved configs" or "Executor has no file functions",
            color = Theme.sub, rightPad = 10,
        })
        table.insert(savedRows, row)
        return
    end
    local auto = Config.getAuto()
    for _, n in ipairs(names) do
        local on = n == selected
        local row = Row(gSaved, { title = n, icon = n == auto and "★" or "▤", color = on and Theme.text or Theme.sub })
        new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = on and Theme.accent or Theme.off, BorderSizePixel = 0, Parent = row,
        }, { corner(4) })
        connect(row.MouseButton1Click, function()
            selected = n
            nameBox.Text = n
            refreshSaved()
        end)
        table.insert(savedRows, row)
    end
end

-- Defaults are captured before the autoload, so "Reset to Defaults" always means a clean start
Config.defaults = Config.snapshot()
local auto = Config.getAuto()
if auto then
    local ok, res = pcall(Config.load, auto)
    if ok and res then
        selected, nameBox.Text = auto, auto
        notify("Config", "Autoloaded: " .. auto)
    end
end
refreshSaved()
end -- configs page

selectTab(Tabs[1])

---------------------------------------------------------------- drag / toggle
do
    local dragging, startPos, startInput
    local function begin(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, Holder.Position, i.Position
        end
    end
    connect(Brand.InputBegan, begin)
    connect(TopBar.InputBegan, begin)
    connect(RightHead.InputBegan, begin)
    connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            tween(Holder, 0.08, {
                Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y),
            })
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function setMenu(v)
    visible = v
    if v then
        Holder.Visible = true
        tween(Main, 0.3, { GroupTransparency = 0 })
        tween(Viewport, 0.3, { ImageTransparency = 0 })
        tween(WinScale, 0.4, { Scale = baseScale }, Enum.EasingStyle.Back)
        tween(Shadow, 0.3, { ImageTransparency = 0.35 })
        tween(OutlineStroke, 0.3, { Transparency = 0 })
        if State.menuBlur then tween(MenuBlur, 0.3, { Size = 12 }) end
    else
        SearchBox:ReleaseFocus()
        tween(Main, 0.22, { GroupTransparency = 1 })
        tween(Viewport, 0.22, { ImageTransparency = 1 })
        tween(WinScale, 0.22, { Scale = baseScale * 0.94 })
        tween(Shadow, 0.22, { ImageTransparency = 1 })
        tween(OutlineStroke, 0.22, { Transparency = 1 })
        tween(MenuBlur, 0.22, { Size = 0 })
        task.delay(0.22, function() if not visible then Holder.Visible = false end end)
    end
end

connect(UserInputService.InputBegan, function(i)
    if bindListener then
        if i.UserInputType == Enum.UserInputType.Keyboard then
            local fn = bindListener
            bindListener = nil
            fn(i.KeyCode ~= Enum.KeyCode.Escape and i.KeyCode or nil)
        end
        return
    end
    if i.KeyCode ~= MENU_KEY or UserInputService:GetFocusedTextBox() then return end
    setMenu(not visible)
end)
connect(CloseBtn.MouseButton1Click, function() setMenu(false) end)

WinScale.Scale = baseScale * 0.92
setMenu(true)
notify("Blox Visuals", "Loaded · " .. MENU_KEY.Name .. " to open / close")

local frames, fps, lastFps = 0, 0, tick()
local skySpinOK = pcall(function() return BVSky.SkyboxOrientation end)

connect(RunService.RenderStepped, function(dt)
    local h = hue()
    local now = tick()
    Acc.step(dt, now)
    World.step(dt, now)

    if visible then
        stepBackdrop(dt)
        if Preview.model and Preview.model.Parent then
            Preview.model:PivotTo(CFrame.Angles(0, now * 0.5, 0) * Preview.offset)
        end
    end

    local flow = Vector2.new(math.sin(tick() * 1.4) * 0.5, 0)
    for _, g in ipairs(accentGrads) do g.Offset = flow end

    local seq = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromHSV(h, 0.8, 1)),
        ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h + 0.33) % 1, 0.8, 1)),
        ColorSequenceKeypoint.new(1,   Color3.fromHSV((h + 0.66) % 1, 0.8, 1)),
    })

    Aura.step(dt, now)

    if State.sky and State.skySpin > 0 and skySpinOK then
        BVSky.SkyboxOrientation = Vector3.new(0, (now * State.skySpin) % 360, 0)
    end

    if CharFX.trail and State.trail then
        CharFX.trail.Color = seq
    end
    if CharFX.outline and State.outline then
        CharFX.outline.OutlineColor = rainbow()
        CharFX.outline.FillColor = rainbow(0.5)
    end

    frames += 1
    if tick() - lastFps >= 0.5 then
        fps = math.floor(frames / (tick() - lastFps) + 0.5)
        frames, lastFps = 0, tick()
        if State.hud then
            local ping = 0
            pcall(function() ping = math.floor(LP:GetNetworkPing() * 1000 + 0.5) end)
            local fpsCol  = fps >= 50 and "#7CFFB2" or fps >= 30 and "#FFD36E" or "#FF6E6E"
            local pingCol = ping <= 100 and "#7CFFB2" or ping <= 200 and "#FFD36E" or "#FF6E6E"
            WFps.Text  = string.format('<font color="%s">%d</font> fps', fpsCol, fps)
            WPing.Text = string.format('<font color="%s">%d</font> ms', pingCol, ping)
            WTime.Text = os.date("%H:%M")
        end
    end
end)

cleanup = function()
    bindListener = nil
    pcall(function() RunService:UnbindFromRenderStep("BV_HoldPreset") end)
    restoreLighting()
    State.clockLock = false
    restoreSky()
    Camera.FieldOfView = Original.FieldOfView
    for _, c in ipairs(connections) do c:Disconnect() end
    clearCharFX()
    Acc.clear()
    World.clear()
    Aura.clear()
    for _, o in ipairs(created) do pcall(function() o:Destroy() end) end
    if getgenv and getgenv().BloxVisualsCleanup == cleanup then getgenv().BloxVisualsCleanup = nil end
end
if getgenv then getgenv().BloxVisualsCleanup = cleanup end

print("✦ Blox Visuals " .. VERSION .. " loaded — press " .. MENU_KEY.Name .. " to open / close the menu")
