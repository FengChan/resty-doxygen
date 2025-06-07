-- 声明共享内存区域（在 nginx.conf 中 http 块加入）：
-- lua_shared_dict build_locks 10m;

local function run(cmd)
    local tmp = os.tmpname()
    local full_cmd = cmd .. " > " .. tmp .. " 2>&1"
    local ok, _, exit_code = os.execute(full_cmd)

    local f = io.open(tmp, "r")
    local output = f and f:read("*a") or ""
    if f then f:close() end
    os.remove(tmp)

    return exit_code, output
end

local function async_task(premature, args)
    if premature then return end

    local lock = ngx.shared.build_locks
    local lock_key = "build_lock:" .. args.repopath

    -- 加锁：防止多个任务并发执行
    local ok, err = lock:add(lock_key, true, 300)  -- 锁 5 分钟
    if not ok then
        ngx.log(ngx.ERR, "Another task is running for ", args.repopath)
        return
    end

    local ok, err = pcall(function()
        local repo      = args.repo
        local repo_name = args.repo_name
        local repopath  = args.repopath
        local outpath   = args.outpath

        run(string.format("mkdir -p %s %s", repopath, outpath))

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

        local cmd = table.concat(cmds, " && \\\n")
        local code, output = run(cmd)

        if code ~= 0 then
            ngx.log(ngx.ERR, "Command failed with code ", code, "\nCMD:\n", cmd, "\nOutput:\n", output)
        else
            ngx.log(ngx.ERR, "Background task finished successfully for repo ", repo)
        end
    end)

    if not ok then
        ngx.log(ngx.ERR, "Unhandled Lua error in async_task: ", err)
    end

    -- 最终释放锁
    lock:delete(lock_key)
end

-- 主请求入口
ngx.req.read_body()
local args = ngx.req.get_uri_args()
local repo = args.repo

if not repo then
    ngx.status = 400
    ngx.say("Missing 'repo' parameter. Example: /generate?repo=https://github.com/user/repo.git")
    return
end

local function parse_git_repo_url(repo_url)
    local url = repo_url
    url = url:gsub("^git@[^:/]+:", "")
    url = url:gsub("^ssh://", "")
    url = url:gsub("^https?://[^/]+/", "")
    local username = url:match("([^/]+)/") or "default_user"
    local repo_name = url:match(".*/([^/]+)$") or url
    repo_name = repo_name:gsub("%.git$", "")
    return username, repo_name
end

local user, repo_name = parse_git_repo_url(repo)
local workdir = "/opt/workspace"
local outputdir = "/opt/output"
local repopath = string.format("%s/%s/%s", workdir, user, repo_name)
local outpath  = string.format("%s/%s/%s", outputdir, user, repo_name)

ngx.say("Task accepted for repo: ", repo)
ngx.flush(true)

local ok, err = ngx.timer.at(0, async_task, {
    repo = repo,
    repo_name = repo_name,
    repopath = repopath,
    outpath = outpath
})

if not ok then
    ngx.log(ngx.ERR, "Failed to create timer: ", err)
end

return
