local require = require(script.Parent.loader).load(script)

local Janitor = require("Janitor")

--[=[
	Manages the cleaning of events and other things. Useful for
	encapsulating state and make deconstructors easy.

	See the [Five Powerful Code Patterns talk](https://developer.roblox.com/en-us/videos/5-powerful-code-patterns-behind-top-roblox-games)
	for a more in-depth look at Maids in top games.

	```lua
	local maid = Maid.new()

	maid:GiveTask(function()
		print("Cleaning up")
	end)

	maid:GiveTask(workspace.ChildAdded:Connect(print))

	-- Disconnects all events, and executes all functions
	maid:DoCleaning()
	```

	@class Maid
]=]
-- luacheck: pop

local Maid = {}
Maid.ClassName = "Maid"

--[=[
	Constructs a new Maid object

	```lua
	local maid = Maid.new()
	```

	@return Maid
]=]
function Maid.new()
	return setmetatable({
		_taskId = 0;
		_tasks = Janitor.new();
	}, Maid)
end

--[=[
	Returns true if the class is a maid, and false otherwise.

	```lua
	print(Maid.isMaid(Maid.new())) --> true
	print(Maid.isMaid(nil)) --> false
	```

	@param value any
	@return boolean
]=]
function Maid.isMaid(value)
	return type(value) == "table" and value.ClassName == "Maid"
end

--[=[
	Returns Maid[key] if not part of Maid metatable

	```lua
	local maid = Maid.new()
	maid._current = Instance.new("Part")
	print(maid._current) --> Part

	maid._current = nil
	print(maid._current) --> nil
	```

	@param index any
	@return MaidTask
]=]
function Maid:__index(index)
	if Maid[index] then
		return Maid[index]
	else
		return self._tasks:Get(index)
	end
end

--[=[
	Add a task to clean up. Tasks given to a maid will be cleaned when
	maid[index] is set to a different value.

	Task cleanup is such that if the task is an event, it is disconnected.
	If it is an object, it is destroyed.

	```
	Maid[key] = (function)         Adds a task to perform
	Maid[key] = (event connection) Manages an event connection
	Maid[key] = (thread)           Manages a thread
	Maid[key] = (Maid)             Maids can act as an event connection, allowing a Maid to have other maids to clean up.
	Maid[key] = (Object)           Maids can cleanup objects with a `Destroy` method
	Maid[key] = nil                Removes a named task.
	```

	@param index any
	@param newTask MaidTask
]=]
function Maid:__newindex(index, newTask)
	if Maid[index] ~= nil then
		error(("Cannot use '%s' as a Maid key"):format(tostring(index)), 2)
	end

	local tasks = self._tasks
	if tasks:Get(index) == newTask then
		return
	end

	tasks:Add(newTask, false, index)
end

--[=[
	Gives a task to the maid for cleanup, but uses an incremented number as a key.

	@param task MaidTask -- An item to clean
	@return number -- taskId
]=]
function Maid:GiveTask(task)
	if not task then
		error("Task cannot be false or nil", 2)
	end

	local taskId = self._taskId + 1
	self._tasks:Add(task, false, taskId)

	if type(task) == "table" and not task.Destroy then
		warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return taskId
end

--[=[
	Gives a promise to the maid for clean.

	@param promise Promise<T>
	@return Promise<T>
]=]
function Maid:GivePromise(promise)
	if not promise:IsPending() then
		return promise
	end

	local newPromise = promise.resolved(promise)
	local id = self:GiveTask(newPromise)

	-- Ensure GC
	newPromise:Finally(function()
		self[id] = nil
	end)

	return newPromise
end

--[=[
	Cleans up all tasks and removes them as entries from the Maid.

	:::note
	Signals that are already connected are always disconnected first. After that
	any signals added during a cleaning phase will be disconnected at random times.
	:::

	:::tip
	DoCleaning() may be recursively invoked. This allows the you to ensure that
	tasks or other tasks. Each task will be executed once.

	However, adding tasks while cleaning is not generally a good idea, as if you add a
	function that adds itself, this will loop indefinitely.
	:::
]=]
function Maid:DoCleaning()
	self._tasks:Cleanup()
end

--[=[
	Alias for [Maid.DoCleaning()](/api/Maid#DoCleaning)

	@function Destroy
	@within Maid
]=]
Maid.Destroy = Maid.DoCleaning

return Maid

