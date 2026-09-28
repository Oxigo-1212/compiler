add_rules("mode.debug", "mode.release")

rule("flex")
set_extensions(".l")
on_buildcmd_file( function (target, batchcmds, sourcefile, opt)
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

---@diagnostic disable: undefined-global
target("compiler")
set_kind("binary")
set_languages("cxx20")
add_files("src/main.cpp")
add_files("src/specs/*.l", { rules = "flex" })
