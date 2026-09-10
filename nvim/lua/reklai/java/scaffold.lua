local runtime = require("reklai.java.runtime")

local M = {}

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Java" })
end

local function exists(path)
	return vim.uv.fs_stat(path) ~= nil
end

local function java_major()
	local jdk = runtime.default_jdtls_runtime()
	return jdk and jdk.major or 21
end

-- Open the generated project's entry point so jdtls/spring-boot attach from
-- its root. Prefers *Application.java (Initializr) or App.java (quickstart).
local function open_project(target)
	local files = vim.fn.glob(target .. "/**/src/main/java/**/*.java", true, true)
	if vim.tbl_isempty(files) then
		files = vim.fn.glob(target .. "/src/main/java/**/*.java", true, true)
	end
	table.sort(files, function(a, b)
		local rank = function(f)
			local tail = vim.fs.basename(f)
			return (tail:match("Application%.java$") or tail == "App.java") and 0 or 1
		end
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	vim.schedule(function()
		vim.cmd.cd(vim.fn.fnameescape(target))
		if files[1] then
			vim.cmd.edit(vim.fn.fnameescape(files[1]))
			notify("Project ready: " .. target)
		else
			notify("Project generated at " .. target .. " (no Java sources found to open).", vim.log.levels.WARN)
		end
	end)
end

-- Spring Initializr: fetch starter.tgz, then extract. Two steps instead of a
-- shell pipe so HTTP failures surface Initializr's actual error message
-- (e.g. an unknown dependency id) instead of a bare curl exit code.
local function generate_spring(opts, on_done)
	local target = opts.parent .. "/" .. opts.name
	local tmp = vim.fn.tempname() .. ".tgz"
	local args = {
		"curl",
		"-s",
		"--max-time",
		"30",
		"-o",
		tmp,
		"-w",
		"%{http_code}",
		"https://start.spring.io/starter.tgz",
		"-d",
		"type=" .. (opts.tool == "maven" and "maven-project" or "gradle-project"),
		"-d",
		"language=java",
		"-d",
		"javaVersion=" .. java_major(),
		"-d",
		"groupId=" .. opts.group,
		"-d",
		"artifactId=" .. opts.name,
		"-d",
		"name=" .. opts.name,
		"-d",
		"baseDir=" .. opts.name,
	}
	if opts.deps and opts.deps ~= "" then
		vim.list_extend(args, { "-d", "dependencies=" .. opts.deps })
	end

	notify("Generating Spring Boot project '" .. opts.name .. "'...")
	-- vim.system callbacks run in a fast event context where vim.fn.* is
	-- forbidden, so hop back to the main loop before doing anything else.
	vim.system(args, { text = true }, function(fetch)
		vim.schedule(function()
			local status = vim.trim(fetch.stdout or "")
			if fetch.code ~= 0 or status ~= "200" then
				local body = table.concat(vim.fn.readfile(tmp, "b"), "\n")
				local message = body:match('"message"%s*:%s*"([^"]+)"') or vim.trim(fetch.stderr or "")
				vim.uv.fs_unlink(tmp)
				notify(
					"Spring Initializr failed (HTTP " .. status .. "): " .. (message ~= "" and message or "unknown error"),
					vim.log.levels.ERROR
				)
				if on_done then
					on_done(false)
				end
				return
			end

			vim.system({ "tar", "-xzf", tmp, "-C", opts.parent }, { text = true }, function(extract)
				vim.schedule(function()
					vim.uv.fs_unlink(tmp)
					if extract.code ~= 0 then
						notify("Extracting the project failed: " .. vim.trim(extract.stderr or ""), vim.log.levels.ERROR)
						if on_done then
							on_done(false)
						end
						return
					end
					open_project(target)
					if on_done then
						on_done(true)
					end
				end)
			end)
		end)
	end)
end

-- Plain projects run through overseer (like the build picker) so the longer
-- local generation -- archetype plugins download on first run -- is visible.
local function generate_plain(opts, on_done)
	local ok, overseer = pcall(require, "overseer")
	if not ok then
		notify("overseer.nvim is not loaded yet.", vim.log.levels.ERROR)
		if on_done then
			on_done(false)
		end
		return
	end

	local target = opts.parent .. "/" .. opts.name
	local package = (opts.group .. "." .. opts.name):gsub("[^%w.]", "")
	local task
	if opts.tool == "maven" then
		-- Quickstart, then a wrapper so plain projects behave like Initializr
		-- ones (tasks.lua prefers mvnw when present).
		local generate = ("mvn -B archetype:generate -DgroupId=%s -DartifactId=%s -Dpackage=%s"
			.. " -DarchetypeArtifactId=maven-archetype-quickstart -DarchetypeVersion=1.5 -DinteractiveMode=false"):format(
			opts.group,
			opts.name,
			package
		)
		task = overseer.new_task({
			name = "New Maven project: " .. opts.name,
			cmd = "sh",
			args = { "-c", generate .. " && cd " .. vim.fn.shellescape(target) .. " && mvn -B -q wrapper:wrapper" },
			cwd = opts.parent,
			components = { "default" },
		})
	else
		task = overseer.new_task({
			name = "New Gradle project: " .. opts.name,
			cmd = "gradle",
			args = {
				"init",
				"--type",
				"java-application",
				"--dsl",
				"kotlin",
				"--test-framework",
				"junit-jupiter",
				"--project-name",
				opts.name,
				"--package",
				package,
				"--java-version",
				tostring(java_major()),
				"--use-defaults",
				"--into",
				target,
			},
			cwd = opts.parent,
			components = { "default" },
		})
	end

	task:subscribe("on_complete", function(_, status)
		if status == "SUCCESS" then
			open_project(target)
		else
			notify("Project generation failed -- see the overseer task output.", vim.log.levels.ERROR)
		end
		if on_done then
			on_done(status == "SUCCESS")
		end
		return true -- unsubscribe
	end)
	task:start()
	pcall(overseer.open, { enter = false, direction = "bottom" })
end

-- opts: tool ("maven"|"gradle"), spring (bool), name, group, parent, deps
function M.generate(opts, on_done)
	local target = opts.parent .. "/" .. opts.name
	if exists(target) then
		notify("Directory already exists: " .. target, vim.log.levels.ERROR)
		if on_done then
			on_done(false)
		end
		return
	end
	if opts.spring then
		generate_spring(opts, on_done)
	else
		generate_plain(opts, on_done)
	end
end

local function input(prompt, default, callback)
	vim.ui.input({ prompt = prompt, default = default }, function(value)
		if value == nil then
			return -- cancelled
		end
		value = vim.trim(value)
		if value == "" and default ~= "" then
			value = default
		end
		if value == "" then
			notify("Cancelled: a value is required.", vim.log.levels.WARN)
			return
		end
		callback(value)
	end)
end

local function prompt_and_generate(tool)
	vim.ui.select({ "Spring Boot", "Plain " .. (tool == "maven" and "Maven" or "Gradle") }, {
		prompt = "Project flavor",
	}, function(flavor)
		if not flavor then
			return
		end
		local spring = flavor == "Spring Boot"
		input("Project name: ", "", function(name)
			input("Group id: ", "com.example", function(group)
				local finish = function(deps)
					input("Create in: ", vim.uv.cwd(), function(parent)
						M.generate({
							tool = tool,
							spring = spring,
							name = name,
							group = group,
							deps = deps,
							parent = vim.fs.normalize(parent),
						})
					end)
				end
				if spring then
					input("Spring starters (comma-separated): ", "web,devtools,lombok", function(deps)
						finish((deps:gsub("%s+", "")))
					end)
				else
					finish(nil)
				end
			end)
		end)
	end)
end

function M.new_maven()
	prompt_and_generate("maven")
end

function M.new_gradle()
	prompt_and_generate("gradle")
end

return M
