local M = {}

local function get_key(key)
    return "queue:" .. key
end

function M.enqueue(key, value)
    local queue = ngx.shared.build_queue:get(key)
    local list = queue and cjson.decode(queue) or {}
    table.insert(list, value)
    ngx.shared.build_queue:set(key, cjson.encode(list))
end

function M.dequeue(key)
    local queue = ngx.shared.build_queue:get(key)
    if not queue then return nil end
    local list = cjson.decode(queue)
    local next = table.remove(list, 1)
    if #list == 0 then
        ngx.shared.build_queue:delete(key)
    else
        ngx.shared.build_queue:set(key, cjson.encode(list))
    end
    return next
end

return M
