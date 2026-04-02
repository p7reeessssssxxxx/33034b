-- fenti AC module — host this file as raw text and load with:
--   loadstring(game:HttpGet(URL))()(ctx)
-- ctx: { banLog, _banLog, _isWave, RS, Players, player }
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
		local acliRemote = RS:FindFirstChild("7add470c-0a32-48cf-bd3e-1d6a1fcdcfc7")
		if acliRemote then
			banLog("AC-INFO", "ACLI heartbeat remote found: " .. acliRemote.ClassName)
			if acliRemote:IsA("RemoteEvent") then
				local acliFireCount = 0
				acliRemote.OnClientEvent:Connect(function(...)
					acliFireCount = acliFireCount + 1
					if acliFireCount <= 5 or acliFireCount % 10 == 0 then
						local args = { ... }
						local argSummary = {}
						for i, v in ipairs(args) do argSummary[i] = typeof(v) .. ":" .. tostring(v):sub(1, 40) end
						banLog("AC-HEARTBEAT", "ACLI recv #" .. acliFireCount .. " args=" .. table.concat(argSummary, ", "))
					end
				end)
			end
		else
			banLog("AC-INFO", "ACLI heartbeat remote NOT found (7add470c-...)")
		end
	end)
end
