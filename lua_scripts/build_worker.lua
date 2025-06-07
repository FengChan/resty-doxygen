local build_locks = ngx.shared.build_locks
local build_status = ngx.shared.build_status
local queue = require("queue")

local M = {}

function M.run(task)
    local repopath = task.repopath
    local outpath = task.outpath
    local repo = task.repo
    local repo_name = task.repo_name

    local lock_key = "lock:" .. repopath
    local status_key = "status:" .. repopath
    local queue_key = "queue:" .. repopath

    if not build_locks:add(lock_key, true, 300) then
        queue.enqueue(queue_key, task)
        build_status:set(status_key, "pending", 600)
        return
    end

    build_status:set(status_key, "building", 600)

    local cmds = {
        string.format("rm -rf %s/* %s/*", repopath, outpath),
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
    local tmp = os.tmpname()
    os.execute(cmd .. " > " .. tmp .. " 2>&1")
    local ok = io.open(tmp):read("*a")
    io.close()
    os.remove(tmp)

    build_status:set(status_key, "success", 600)
    build_locks:delete(lock_key)

    local next = queue.dequeue(queue_key)
    if next then
        ngx.timer.at(0, function(premature) M.run(next) end)
    end
end

return M
