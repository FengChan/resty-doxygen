local function parse_git_repo_url(repo_url)
    local url = repo_url:gsub("^git@[^:/]+:", "")
    url = url:gsub("^ssh://", "")
    url = url:gsub("^https?://[^/]+/", "")
    local username = url:match("([^/]+)/") or "default"
    local repo_name = url:match(".*/([^/]+)$") or "repo"
    repo_name = repo_name:gsub("%.git$", "")
    return username, repo_name
end

ngx.req.read_body()
local args = ngx.req.get_uri_args()
local repo = args.repo

if not repo then
    ngx.status = 400
    ngx.say("Missing 'repo' parameter")
    return
end

local user, repo_name = parse_git_repo_url(repo)
local repopath = string.format("/opt/workspace/%s/%s", user, repo_name)
local outpath  = string.format("/opt/output/%s/%s", user, repo_name)

local task = {
    repo = repo,
    repo_name = repo_name,
    repopath = repopath,
    outpath = outpath,
}

local ok, err = ngx.timer.at(0, function(premature)
    local build_worker = require("build_worker")
    build_worker.run(task)
end)

if ok then
    ngx.say("Build task accepted.")
else
    ngx.status = 500
    ngx.say("Failed to start build task: ", err)
end
