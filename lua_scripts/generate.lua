local function run(cmd)
    local tmp = os.tmpname()
    local full_cmd = cmd .. " > " .. tmp .. " 2>&1"
    local exit_code = os.execute(full_cmd)
    local f = io.open(tmp, "r")
    local output = f:read("*a")
    f:close()
    os.remove(tmp)
    return exit_code, output
end

local function async_task(premature, repo, repo_name, repopath, outpath)
    if premature then
        return
    end

    local cmds = {
        string.format("rm -rf %s %s", repopath, outpath),
        string.format("git clone --depth=1 --single-branch %s %s", repo, repopath),
        string.format("cd %s && doxygen -g", repopath),
        string.format("sed -i 's/^[[:space:]]*PROJECT_NAME[[:space:]]*=.*/PROJECT_NAME = \"%s\"/' Doxyfile", repo_name:gsub("([\"\\])", "\\%1")),
        "sed -i 's/EXTRACT_ALL.*/EXTRACT_ALL = YES/' Doxyfile",
        "sed -i 's/GENERATE_LATEX.*/GENERATE_LATEX = NO/' Doxyfile",
        "sed -i 's/HAVE_DOT.*/HAVE_DOT = YES/' Doxyfile",
        "sed -i 's/CALL_GRAPH.*/CALL_GRAPH = YES/' Doxyfile",
        "sed -i 's/INPUT_ENCODING.*/INPUT_ENCODING = UTF-8/' Doxyfile",
        "sed -i 's/CALLER_GRAPH.*/CALLER_GRAPH = YES/' Doxyfile",
        "sed -i 's/INPUT.*/INPUT = ./' Doxyfile",
        "sed -i 's/RECURSIVE.*/RECURSIVE = YES/' Doxyfile",
        'echo "" > footer.html',
        "sed -i 's/HTML_FOOTER.*/HTML_FOOTER = footer.html/' Doxyfile",
        "sed -i 's/CLASS_DIAGRAMS.*/CLASS_DIAGRAMS = YES/' Doxyfile",
        "sed -i 's/SEARCHENGINE.*/SEARCHENGINE = NO/' Doxyfile",
        "sed -i 's/DOT_GRAPH_MAX_NODES.*/DOT_GRAPH_MAX_NODES = 100/' Doxyfile",
        "doxygen Doxyfile",
        
        string.format("mkdir -p %s", outpath),
        string.format("rm -rf %s/* && cp -r html %s/html", outpath, outpath),
        string.format("echo '' > %s/html/menu.js", outpath),
        string.format("python3 /opt/lua_scripts/replace_html.py %s/html", outpath),
        string.format("cp -r /opt/lua_scripts/doxygen.css %s/html/doxygen.css", outpath),
        string.format("cp -r /opt/lua_scripts/detail-bg.png %s/html/detail-bg.png", outpath),
    }
    local cmd = table.concat(cmds, " && \\\n")

    local code, output = run(cmd)

    -- 这里可以写日志或者做别的处理，比如把结果写文件、通知等
    ngx.log(ngx.ERR, "Background task finished with code ", code)
end

-- 主请求逻辑
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
ngx.flush(true)  -- 立即发送响应给客户端

-- 异步启动后台任务
local ok, err = ngx.timer.at(0, async_task, repo, repo_name, repopath, outpath)
if not ok then
    ngx.log(ngx.ERR, "Failed to create timer: ", err)
end

-- 主请求结束，不阻塞
return
