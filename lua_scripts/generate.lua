local cjson = require "cjson.safe"
local queue = require "queue"

local build_locks = ngx.shared.build_locks
local build_status = ngx.shared.build_status

local function run(cmd)
    local tmp = os.tmpname()
    local full_cmd = cmd .. " > " .. tmp .. " 2>&1"
    local ok, _, code = os.execute(full_cmd)

    local f = io.open(tmp, "r")
    local output = f and f:read("*a") or ""
    if f then f:close() end
    os.remove(tmp)
    return code, output
end

local function update_status(key, value)
    build_status:set(key, value, 3600)
end

local function async_task(premature, args)
    if premature then return end

    local lock_key   = "lock:" .. args.repopath
    local status_key = "status:" .. args.repopath
    local queue_key  = "queue:" .. args.repopath

    if not build_locks:add(lock_key, true, 300) then
        return
    end

    update_status(status_key, "building")

    local ok, err = pcall(function()
        -- 构建命令（你可以替换成你的构建逻辑）
        local cmds = {
            string.format("rm -rf %s %s", repopath, outpath),
            string.format("git clone --depth=1 --single-branch %s %s", repo, repopath),

            string.format("cd %s && doxygen -g", repopath),
            string.format("cd %s && sed -i 's/^[[:space:]]*PROJECT_NAME[[:space:]]*=.*/PROJECT_NAME = \"%s\"/' Doxyfile", repopath, repo_name:gsub("([\"\\])", "\\%1")),
            string.format("cd %s && sed -i 's/EXTRACT_ALL.*/EXTRACT_ALL = YES/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/GENERATE_LATEX.*/GENERATE_LATEX = NO/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/HAVE_DOT.*/HAVE_DOT = YES/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/GENERATE_XML.*/GENERATE_XML = YES/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/CALL_GRAPH.*/CALL_GRAPH = YES/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/CALLER_GRAPH.*/CALLER_GRAPH = YES/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/INPUT.*/INPUT = ./' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/RECURSIVE.*/RECURSIVE = YES/' Doxyfile", repopath),
            string.format("cd %s && echo \"\" > footer.html", repopath),
            string.format("cd %s && sed -i 's/HTML_FOOTER.*/HTML_FOOTER = footer.html/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/CLASS_DIAGRAMS.*/CLASS_DIAGRAMS = YES/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/SEARCHENGINE.*/SEARCHENGINE = NO/' Doxyfile", repopath),
            string.format("cd %s && sed -i 's/DOT_GRAPH_MAX_NODES.*/DOT_GRAPH_MAX_NODES = 100/' Doxyfile", repopath),

            string.format("cd %s && doxygen Doxyfile", repopath),

            string.format("mkdir -p %s", outpath),
            string.format("rm -rf %s/* && cp -r %s/html %s/html && cp -r %s/xml %s/xml", outpath, repopath, outpath, repopath, outpath),
            string.format("echo '' > %s/html/menu.js", outpath),
            string.format("python3 /opt/lua_scripts/replace_html.py %s/html", outpath),
            string.format("python3 /opt/lua_scripts/analyze_doxygen.py %s/xml --json %s/html/analyze_doxygen.json", outpath, outpath),
            string.format("cp /opt/lua_scripts/doxygen.css %s/html/doxygen.css", outpath),
            string.format("cp /opt/lua_scripts/detail-bg.png %s/html/detail-bg.png", outpath),
        }

        local cmd = table.concat(cmds, " && ")
        local code, output = run(cmd)

        if code ~= 0 then
            update_status(status_key, "failed")
            ngx.log(ngx.ERR, "[BUILD FAIL]", output)
        else
            update_status(status_key, "success")
        end
    end)

    if not ok then
        update_status(status_key, "failed")
        ngx.log(ngx.ERR, "Lua error: ", err)
    end

    build_locks:delete(lock_key)

    local next = queue.dequeue(queue_key)
    if next then
        ngx.timer.at(0, async_task, next)
    end
end

-- 处理请求
ngx.req.read_body()
local args = ngx.req.get_uri_args()
local repo = args.repo

if not repo then
    ngx.status = 400
    ngx.say("Missing 'repo' parameter")
    return
end

local function parse_git_repo_url(repo_url)
    local url = repo_url:gsub("^git@[^:/]+:", "")
    url = url:gsub("^ssh://", "")
    url = url:gsub("^https?://[^/]+/", "")
    local username = url:match("([^/]+)/") or "default"
    local repo_name = url:match(".*/([^/]+)$") or "repo"
    repo_name = repo_name:gsub("%.git$", "")
    return username, repo_name
end

local user, repo_name = parse_git_repo_url(repo)
local repopath = string.format("/opt/workspace/%s/%s", user, repo_name)
local outpath  = string.format("/opt/output/%s/%s", user, repo_name)

local lock_key   = "lock:" .. repopath
local status_key = "status:" .. repopath
local queue_key  = "queue:" .. repopath

local task = {
    repo = repo,
    repo_name = repo_name,
    repopath = repopath,
    outpath = outpath
}

if build_locks:get(lock_key) then
    queue.enqueue(queue_key, task)
    update_status(status_key, "pending")
    ngx.say("Build task is queued.")
else
    update_status(status_key, "pending")
    local ok, err = ngx.timer.at(0, async_task, task)
    if ok then
        ngx.say("Build started.")
    else
        update_status(status_key, "failed")
        ngx.say("Failed to schedule build: ", err)
    end
end
