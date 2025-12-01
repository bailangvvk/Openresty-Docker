---json 转换工具
---@class JSON @by wx771720@outlook.com 2019-08-07 16:03:34
_G.JSON = {escape = "\\", comma = ",", colon = ":", null = "null"}

---将数据转换成 json 字符串
---@param data any @数据
---@param space number|string @美化输出时缩进空格数量或者字符串，默认 nil 表示不美化
---@param toArray boolean @如果是数组，是否按数组格式输出，默认 true
---@return string @返回 json 格式的字符串
function JSON.ENCODE(data, space, toArray, __tableList, __keyList, __indent)
	if "boolean" ~= type(toArray) then toArray = true end
	if "table" ~= type(__tableList) then __tableList = {} end
	if "table" ~= type(__keyList) then __keyList = {} end
	if "number" == type(space) then space = space > 0 and string.format("%" .. tostring(space) .. "s", " ") or nil end
	if nil ~= space and nil == __indent then __indent = "" end

	local dataType = type(data)
	-- string
	if "string" == dataType then
		data = string.gsub(data, "\\", "\\\\")
		data = string.gsub(data, "\"", "\\\"")
		return "\"" .. data .. "\""
	end
	-- number
	if "number" == dataType then return tostring(data) end
	-- boolean
	if "boolean" == dataType then return data and "true" or "false" end
	-- table
	if "table" == dataType then
		table.insert(__tableList, data)

		local result, value
		if 0 == JSON._tableCount(data) then
			result = "{}"
		elseif toArray and JSON._isArray(data) then
			result = nil == space and "[" or (__indent .. "[")
			local subIndent = __indent and (__indent .. space)
			for i = 1, #data do
				value = data[i]
				if "table" == type(value) and JSON._indexOf(__tableList, value) >= 1 then
					print(string.format("json array loop refs warning : %s[%i]", JSON.ENCODE(__keyList), i))
				else
					local valueString = JSON.ENCODE(data[i], space, toArray, __tableList, table.insert({unpack(__keyList)}, i), subIndent)
					if valueString and subIndent and JSON._isBeginWith(valueString, subIndent) then valueString = string.sub(valueString, #subIndent + 1) end
					if nil == space then
						result = result .. (i > 1 and "," or "") .. (valueString or JSON.null)
					else
						result = result .. (i > 1 and "," or "") .. "\n" .. subIndent .. (valueString or JSON.null)
					end
				end
			end
			result = result .. (nil == space and "]" or ("\n" .. __indent .. "]"))
		else
			result = nil == space and "{" or (__indent .. "{")
			local index = 0
			local subIndent = __indent and (__indent .. space)
			for k, v in pairs(data) do
				if "table" == type(v) and JSON._indexOf(__tableList, v) >= 1 then
					print(string.format("json map loop refs warning : %s[%s]", JSON.ENCODE(__keyList), k))
				else
					local valueString = JSON.ENCODE(v, space, toArray, __tableList, table.insert({unpack(__keyList)}, k), subIndent)
					if valueString then
						if subIndent and JSON._isBeginWith(valueString, subIndent) then valueString = string.sub(valueString, #subIndent + 1) end
						if nil == space then
							result = result .. (index > 0 and "," or "") .. ("\"" .. k .. "\":") .. valueString
						else
							result = result .. (index > 0 and "," or "") .. "\n" .. subIndent .. ("\"" .. k .. "\" : ") .. valueString
						end
						index = index + 1
					end
				end
			end
			result = result .. (nil == space and "}" or ("\n" .. __indent .. "}"))
		end
		return result
	end
end

---去掉字符串首尾空格
---@param target string
---@return string
JSON._trim = function(target) return target and string.gsub(target, "^%s*(.-)%s*$", "%1") end
---判断字符串是否已指定字符串开始
---@param str string @需要判断的字符串
---@param match string @需要匹配的字符串
---@return boolean
JSON._isBeginWith = function(str, match) return nil ~= string.match(str, "^" .. match) end
---计算指定表键值对数量
---@param map table @表
---@return number @返回表数量
JSON._tableCount = function(map)
	local count = 0
	for _, __ in pairs(map) do count = count + 1 end
	return count
end
---判断指定表是否是数组（不包含字符串索引的表）
---@param target any @表
---@return boolean @如果不包含字符串索引则返回 true，否则返回 false
JSON._isArray = function(target)
	if "table" == type(target) then
		for key, _ in pairs(target) do if "string" == type(key) then return false end end
		return true
	end
	return false
end
---获取数组中第一个项索引
JSON._indexOf = function(array, item)
	for i = 1, #array do if item == array[i] then return i end end
	return -1
end

---将字符串转换成 table 对象
---@param text string json @格式的字符串
---@return any|nil @如果解析成功返回对应数据，否则返回 nil
JSON.DECODE = function(text)
	text = JSON._trim(text)
	-- string
	if "\"" == string.sub(text, 1, 1) and "\"" == string.sub(text, -1, -1) then return string.sub(JSON.findMeta(text), 2, -2) end
	if 4 == #text then
		-- boolean
		local lowerText = string.lower(text)
		if "false" == lowerText then
			return false
		elseif "true" == lowerText then
			return true
		end
		-- nil
		if JSON.null == lowerText then return end
	end
	-- number
	local number = tonumber(text)
	if number then return number end
	-- array
	if "[" == string.sub(text, 1, 1) and "]" == string.sub(text, -1, -1) then
		local remain = string.gsub(text, "[\r\n]+", "")
		remain = string.sub(remain, 2, -2)
		local array, index, value = {}, 1
		while #remain > 0 do
			value, remain = JSON.findMeta(remain)
			if value then
				value = JSON.DECODE(value)
				array[index] = value
				index = index + 1
			end
		end
		return array
	end
	-- table
	if "{" == string.sub(text, 1, 1) and "}" == string.sub(text, -1, -1) then
		local remain = string.gsub(text, "[\r\n]+", "")
		remain = string.sub(remain, 2, -2)
		local key, value
		local map = {}
		while #remain > 0 do
			key, remain = JSON.findMeta(remain)
			value, remain = JSON.findMeta(remain)
			if key and #key > 0 and value then
				key = JSON.DECODE(key)
				value = JSON.DECODE(value)
				if key and value then map[key] = value end
			end
		end
		return map
	end
end

---查找字符串中的 json 元数据
---@param text string @json 格式的字符串
---@return string,string @元数据,剩余字符串
JSON.findMeta = function(text)
	local stack = {}
	local index = 1
	local lastChar = nil
	while index <= #text do
		local char = string.sub(text, index, index)
		if "\"" == char then
			if char == lastChar then
				table.remove(stack, #stack)
				lastChar = #stack > 0 and stack[#stack] or nil
			else
				table.insert(stack, char)
				lastChar = char
			end
		elseif "\"" ~= lastChar then
			if "{" == char then
				table.insert(stack, "}")
				lastChar = char
			elseif "[" == char then
				table.insert(stack, "]")
				lastChar = char
			elseif "}" == char or "]" == char then
				assert(char == lastChar, text .. " " .. index .. " not expect " .. char .. "<=>" .. lastChar)
				table.remove(stack, #stack)
				lastChar = #stack > 0 and stack[#stack] or nil
			elseif JSON.comma == char or JSON.colon == char then
				if not lastChar then return string.sub(text, 1, index - 1), string.sub(text, index + 1) end
			end
		elseif JSON.escape == char then
			text = string.sub(text, 1, index - 1) .. string.sub(text, index + 1)
		end

		index = index + 1
	end
	return string.sub(text, 1, index - 1), string.sub(text, index + 1)
end


--[[
    --序列化
    local json = {name = "wx771720", age = 18, married = true, skills = {"typescript", "unity", "lua"}}
    local jsonStr = JSON.toString(json)
    print(jsonStr)

    -- {"name":"wx771720","skills":["typescript","unity","lua"],"age":18,"married":true}
]]

--[[
    --序列化漂亮格式
    local json = {name = "wx771720", age = 18, married = true, skills = {"typescript", "unity", "lua"}}
    local jsonStr = JSON.toString(json, 4)
    print(jsonStr)
    --{
    --    "age" : 18,
    --    "name" : "wx771720",
    --    "married" : true,
    --    "skills" : [
    --        "typescript",
    --        "unity",
    --        "lua"
    --    ]
    --}
]]

--[[
    --字符串解析
    local json = {name = "wx771720", age = 18, married = true, skills = {"typescript", "unity", "lua"}}
    local jsonStr = JSON.toString(json)
    -- 解析严格格式的 json 字符串
    json = JSON.toJSON(jsonStr)
    -- 解析经过格式处理的 json 字符串
    jsonStr = JSON.toString(json, 4)
    json = JSON.toJSON(jsonStr)

    print(json.name)
    print(json.age)
    print(json.married)

    --wx771720
    --18
    --true
]]