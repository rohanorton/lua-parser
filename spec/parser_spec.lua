local P = require("parser")

describe("Parser", function()
	local function assert_successful(res, expected)
		if res.success == false then
			assert(
				res.success,
				"expected "
					.. tostring(expected)
					.. " but parser failed to parse "
					.. (res.expected or "[unknown]")
					.. " from input '"
					.. res.ctx.input
					.. "' at index "
					.. res.ctx.index
			)
		else
			assert.same(res.value, expected)
		end
	end

	describe("literal()", function()
		it("matches literal", function()
			-- not to be used for literals, because that leads to problems
			local input = "hello, world!"
			local parser = P.literal("hello")
			local expected = "hello"
			assert_successful(P.run(input, parser), expected)
		end)
	end)
	describe("pattern()", function()
		it("matches literal", function()
			-- not to be used for literals, because that leads to problems
			local input = "abc"
			local parser = P.pattern("abc")
			local expected = "abc"
			assert_successful(P.run(input, parser), expected)
		end)
		it("matches wildards", function()
			local input = "abc"
			local parser = P.pattern("..")
			local expected = "ab"
			assert_successful(P.run(input, parser), expected)
		end)
		it("matches numbers", function()
			local input = "123abc456"
			local parser = P.pattern("[0-9]+")
			local expected = "123"
			assert_successful(P.run(input, parser), expected)
		end)
	end)
	describe("sequence()", function()
		it("matches simple sequences", function()
			local input = "1abc2def"
			local digit = P.pattern("%d", "digit")
			local three_letters = P.pattern("%a%a%a", "3 letters")
			local parser = P.sequence({ digit, three_letters, digit })
			local expected = { "1", "abc", "2" }
			assert_successful(P.run(input, parser), expected)
		end)
		it("handles nesting", function()
			local input = "1abc2def"
			local digit = P.pattern("%d", "digit")
			local three_letters = P.pattern("%a%a%a", "3 letters")
			local parser1 = P.sequence({ digit, three_letters })
			local parser2 = P.sequence({ parser1, parser1 })
			local expected = { { "1", "abc" }, { "2", "def" } }
			assert_successful(P.run(input, parser2), expected)
		end)
	end)
	describe("complex example", function()
		local number_literal
		local function_call

		local expr = function(ctx)
			return P.any({ function_call, number_literal })(ctx)
		end

		number_literal = P.map(P.pattern("[0-9]+", "number"), tonumber)
		local ident = P.pattern("[a-zA-Z][a-zA-Z0-9]*", "identifier")

		local trailingArg = P.map(P.sequence({ P.literal(","), expr }), function(xs)
			local _, argExpr = table.unpack(xs)
			return argExpr
		end)

		local args = P.map(P.sequence({ expr, P.many(trailingArg) }), function(xs)
			local arg1, rest = table.unpack(xs)
			table.insert(rest, 1, arg1)
			return rest
		end)

		function_call = P.map(
			P.sequence({ ident, P.literal("("), P.optional(args), P.literal(")") }),
			--
			function(xs)
				local fnName, _, argList, _ = table.unpack(xs)

				if argList == P.NULL then
					argList = {}
				end

				return {
					target = fnName,
					args = argList,
				}
			end
		)

		it("parses simple complex example", function()
			local res = P.run("Foo(1,2,3)", expr)
			local expected = { target = "Foo", args = { 1, 2, 3 } }
			assert_successful(res, expected)
		end)
		it("parses recursively", function()
			local res = P.run("Foo(Bar(1,2,3))", expr)
			local expected = { target = "Foo", args = { { target = "Bar", args = { 1, 2, 3 } } } }
			assert_successful(res, expected)
		end)
	end)
end)
