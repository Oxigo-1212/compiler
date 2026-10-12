add_rules("mode.debug", "mode.release")

option("tests")
set_default(false)
set_showmenu(true)
set_description("Build the C++ parser tests")
option_end()

if has_config("tests") then
	add_requires("doctest 2.4.12", { configs = { cmake = false } })
end

rule("flex")
set_extensions(".l")
on_buildcmd_file(function(target, batchcmds, sourcefile, opt)
	import("lib.detect.find_tool")
	---@diagnostic disable: param-type-not-match, undefined-field
	local flex = assert(find_tool("flex"), "flex not found! Please install flex.")
	local generated_dir = path.join(target:autogendir(), "flex")
	local cppfile = path.join(generated_dir, path.basename(sourcefile) .. ".cpp")
	local objectfile = target:objectfile(cppfile)

	table.insert(target:objectfiles(), objectfile)

	---@diagnostic disable: redundant-parameter
	batchcmds:show_progress(opt.progress, "${color.build.object}flex %s", sourcefile)
	batchcmds:mkdir(generated_dir)
	batchcmds:vrunv(flex.program, { "-o", cppfile, sourcefile })
	batchcmds:compile(cppfile, objectfile)

	batchcmds:add_depfiles(sourcefile)
	batchcmds:set_depmtime(os.mtime(objectfile))
	batchcmds:set_depcache(target:dependfile(objectfile))
end)

rule("bison")
set_extensions(".y")
on_load(function(target)
	target:add("includedirs", path.join(target:autogendir(), "bison"))
end)
before_build(function(target)
	import("lib.detect.find_tool")
	local bison = assert(find_tool("bison"), "bison not found! Please install bison.")
	local generated_dir = path.join(target:autogendir(), "bison")
	os.mkdir(generated_dir)
	-- Generate the shared token header before Flex output is compiled.
	os.vrunv(bison.program, { "--defines=" .. path.join(generated_dir, "parser.hpp"),
		"-o", path.join(generated_dir, "parser.cpp"), "src/specs/parser.y" })
end)
on_buildcmd_file(function(target, batchcmds, sourcefile, opt)
	local generated_dir = path.join(target:autogendir(), "bison")
	local cppfile = path.join(generated_dir, path.basename(sourcefile) .. ".cpp")
	local objectfile = target:objectfile(cppfile)

	table.insert(target:objectfiles(), objectfile)

	---@diagnostic disable: redundant-parameter
	batchcmds:show_progress(opt.progress, "${color.build.object}bison %s", sourcefile)
	batchcmds:compile(cppfile, objectfile)

	batchcmds:add_depfiles(sourcefile)
	batchcmds:set_depmtime(os.mtime(objectfile))
	batchcmds:set_depcache(target:dependfile(objectfile))
end)

---@diagnostic disable: undefined-global
target("compiler")
set_kind("binary")
set_languages("cxx20")
add_includedirs("src")
add_rules("bison")
add_files("src/main.cpp", "src/ast.cpp")
add_files("src/specs/*.l", { rules = "flex" })
add_files("src/specs/*.y")

if has_config("tests") then
	target("parser_tests")
	set_kind("binary")
	set_languages("cxx20")
	add_includedirs("src")
	add_packages("doctest")
	add_rules("bison")
	add_files("tests/parser_tests.cpp", "src/ast.cpp")
	add_files("src/specs/*.l", { rules = "flex" })
	add_files("src/specs/*.y")
	add_tests("parser", { rundir = os.projectdir(), run_timeout = 30000 })
end
