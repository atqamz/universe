local root = assert(arg[1])
package.path = root .. "/?.lua;" .. package.path

local rules = {}
local gestures = {}
local binds = {}
local dispatched = {}
local active = 1

hl = {
    workspace_rule = function(spec) table.insert(rules, spec) end,
    gesture = function(spec) table.insert(gestures, spec) end,
    bind = function(keys, dispatcher) binds[keys] = dispatcher end,
    dispatch = function(dispatcher) table.insert(dispatched, dispatcher) end,
    get_active_workspace = function() return { id = active } end,
    dsp = {
        focus = function(spec) return { kind = "focus", workspace = spec.workspace } end,
        window = {
            move = function(spec) return { kind = "move", workspace = spec.workspace } end,
        },
    },
}

local grid = require("workspace_grid")
grid.setup({
    { monitor = "eDP-1", first = 1 },
    { monitor = "DP-1", first = 101 },
})

assert(#rules == 18)
assert(rules[1].workspace == "1" and rules[1].monitor == "eDP-1" and rules[1].persistent and rules[1].default)
assert(rules[9].workspace == "9" and rules[9].monitor == "eDP-1" and not rules[9].default)
assert(rules[10].workspace == "101" and rules[10].monitor == "DP-1" and rules[10].default)
assert(rules[18].workspace == "109" and rules[18].monitor == "DP-1" and not rules[18].default)

local by_direction = {}
for _, gesture in ipairs(gestures) do by_direction[gesture.direction] = gesture.action end
assert(by_direction.left and by_direction.right and by_direction.up and by_direction.down)

local function expect_gesture(direction, workspace, target)
    active = workspace
    dispatched = {}
    by_direction[direction]()
    if target then
        assert(#dispatched == 1)
        assert(dispatched[1].kind == "focus" and dispatched[1].workspace == tostring(target))
    else
        assert(#dispatched == 0)
    end
end

expect_gesture("left", 1, 2)
expect_gesture("left", 3, nil)
expect_gesture("right", 102, 101)
expect_gesture("right", 101, nil)
expect_gesture("up", 4, 7)
expect_gesture("up", 107, nil)
expect_gesture("down", 109, 106)
expect_gesture("down", 2, nil)

active = 101
dispatched = {}
binds["SUPER + 2"]()
assert(dispatched[1].kind == "focus" and dispatched[1].workspace == "102")

dispatched = {}
binds["SUPER + SHIFT + 9"]()
assert(dispatched[1].kind == "move" and dispatched[1].workspace == "109")

print("workspace grid behavior passed")
