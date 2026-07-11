package ratatoskr

import "core:time"

Date :: struct {
	year:  int,
	month: time.Month,
	day:   int,
}

// [ Compiler flags ]

Build_Mode :: enum {
	Exe,
	Test,
	Dll,
	Lib,
	Obj,
	Assembly,
	LLVM_IR,
}

Optimization_Mode :: enum {
	None,
	Minimal,
	Size,
	Speed,
	Aggressive,
}

Sanitize_Mode :: enum {
	Address,
	Memory,
	Thread,
}

Source_Code_Locations_Mode :: enum {
	Normal,
	Obfuscated,
	Filename,
	None,
}

// Models the most common `odin build` flags in a typed way.
// Each field uses Maybe(T) or zero-value ("", false, nil) for "unset":
// when unset, raratoskr does not emit that flag when compiling.
Compiler_Flags :: struct {
	build_mode:             Maybe(Build_Mode),
	optimization:           Maybe(Optimization_Mode),
	sanitize:               Maybe(Sanitize_Mode),
	source_code_locations:  Maybe(Source_Code_Locations_Mode),

	target:                 string, // -target:<string>
	subtarget:              string, // -subtarget:<ios|android>
	microarch:              string, // -microarch:<string>
	target_features:        string, // -target-features:<string>
	linker:                 string, // -linker:<default|lld|radlink>
	out:                    string, // -out:<filepath>

	thread_count:           Maybe(int), // -thread-count:<integer>
	max_error_count:        Maybe(int), // -max-error-count:<integer>

	debug:                     bool,
	disable_assert:            bool,
	disable_red_zone:          bool,
	disallow_do:               bool,
	dynamic_map_calls:         bool,
	no_bounds_check:           bool,
	no_crt:                    bool,
	no_entry_point:            bool,
	no_rpath:                  bool,
	no_thread_local:           bool,
	no_threaded_checker:       bool,
	no_type_assert:            bool,
	ignore_warnings:           bool,
	ignore_unknown_attributes: bool,
	warnings_as_errors:        bool,
	use_separate_modules:      bool,
	use_single_module:         bool,
	keep_temp_files:           bool,
	keep_executable:           bool,
	strict_style:              bool,
	strict_target_features:    bool,
	min_link_libs:             bool,
	lld:                       bool,
	radlink:                   bool,

	vet:                   bool,
	vet_cast:              bool,
	vet_semicolon:         bool,
	vet_shadowing:         bool,
	vet_style:             bool,
	vet_tabs:              bool,
	vet_unused:            bool,
	vet_unused_imports:    bool,
	vet_unused_procedures: bool,
	vet_unused_variables:  bool,
	vet_using_param:       bool,
	vet_using_stmt:        bool,
	vet_packages:          []string, // -vet-packages:<comma-separated>

	defines:               map[string]string, // -define:NAME=VALUE
	custom_attributes:     []string,          // -custom-attribute:...
	extra_linker_flags:    string,
	extra_assembler_flags: string,

	// Escape hatch: any flag the compiler supports that this struct
	// does not yet model explicitly (or new flags from future compiler
	// versions). key = flag name without "-", value = value ("" if
	// the flag takes no value, e.g. "-debug").
	raw: map[string]string,
}

// [ Project config ]

Project_Config :: struct {
	project: struct {
		name:    string,
		version: string,
		authors: []string,
		path:    string,
	},
	output:      map[string]string,
	collections: map[string]string,
	compiler:    Compiler_Flags,
	events:      Events_Scripts,
	defines:     map[string]string,
}

Events_Scripts :: struct {
	before_build: string,
	after_build:  string,
	before_run:   string,
	after_run:    string,
}

// [ Project lock ]

Project_Lock :: struct {
	odin_version: string,
	collections:  map[string]Collection,
}

// Local way to distinguish updates from the first pull from GitHub.
Collection_Version :: Date

Collection :: struct {
	path:             string,
	ref:              string, // commit hash or exact tag, for reproducible builds
	last_repo_update: Collection_Version,
	last_git_pull:    Collection_Version,
	pulls:            u32,
}
