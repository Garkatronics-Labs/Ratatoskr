package ratatoskr

import "core:fmt"
import "core:log"
import "core:strings"
import os "core:os"

// --- enum -> flag string helpers ------------------------------------------

build_mode_to_flag :: proc(m: Build_Mode) -> string {
	switch m {
	case .Exe:      return "exe"
	case .Test:     return "test"
	case .Dll:      return "dll"
	case .Lib:      return "lib"
	case .Obj:      return "obj"
	case .Assembly: return "assembly"
	case .LLVM_IR:  return "llvm-ir"
	}
	return "exe"
}

optimization_to_flag :: proc(o: Optimization_Mode) -> string {
	switch o {
	case .None:       return "none"
	case .Minimal:    return "minimal"
	case .Size:       return "size"
	case .Speed:      return "speed"
	case .Aggressive: return "aggressive"
	}
	return "minimal"
}

sanitize_to_flag :: proc(s: Sanitize_Mode) -> string {
	switch s {
	case .Address: return "address"
	case .Memory:  return "memory"
	case .Thread:  return "thread"
	}
	return "address"
}

// --- translate Compiler_Flags into a string of "-flag ..." args -----------

add_compiler_options :: proc(cfg: Project_Config, allocator := context.allocator) -> string {
	sb: strings.Builder
	strings.builder_init(&sb, allocator)
	cf := cfg.compiler

	if v, ok := cf.build_mode.?; ok {
		log.debugf("build_mode: %s", build_mode_to_flag(v))
		fmt.sbprintf(&sb, " -build-mode:%s", build_mode_to_flag(v))
	}
	if v, ok := cf.optimization.?; ok {
		fmt.sbprintf(&sb, " -o:%s", optimization_to_flag(v))
	}
	if v, ok := cf.sanitize.?; ok {
		fmt.sbprintf(&sb, " -sanitize:%s", sanitize_to_flag(v))
	}
	if v, ok := cf.thread_count.?; ok {
		fmt.sbprintf(&sb, " -thread-count:%d", v)
	}
	if v, ok := cf.max_error_count.?; ok {
		fmt.sbprintf(&sb, " -max-error-count:%d", v)
	}

	if cf.target          != "" do fmt.sbprintf(&sb, " -target:%s", cf.target)
	if cf.subtarget        != "" do fmt.sbprintf(&sb, " -subtarget:%s", cf.subtarget)
	if cf.microarch        != "" do fmt.sbprintf(&sb, " -microarch:%s", cf.microarch)
	if cf.target_features  != "" do fmt.sbprintf(&sb, " -target-features:%s", cf.target_features)
	if cf.linker           != "" do fmt.sbprintf(&sb, " -linker:%s", cf.linker)
	if cf.extra_linker_flags    != "" do fmt.sbprintf(&sb, " -extra-linker-flags:%s", cf.extra_linker_flags)
	if cf.extra_assembler_flags != "" do fmt.sbprintf(&sb, " -extra-assembler-flags:%s", cf.extra_assembler_flags)

	if cf.debug                     do strings.write_string(&sb, " -debug")
	if cf.disable_assert            do strings.write_string(&sb, " -disable-assert")
	if cf.disable_red_zone          do strings.write_string(&sb, " -disable-red-zone")
	if cf.disallow_do               do strings.write_string(&sb, " -disallow-do")
	if cf.dynamic_map_calls         do strings.write_string(&sb, " -dynamic-map-calls")
	if cf.no_bounds_check           do strings.write_string(&sb, " -no-bounds-check")
	if cf.no_crt                    do strings.write_string(&sb, " -no-crt")
	if cf.no_entry_point             do strings.write_string(&sb, " -no-entry-point")
	if cf.no_rpath                  do strings.write_string(&sb, " -no-rpath")
	if cf.no_thread_local            do strings.write_string(&sb, " -no-thread-local")
	if cf.no_threaded_checker        do strings.write_string(&sb, " -no-threaded-checker")
	if cf.no_type_assert             do strings.write_string(&sb, " -no-type-assert")
	if cf.ignore_warnings            do strings.write_string(&sb, " -ignore-warnings")
	if cf.ignore_unknown_attributes  do strings.write_string(&sb, " -ignore-unknown-attributes")
	if cf.warnings_as_errors         do strings.write_string(&sb, " -warnings-as-errors")
	if cf.use_separate_modules       do strings.write_string(&sb, " -use-separate-modules")
	if cf.use_single_module          do strings.write_string(&sb, " -use-single-module")
	if cf.keep_temp_files            do strings.write_string(&sb, " -keep-temp-files")
	if cf.keep_executable            do strings.write_string(&sb, " -keep-executable")
	if cf.strict_style               do strings.write_string(&sb, " -strict-style")
	if cf.strict_target_features     do strings.write_string(&sb, " -strict-target-features")
	if cf.min_link_libs              do strings.write_string(&sb, " -min-link-libs")
	if cf.lld                        do strings.write_string(&sb, " -lld")
	if cf.radlink                    do strings.write_string(&sb, " -radlink")

	if cf.vet                    do strings.write_string(&sb, " -vet")
	if cf.vet_cast               do strings.write_string(&sb, " -vet-cast")
	if cf.vet_semicolon          do strings.write_string(&sb, " -vet-semicolon")
	if cf.vet_shadowing          do strings.write_string(&sb, " -vet-shadowing")
	if cf.vet_style              do strings.write_string(&sb, " -vet-style")
	if cf.vet_tabs               do strings.write_string(&sb, " -vet-tabs")
	if cf.vet_unused             do strings.write_string(&sb, " -vet-unused")
	if cf.vet_unused_imports     do strings.write_string(&sb, " -vet-unused-imports")
	if cf.vet_unused_procedures  do strings.write_string(&sb, " -vet-unused-procedures")
	if cf.vet_unused_variables   do strings.write_string(&sb, " -vet-unused-variables")
	if cf.vet_using_param        do strings.write_string(&sb, " -vet-using-param")
	if cf.vet_using_stmt         do strings.write_string(&sb, " -vet-using-stmt")
	if len(cf.vet_packages) > 0 {
		fmt.sbprintf(&sb, " -vet-packages:%s", strings.join(cf.vet_packages, ",", context.temp_allocator))
	}

	for name in cf.custom_attributes {
		fmt.sbprintf(&sb, " -custom-attribute:%s", name)
	}
	for k, v in cf.defines {
		fmt.sbprintf(&sb, " -define:%s=%s", k, v)
	}
	// escape hatch: any flag not modeled above
	for k, v in cf.raw {
		if v == "" {
			fmt.sbprintf(&sb, " -%s", k)
		} else {
			fmt.sbprintf(&sb, " -%s:%s", k, v)
		}
	}


	for name, path in cfg.collections {
		fmt.sbprintf(&sb, " -collection:%s=%s", name, path)
	}

	return strings.to_string(sb)
}

// --- run a shell command and stream its output ----------------------------

run_command :: proc(command: string) -> bool {
	log.infof("running: %s", command)

	desc := os.Process_Desc{
		command = {"sh", "-c", command},
	}

	state, stdout, stderr, err := os.process_exec(desc, context.allocator)
	defer delete(stdout)
	defer delete(stderr)

	if err != nil {
		log.errorf("failed to run command: %v", err)
		return false
	}

	if len(stdout) > 0 do fmt.print(string(stdout))
	if len(stderr) > 0 do fmt.eprint(string(stderr))

	return state.exit_code == 0
}
