local grid = {}
local ranges = {}

local function range_for(id)
    for _, range in ipairs(ranges) do
        if id >= range.first and id <= range.first + 8 then return range end
    end
    return nil
end

local function active_target(column_delta, row_delta)
    local workspace = hl.get_active_workspace()
    if not workspace then return nil end
    local range = range_for(workspace.id)
    if not range then return nil end
    local slot = workspace.id - range.first
    local column = slot % 3
    local row = math.floor(slot / 3)
    local target_column = column + column_delta
    local target_row = row + row_delta
    if target_column < 0 or target_column > 2 or target_row < 0 or target_row > 2 then return nil end
    return range.first + target_row * 3 + target_column
end

local function local_target(slot)
    local workspace = hl.get_active_workspace()
    if not workspace then return nil end
    local range = range_for(workspace.id)
    if not range then return nil end
    return range.first + slot - 1
end

local function focus(target)
    if target then hl.dispatch(hl.dsp.focus({ workspace = tostring(target) })) end
end

local function move(target)
    if target then hl.dispatch(hl.dsp.window.move({ workspace = tostring(target) })) end
end

local function gesture(column_delta, row_delta)
    return function() focus(active_target(column_delta, row_delta)) end
end

function grid.setup(specs)
    assert(#ranges == 0, "workspace grid is already configured")
    assert(type(specs) == "table" and #specs > 0, "workspace grid requires at least one monitor")
    local ids = {}
    for _, spec in ipairs(specs) do
        assert(type(spec.monitor) == "string" and spec.monitor ~= "", "workspace grid monitor must be non-empty")
        assert(type(spec.first) == "number" and spec.first > 0 and spec.first % 1 == 0, "workspace grid first ID must be a positive integer")
        local range = { monitor = spec.monitor, first = spec.first }
        for slot = 1, 9 do
            local id = range.first + slot - 1
            assert(not ids[id], "workspace grid ranges must not overlap")
            ids[id] = true
            hl.workspace_rule({
                workspace = tostring(id),
                monitor = range.monitor,
                persistent = true,
                default = slot == 1,
            })
        end
        table.insert(ranges, range)
    end

    for slot = 1, 9 do
        local target_slot = slot
        hl.bind("SUPER + " .. target_slot, function() focus(local_target(target_slot)) end)
        hl.bind("SUPER + SHIFT + " .. target_slot, function() move(local_target(target_slot)) end)
    end

    hl.gesture({ fingers = 3, direction = "left", action = gesture(1, 0) })
    hl.gesture({ fingers = 3, direction = "right", action = gesture(-1, 0) })
    hl.gesture({ fingers = 3, direction = "up", action = gesture(0, 1) })
    hl.gesture({ fingers = 3, direction = "down", action = gesture(0, -1) })
end

return grid
