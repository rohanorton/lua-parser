local function readonlytable(table)
	return setmetatable({}, {
		__index = table,
		__newindex = function()
			error("Attempt to modify read-only table")
		end,
		__metatable = false,
	})
end

local NULL = readonlytable({ "NULL" })

-- success<T>(ctx: Context, value: T): Success<T>
local function success(ctx, value)
	return { success = true, value = value, ctx = ctx }
end

-- failure(ctx: Context, expected: string): Failure
local function failure(ctx, expected)
	return { success = false, expected = expected, ctx = ctx }
end

local function run(input, parser)
	return parser({ input = input, index = 1 })
end

-- Match a regexp
-- regex(pattern: LuaRegExp, expected: string): Parser<string>
local function pattern(pat, expected)
	return function(ctx)
		local startIdx, endIdx = string.find(ctx.input, pat, ctx.index)
		if startIdx == ctx.index then
			local match = string.sub(ctx.input, startIdx, endIdx)
			ctx.index = endIdx + 1
			return success(ctx, match)
		end
		return failure(ctx, expected)
	end
end

-- Match a literal
-- literal(match): Parser<string>
local function literal(match)
	return function(ctx)
		local endIdx = ctx.index + #match - 1
		if string.sub(ctx.input, ctx.index, endIdx) == match then
			ctx.index = endIdx + 1
			return success(ctx, match)
		end
		return failure(ctx, match)
	end
end

-- Look for an exact sequence of parsers
-- sequence<T>(parsers: Parser<T>[]): Parser<T[]>
local function sequence(parsers)
	return function(ctx)
		local values = {}
		local next_ctx = ctx
		for i, parser in ipairs(parsers) do
			local res = parser(next_ctx)
			if res.success == false then
				return res
			end

			table.insert(values, res.value)
			next_ctx = res.ctx
		end
		return success(next_ctx, values)
	end
end

-- Try each matcher in order, starting from the same point in the input.
-- return the first one that succeeds. or return the failure that got furthest
-- in the input string. which failure to return is a matter of taste, we prefer
-- the furthest failure because. it tends be the most useful / complete error
-- message. any time you see several choices in a grammar, you'll use `any`
-- any<T>(parsers: Parser<T>[]): Parser<T>
local function any(parsers)
	return function(ctx)
		local last_failure
		for _, parser in ipairs(parsers) do
			local res = parser(ctx)
			if res.success then
				return res
			end
			last_failure = res
		end
		return last_failure
	end
end

-- Match a parser, or succeed with null if not found. cannot fail.
-- optional<T>(parser: Parser<T>): Parser<T | null>
local function optional(parser)
	return function(ctx)
		local res = parser(ctx)
		if res.success then
			return res
		end
		return success(ctx, NULL)
	end
end

-- Look for 0 or more of something, until we can't parse any more. note that
-- this function never fails, it will instead succeed with an empty array.
-- many<T>(parser: Parser<T>): Parser<T[]>
local function many(parser)
	return function(ctx)
		local values = {}
		local next_ctx = ctx
		while true do
			local res = parser(next_ctx)
			if res.success then
				next_ctx = res.ctx
				table.insert(values, res.value)
			else
				return success(next_ctx, values)
			end
		end
	end
end

-- A convenience method that will map a Success to callback, to let us do
-- common things like build AST nodes from input strings.
-- Failures are passed through untouched.
-- map<A, B>(parser: Parser<A>, fn: (val: A) => B): Parser<B>
local function map(parser, fn)
	return function(ctx)
		local res = parser(ctx)
		if res.success then
			return success(res.ctx, fn(res.value))
		else
			return res
		end
	end
end

return {
	pattern = pattern,
	literal = literal,
	sequence = sequence,
	any = any,
	optional = optional,
	many = many,
	map = map,
	run = run,
	NULL = NULL,
}
