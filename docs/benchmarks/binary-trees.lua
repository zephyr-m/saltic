local function make(d) if d == 0 then return {} end return {make(d - 1), make(d - 1)} end
local function check(t) if t[1] == nil then return 1 end return 1 + check(t[1]) + check(t[2]) end
local top, low = 16, 4
print("stretch tree of depth " .. top + 1 .. " check: " .. check(make(top + 1)))
local lng = make(top)
for d = low, top, 2 do local it = 1 << (top - d + low); local s = 0; for i = 1, it do s = s + check(make(d)) end; print(it .. " trees of depth " .. d .. " check: " .. s) end
print("long lived tree of depth " .. top .. " check: " .. check(lng))
