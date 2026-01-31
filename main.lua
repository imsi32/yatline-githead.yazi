---@diagnostic disable: undefined-global

local save = ya.sync(function(this, cwd, output)
	if cx.active.current.cwd == Url(cwd) then
		this.output = output
		ui.render()
	end
end)

return {
	setup = function(this, options)
		options = options or {}

		local config = {
			order = options.order or {
				"branch",
				"remote",
				"behind_ahead",
				"stashes",
				"state",
				"staged",
				"unstaged",
				"untracked",
			},

			show_branch = options.show_branch == nil and true or options.show_branch,
			branch_prefix = options.branch_prefix or "on",
			branch_symbol = options.branch_symbol or "",
			branch_borders = options.branch_borders or "()",

			show_remote = options.show_remote == nil and true or options.show_remote,
			remote_prefix = options.remote_prefix or ":",

			commit_symbol = options.commit_symbol or "@",

			show_behind_ahead = options.behind_ahead == nil and true or options.behind_ahead,
			behind_symbol = options.behind_symbol or "⇣",
			ahead_symbol = options.ahead_symbol or "⇡",

			show_stashes = options.show_stashes == nil and true or options.show_stashes,
			stashes_symbol = options.stashes_symbol or "$",

			show_state = options.show_state == nil and true or options.show_state,
			show_state_prefix = options.show_state_prefix == nil and true or options.show_state_prefix,
			state_symbol = options.state_symbol or "~",

			show_staged = options.show_staged == nil and true or options.show_staged,
			staged_symbol = options.staged_symbol or "+",

			show_unstaged = options.show_unstaged == nil and true or options.show_unstaged,
			unstaged_symbol = options.unstaged_symbol or "!",

			show_untracked = options.show_untracked == nil and true or options.show_untracked,
			untracked_symbol = options.untracked_symbol or "?",
		}

		if options.theme then
			options = options.theme
		end

		local theme = {
			prefix_color = options.prefix_color or "white",
			branch_color = options.branch_color or "blue",
			remote_color = options.remote_color or "bright magenta",
			commit_color = options.commit_color or "bright magenta",
			behind_color = options.behind_color or "bright magenta",
			ahead_color = options.ahead_color or "bright magenta",
			stashes_color = options.stashes_color or "bright magenta",
			state_color = options.state_color or "red",
			staged_color = options.staged_color or "bright yellow",
			unstaged_color = options.unstaged_color or "bright yellow",
			untracked_color = options.untracked_color or "bright blue",
		}

		local function get_branch(status)
			local branch = status:match("On branch (%S+)")

			if branch == nil then
				local commit = status:match("onto (%S+)") or status:match("detached at (%S+)")

				if commit == nil then
					return ""
				else
					local branch_prefix = config.branch_prefix == "" and " " or " " .. config.branch_prefix .. " "
					local commit_prefix = config.commit_symbol == "" and "" or config.commit_symbol

					return { "commit", branch_prefix .. commit_prefix, commit }
				end
			else
				local left_border = config.branch_borders:sub(1, 1)
				local right_border = config.branch_borders:sub(2, 2)

				local branch_string = ""

				if config.branch_symbol == "" then
					branch_string = left_border .. branch .. right_border
				else
					branch_string = left_border .. config.branch_symbol .. " " .. branch .. right_border
				end

				local branch_prefix = config.branch_prefix == "" and " " or " " .. config.branch_prefix .. " "

				return { "branch", branch_prefix, branch_string }
			end
		end

		local function get_remote(status)
			local branch = status:match("On branch (%S+)")
			local remote_branch = status:match("'[^/]+/([^']+)'")

			if (branch and remote_branch) and (branch ~= remote_branch) then
				return config.remote_prefix .. remote_branch
			else
				return ""
			end
		end

		get_remote("")

		local function get_behind_ahead(status)
			local diverged_ahead, diverged_behind = status:match("have (%d+) and (%d+) different")
			if diverged_ahead and diverged_behind then
				return { " " .. config.behind_symbol .. diverged_behind, config.ahead_symbol .. diverged_ahead }
			else
				local behind = status:match("behind %S+ by (%d+) commit")
				local ahead = status:match("ahead of %S+ by (%d+) commit")
				if ahead then
					return { "", " " .. config.ahead_symbol .. ahead }
				elseif behind then
					return { " " .. config.behind_symbol .. behind, "" }
				else
					return ""
				end
			end
		end

		local function get_stashes(status)
			local stashes = tonumber(status:match("Your stash currently has (%S+)"))

			return stashes ~= nil and " " .. config.stashes_symbol .. stashes or ""
		end

		local function get_state(status)
			local unmerged = status:match("Unmerged paths:%s*(.-)%s*\n\n")
			if unmerged then
				local filtered_unmerged = unmerged:gsub("^[%s]*%b()[%s]*", ""):gsub("^[%s]*%b()[%s]*", "")

				local unmerged_count = 0
				for line in filtered_unmerged:gmatch("[^\r\n]+") do
					if line:match("%S") then
						unmerged_count = unmerged_count + 1
					end
				end

				local state_name = ""

				if config.show_state_prefix then
					if status:find("git merge") then
						state_name = "merge "
					elseif status:find("git cherry%-pick") then
						state_name = "cherry "
					elseif status:find("git rebase") then
						state_name = "rebase "

						if status:find("done") then
							local done = status:match("%((%d+) com.- done%)") or ""
							state_name = state_name .. done .. "/" .. unmerged_count .. " "
						end
					elseif status:find("git revert") then
						state_name = "revert "
					end
				end

				return " " .. state_name .. config.state_symbol .. unmerged_count
			elseif status:find("git bisect") then
				return " bisect"
			else
				return ""
			end
		end

		local function get_staged(status)
			local result = status:match("Changes to be committed:%s*(.-)%s*\n\n")
			if result then
				local filtered_result = result:gsub("^[%s]*%b()[%s]*", "")

				local staged = 0
				for line in filtered_result:gmatch("[^\r\n]+") do
					if line:match("%S") then
						staged = staged + 1
					end
				end

				return " " .. config.staged_symbol .. staged
			else
				return ""
			end
		end

		local function get_unstaged(status)
			local result = status:match("Changes not staged for commit:%s*(.-)%s*\n\n")
			if result then
				local filtered_result = result:gsub("^[%s]*%b()[\r\n]*", ""):gsub("^[%s]*%b()[\r\n]*", "")

				local unstaged = 0
				for line in filtered_result:gmatch("[^\r\n]+") do
					if line:match("%S") then
						unstaged = unstaged + 1
					end
				end

				return " " .. config.unstaged_symbol .. unstaged
			else
				return ""
			end
		end

		local function get_untracked(status)
			local result = status:match("Untracked files:%s*(.-)%s*\n\n")
			if result then
				local filtered_result = result:gsub("^[%s]*%b()[\r\n]*", "")

				local untracked = 0
				for line in filtered_result:gmatch("[^\r\n]+") do
					if line:match("%S") then
						untracked = untracked + 1
					end
				end

				return " " .. config.untracked_symbol .. untracked
			else
				return ""
			end
		end

		function Header:githead()
			local status = this.output

			local branch_array = get_branch(status)
			local behind_ahead_array = get_behind_ahead(status)

			local values = {
				prefix = ui.Span(config.show_branch and branch_array[2] or ""):fg(theme.prefix_color),
				branch = ui.Span(config.show_branch and branch_array[3] or "")
					:fg(branch_array[1] == "commit" and theme.commit_color or theme.branch_color),
				remote = ui.Span(config.show_remote and get_remote(status) or ""):fg(theme.remote_color),
				behind_ahead = ui.Line(
					ui.Span(config.show_behind_ahead and behind_ahead_array[1] or ""):fg(theme.behind_color),
					ui.Span(config.show_behind_ahead and behind_ahead_array[2] or ""):fg(theme.ahead_color)
				),
				stashes = ui.Span(config.show_stashes and get_stashes(status) or ""):fg(theme.stashes_color),
				state = ui.Span(config.show_state and get_state(status) or ""):fg(theme.state_color),
				staged = ui.Span(config.show_staged and get_staged(status) or ""):fg(theme.staged_color),
				unstaged = ui.Span(config.show_unstaged and get_unstaged(status) or ""):fg(theme.unstaged_color),
				untracked = ui.Span(config.show_untracked and get_untracked(status) or ""):fg(theme.untracked_color),
			}

			local githead = {}
			for _, key in ipairs(config.order) do
				local is_shown = config["show_" .. key]
				if values[key] and is_shown then
					table.insert(githead, values[key])
				end
			end

			return ui.Line(githead)
		end

		local callback = function()
			local cwd = cx.active.current.cwd

			ya.emit("plugin", {
				this._id,
				ya.quote(tostring(cwd), true),
			})
		end

		ps.sub("cd", callback)
		ps.sub("rename", callback)
		ps.sub("bulk", callback)
		ps.sub("move", callback)
		ps.sub("trash", callback)
		ps.sub("delete", callback)
		ps.sub("tab", callback)

		if Yatline ~= nil then
			function Yatline.coloreds.get:githead()
				local status = this.output

				if not status then
					return ""
				end

				local branch_array = config.show_branch and get_branch(status) or ""
				local remote_str = config.show_remote and get_remote(status) or ""
				local behind_ahead_array = config.show_behind_ahead and get_behind_ahead(status) or ""
				local stashes_str = config.show_stashes and get_stashes(status) or ""
				local state_str = config.show_state and get_state(status) or ""
				local staged_str = config.show_staged and get_staged(status) or ""
				local unstaged_str = config.show_unstaged and get_unstaged(status) or ""
				local untracked_str = config.show_untracked and get_untracked(status) or ""

				local values = {
					prefix = branch_array ~= "" and { branch_array[2], theme.prefix_color } or nil,
					branch = branch_array ~= "" and {
						branch_array[3],
						branch_array[1] == "commit" and theme.commit_color or theme.branch_color,
					} or nil,
					remote = remote_str ~= "" and { remote_str, theme.remote_color } or nil,
					behind_ahead = (function()
						if behind_ahead_array ~= "" then
							local ba_array = {}
							if behind_ahead_array[1] ~= "" then
								table.insert(ba_array, { behind_ahead_array[1], theme.behind_color })
							end
							if behind_ahead_array[2] ~= "" then
								table.insert(ba_array, { behind_ahead_array[2], theme.ahead_color })
							end
							if #ba_array ~= 0 then
								return ba_array
							end
						end
						return nil
					end)(),
					stashes = stashes_str ~= "" and { stashes_str, theme.stashes_color } or nil,
					state = state_str ~= "" and { state_str, theme.state_color } or nil,
					staged = staged_str ~= "" and { staged_str, theme.staged_color } or nil,
					unstaged = unstaged_str ~= "" and { unstaged_str, theme.unstaged_color } or nil,
					untracked = untracked_str ~= "" and { untracked_str, theme.untracked_color } or nil,
				}

				local githead = {}
				for _, key in ipairs(config.order) do
					local is_shown = config["show_" .. key]
					if values[key] ~= nil and is_shown then
						if type(values[key][1]) == "table" then
							for _, value in ipairs(values[key]) do
								table.insert(githead, value)
							end
						else
							table.insert(githead, values[key])
						end
					end
				end

				if #githead == 0 then
					return ""
				else
					return githead
				end
			end
		else
			Header:children_add(Header.githead, 2000, Header.LEFT)
		end
	end,

	entry = function(_, job)
		local args = job.args or job
		local command = Command("git")
			:arg({ "status", "--ignore-submodules=dirty", "--branch", "--show-stash", "--ahead-behind" })
			:cwd(args[1])
			:env("LANGUAGE", "en_US.UTF-8")
			:stdout(Command.PIPED)
		local output = command:output()

		if output then
			save(args[1], output.stdout)
		end
	end,
}
