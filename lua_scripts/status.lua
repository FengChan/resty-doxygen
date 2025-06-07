local build_status = ngx.shared.build_status

ngx.req.read_body()
local args = ngx.req.get_uri_args()
local repo = args.repo

if not repo then
    ngx.status = 400
    ngx.say("Missing 'repo'")
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
local status = build_status:get("status:" .. repopath) or "unknown"
ngx.say(status)
