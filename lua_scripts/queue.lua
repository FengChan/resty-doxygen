-- queue.lua
local cjson = require("cjson.safe")
local queue_store = ngx.shared.build_queue

local _M = {}

function _M.enqueue(key, item)
    local q_raw = queue_store:get(key)
    local q = q_raw and cjson.decode(q_raw) or {}
    table.insert(q, item)
    queue_store:set(key, cjson.encode(q))
end

function _M.dequeue(key)
    local q_raw = queue_store:get(key)
    if not q_raw then return nil end

    local q = cjson.decode(q_raw)
    if not q or #q == 0 then return nil end

    local item = table.remove(q, 1)
    queue_store:set(key, cjson.encode(q))
    return item
end

function _M.peek(key)
    local q_raw = queue_store:get(key)
    return q_raw and cjson.decode(q_raw) or {}
end

return _M
