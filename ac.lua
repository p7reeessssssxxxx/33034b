return function(ctx)
	local banLog = ctx.banLog
	local _banLog = ctx._banLog
	local _isWave = ctx._isWave
	local RS = ctx.RS
	local Players = ctx.Players
	local player = ctx.player

	if not _isWave then
		pcall(function()
			local ps = Players.LocalPlayer:FindFirstChild("PlayerScripts")
			if ps then
				for _, s in ipairs(ps:GetDescendants()) do
					if s:IsA("LocalScript") or s:IsA("ModuleScript") then
						local name = s.Name:lower()
						if name:find("acli") or name:find("adonis") or name:find("anticheat") or name:find("anti_cheat") then
							banLog("AC-DETECT", "Found AC script: " .. s:GetFullName())
						end
					end
				end
			end
		end)
	else
		banLog("AC-DETECT", "Skipped PlayerScripts scan (Wave - can trigger AC)")
	end

	pcall(function()
		local remFolder = RS:FindFirstChild("Remotes")
		if remFolder then
			local suspicious = {}
			for _, r in ipairs(remFolder:GetChildren()) do
				if r.Name:match("^%x%x%x%x%x%x%x%x%-") then
					table.insert(suspicious, r.Name:sub(1, 8) .. "... (" .. r.ClassName .. ")")
				end
			end
			if #suspicious > 0 then
				banLog("INIT", "UUID remotes (possible AC heartbeat): " .. table.concat(suspicious, ", "))
			end
		end
	end)

	pcall(function()
		for _, ch in ipairs(RS:GetChildren()) do
			local n = ch.Name
			if type(n) == "string" and #n == 36 and n:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x$") then
				banLog("INIT", "ReplicatedStorage UUID child: " .. n:sub(1, 8) .. "... (" .. ch.ClassName .. ")")
			end
		end
	end)

	pcall(function()
		local function looksLikeObfuscatedModuleName(n)
			if type(n) ~= "string" or #n < 10 then return false end
			local _, u = n:gsub("_", "_")
			if u >= 6 then return true end
			if #n >= 40 and u >= 3 and n:match("^[%w_]+$") then return true end
			if #n >= 56 and n:match("^[%w_]+$") then return true end
			return false
		end
		local maxShow = 20
		local hits = {}
		local function collect(root, tag)
			if not root then return end
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("ModuleScript") and looksLikeObfuscatedModuleName(d.Name) then
					table.insert(hits, { tag = tag, name = d.Name, path = d:GetFullName() })
				end
			end
		end
		collect(RS, "RS")
		pcall(function() collect(game:GetService("ReplicatedFirst"), "ReplicatedFirst") end)
		if #hits == 0 then
			banLog("AC-INFO", "No obfuscated-name ModuleScripts found under RS / ReplicatedFirst")
			return
		end
		banLog("AC-INFO", "Found " .. #hits .. " ModuleScript(s) with underscore/long obfuscated names")
		for i = 1, math.min(#hits, maxShow) do
			local h = hits[i]
			local short = #h.name > 28 and (h.name:sub(1, 28) .. "…") or h.name
			banLog("AC-INFO", "[" .. h.tag .. "] " .. short .. " → " .. h.path)
		end
		if #hits > maxShow then
			banLog("AC-INFO", "… +" .. (#hits - maxShow) .. " more not listed")
		end
	end)

	_banLog._bypassDone = false
	local function _bypassIndexInstance()
		if _banLog._bypassDone then return end
		if _isWave then
			banLog("BYPASS", "Skipped indexInstance bypass (Wave executor - getgc can crash)")
			return
		end
		if not getgc or not hookfunction or not newcclosure then
			banLog("BYPASS", "Skipped indexInstance bypass (missing getgc/hookfunction/newcclosure)")
			return
		end
		local ok, err = pcall(function()
			local gc = getgc(true)
			if not gc then return end
			for i = 1, math.min(#gc, 50000) do
				local v = gc[i]
				if type(v) ~= "userdata" and type(v) ~= "function" and type(v) == "table" then
					local s, hasIdx = pcall(rawget, v, "indexInstance")
					if s and hasIdx then
						for _, a in pairs(v) do
							if type(a) == "table" and type(a[2]) == "function" then
								hookfunction(a[2], newcclosure(function()
									return false
								end))
							end
						end
						_banLog._bypassDone = true
						banLog("BYPASS", "indexInstance hooked successfully")
						break
					end
				end
			end
		end)
		if not ok then banLog("BYPASS", "indexInstance bypass FAILED: " .. tostring(err)) end
	end
	task.delay(3, function() pcall(_bypassIndexInstance) end)
	task.delay(6, function() pcall(_bypassIndexInstance) end)
	task.delay(10, function() pcall(_bypassIndexInstance) end)

	pcall(function()
		local function isFullUuidName(n)
			return type(n) == "string" and #n == 36 and n:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x$")
		end
		local wired = {}
		local function wireHeartbeatRemote(r)
			if wired[r] then return end
			wired[r] = true
			banLog("AC-INFO", "Heartbeat watch: " .. r.ClassName .. " " .. r.Name:sub(1, 8) .. "... @ " .. r:GetFullName())
			local fireCount = 0
			r.OnClientEvent:Connect(function(...)
				fireCount = fireCount + 1
				if fireCount <= 5 or fireCount % 10 == 0 then
					local args = { ... }
					local argSummary = {}
					for i, v in ipairs(args) do argSummary[i] = typeof(v) .. ":" .. tostring(v):sub(1, 40) end
					banLog("AC-HEARTBEAT", r.Name:sub(1, 8) .. "... #" .. fireCount .. " " .. table.concat(argSummary, ", "))
				end
			end)
		end
		local nFound = 0
		for _, d in ipairs(RS:GetDescendants()) do
			if isFullUuidName(d.Name) and (d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent")) then
				wireHeartbeatRemote(d)
				nFound = nFound + 1
			end
		end
		if nFound == 0 then
			banLog("AC-INFO", "No UUID RemoteEvents in ReplicatedStorage yet (will attach if one appears)")
		else
			banLog("AC-INFO", "Attached to " .. nFound .. " UUID remote(s); new ones under RS are auto-watched")
		end
		RS.DescendantAdded:Connect(function(inst)
			if not isFullUuidName(inst.Name) then return end
			if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") then
				wireHeartbeatRemote(inst)
			end
		end)
	end)
end
