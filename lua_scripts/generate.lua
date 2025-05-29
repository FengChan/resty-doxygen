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



local function parse_git_repo_url(repo_url)
    -- 去掉协议和域名部分，统一格式为 path1/path2/...
    local url = repo_url
    url = url:gsub("^git@[^:/]+:", "")     -- 处理 git@host:xxx/xxx.git
    url = url:gsub("^ssh://", "")           -- 去掉 ssh://
    url = url:gsub("^https?://[^/]+/", "") -- 去掉 http(s)://host/

    -- 提取第一个路径部分作为 username（组织名）
    local username = url:match("([^/]+)/") or "default_user"

    -- 提取 repo_name，匹配最后一个路径段，去掉可能的 .git 后缀
    local repo_name = url:match(".*/([^/]+)$") or url
    repo_name = repo_name:gsub("%.git$", "") -- 去掉 .git

    return username, repo_name
end 


ngx.req.read_body()
local args = ngx.req.get_uri_args()
local repo = args.repo

if not repo then
    ngx.status = 400
    ngx.say("Missing 'repo' parameter. Example: /generate?repo=https://github.com/user/repo.git")
    return
end

local workdir = "/opt/workspace"
local outputdir = "/opt/output"

-- 解析 repo 名称
local user, repo_name = parse_git_repo_url(repo)
local repopath = string.format("%s/%s/%s", workdir, user, repo_name)
local outpath  = string.format("%s/%s/%s", outputdir, user, repo_name)


-- 打印调试信息（可注释）
ngx.say("Repo: ", repo)
ngx.say("Repo name: ", repo_name)
ngx.say("Repopath: ", repopath)
ngx.say("Outpath: ", outpath)
ngx.say("rootpath: ", string.format("/files/%s/%s/html/", user, repo_name))


-- 构造命令
local cmd = string.format([[
    rm -rf %s %s && \
    git clone %s %s && \
    cd %s && \
    
    doxygen -g && \
    sed -i 's/EXTRACT_ALL.*/EXTRACT_ALL = YES/' Doxyfile && \
    sed -i 's/GENERATE_LATEX.*/GENERATE_LATEX = NO/' Doxyfile && \
    sed -i 's/HAVE_DOT.*/HAVE_DOT = YES/' Doxyfile && \
    sed -i 's/CALL_GRAPH.*/CALL_GRAPH = YES/' Doxyfile && \
    sed -i 's/CALLER_GRAPH.*/CALLER_GRAPH = YES/' Doxyfile && \
    echo "" > footer.html && \
    echo "body#top > * {display: none !important;}" > custom.css && \
    sed -i 's|HTML_FOOTER.*|HTML_FOOTER = footer.html|' Doxyfile && \
    sed -i 's/CLASS_DIAGRAMS.*/CLASS_DIAGRAMS = YES/' Doxyfile && \
    sed -i 's/SEARCHENGINE.*/SEARCHENGINE = NO/' Doxyfile && \
    sed -i 's/DOT_GRAPH_MAX_NODES.*/DOT_GRAPH_MAX_NODES = 100/' Doxyfile && \
    sed -i 's|HTML_EXTRA_STYLESHEET.*|HTML_EXTRA_STYLESHEET = custom.css|' Doxyfile &&\
    
    doxygen Doxyfile && \
    mkdir -p %s && \
    cp -r html %s/html
]], repopath, outpath, repo, repopath, repopath, outpath, outpath)

-- 执行命令
local code, output = run(cmd)

-- 响应
if code == 0 then
    ngx.say("Finished successfully:\n\n" .. output)
else
    ngx.status = 500
    ngx.say("Command failed with exit code " .. tostring(code) .. ":\n\n" .. output)
end

