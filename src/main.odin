package ratatoskr

import toml "libs:toml/src"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:log"

main :: proc() {
	context.logger = log.create_console_logger(.Debug)

	if len(os.args) < 2 {
		fmt.eprintln("usage: raratoskr <command> [flags]")
		fmt.eprintln("commands: build, add-collection, update, init")
		os.exit(1)
	}

	command := os.args[1]
	rest := os.args[2:]

	switch command {
	case "build":
		release := false
		debug := false
		development := false
		config_path := ""



		for arg in rest {

			switch {
			case arg == "--release":
				release = true
			case arg == "--debug":
				debug = true
			case arg == "--development":
				development = true
			case strings.has_prefix(arg, "--config="):
				config_path = arg[len("--config="):]
			case:
				fmt.eprintfln("unknown flag: %s", arg)
				os.exit(1)


			}
		}

		output_count := int(release) + int(debug) + int(development)
		if output_count != 1 {
			fmt.eprintln("error: pick exactly one of --release, --debug, --development")
			os.exit(1)
		}

		cmd_build(release, debug, development, config_path)

	case "add-collection":
		if len(rest) < 1 {
			fmt.eprintln("error: add-collection requires a collection name")
			os.exit(1)
		}
		name := rest[0]
		folder := ""
		github := ""

		for arg in rest[1:] {
			if strings.has_prefix(arg, "--folder=") {
				folder = arg[len("--folder="):]
			} else if strings.has_prefix(arg, "--github=") {
				github = arg[len("--github="):]
			} else {
				fmt.eprintfln("unknown flag: %s", arg)
				os.exit(1)
			}
		}

		has_folder := folder != ""
		has_github := github != ""

		if has_folder == has_github {
			fmt.eprintln("error: pick exactly one of --folder or --github")
			os.exit(1)
		}

		cmd_add_collection(name, folder, github)

	case "update":
		collection := ""
		if len(rest) > 0 {
			collection = rest[0]
		}
		cmd_update(collection)

	case "init":
		path := ""
		if len(rest) > 0 {
			path = rest[0]
		}
		cmd_init(path)

	case:
		fmt.eprintfln("unknown command: %s", command)
		os.exit(1)
	}
}

// --- build ---------------------------------------------------------------

cmd_build :: proc(release, debug, development: bool, config_path: string) {
	cfg, ok := load_project_config(config_path)
	if !ok {
		log.error("failed to load project config")
		os.exit(1)
	}

	b_ok: bool = false
	if release {
		b_ok = release_mode(cfg)
	} else if debug {
		b_ok = debug_mode(cfg)
	} else if development {
		b_ok = development_mode(cfg)
	}

	if !b_ok {
		log.error("build failed")
		os.exit(1)
	} else {
		log.info("build succeeded")
	}
}

release_mode :: proc(cfg: Project_Config) -> bool {
	log.info("building release mode")

	sb: strings.Builder
	strings.builder_init(&sb, context.temp_allocator)
	fmt.sbprintf(&sb, "odin build %s -o:speed -disable-assert -no-bounds-check", cfg.project.path)
	strings.write_string(&sb, add_compiler_options(cfg, context.temp_allocator))

	out_path := cfg.output["release"]
	if out_path == "" {
		log.error("no output path configured for 'release' in [output]")
		log.debugf("output path: %v", cfg.output)
		return false
	}
	fmt.sbprintf(&sb, " -out:%s", out_path)

	return run_command(strings.to_string(sb))
}

debug_mode :: proc(cfg: Project_Config) -> bool {
	log.info("building debug mode")

	sb: strings.Builder
	strings.builder_init(&sb, context.temp_allocator)
	fmt.sbprintf(&sb, "odin build %s -debug -o:none", cfg.project.path)
	strings.write_string(&sb, add_compiler_options(cfg, context.temp_allocator))

	out_path := cfg.output["debug"]
	if out_path == "" {
		log.error("no output path configured for 'debug' in [output]")
		return false
	}
	fmt.sbprintf(&sb, " -out:%s", out_path)

	return run_command(strings.to_string(sb))
}

development_mode :: proc(cfg: Project_Config) -> bool {
	log.info("building development mode")

	sb: strings.Builder
	strings.builder_init(&sb, context.temp_allocator)
	fmt.sbprintf(&sb, "odin build %s -debug", cfg.project.path)
	strings.write_string(&sb, add_compiler_options(cfg, context.temp_allocator))

	out_path := cfg.output["development"]
	if out_path == "" {
		log.error("no output path configured for 'development' in [output]")
		return false
	}
	fmt.sbprintf(&sb, " -out:%s", out_path)

	return run_command(strings.to_string(sb))
}

load_project_config :: proc(config_path: string = "") -> (cfg: Project_Config, ok: bool) {
	log.info("loading project config")

	dir, w_err := os.get_working_directory(context.allocator)
	defer delete(dir)

	if w_err != nil {
		log.errorf("failed to get working directory: %v", w_err)
		return {}, false
	}

	file_path: string
	if config_path != "" {
		file_path = config_path
	} else {
		file_path, err := filepath.join([]string{dir, "project.toml"})
		defer delete(file_path)
		if err != .None {
			log.error("failed to join project.toml path")
			return {}, false
		}
	}


	data, r_err := os.read_entire_file(file_path, context.allocator)
	defer delete(data)

	if r_err != nil {
		log.errorf("failed to read project.toml: %v", r_err)
		return {}, false
	}

	u_err := toml.unmarshal(data, &cfg)
	if u_err != .None {
		// TODO: destroy_project_config(&cfg) before returning, to avoid
		// leaking any fields the unmarshaler managed to fill before failing.
		log.errorf("failed to unmarshal project.toml: %v", u_err)
		return {}, false
	}

	log.info("project config loaded successfully")
	return cfg, true
}

// --- add-collection --------------------------------------------------------

cmd_add_collection :: proc(name, folder, github: string) {
	if folder != "" {
		fmt.printfln("adding collection %q from folder %q", name, folder)
		// TODO: copy/link folder, register in Project_Config.collections
	} else {
		fmt.printfln("adding collection %q from github %q", name, github)
		// TODO: git clone github, register in Project_Config.collections
	}
}

// --- update ----------------------------------------------------------------

cmd_update :: proc(collection: string) {
	if collection == "" {
		fmt.println("updating all collections")
		// TODO: iterate Project_Config.collections, pull each
	} else {
		fmt.printfln("updating collection %q", collection)
		// TODO: pull just this one, error if it doesn't exist
	}
}

// --- init --------------------------------------------------------------------

cmd_init :: proc(path: string) {
	dir := path

	if strings.trim(dir, " ") == "" {
		cwd, w_err := os.get_working_directory(context.allocator)
		if w_err != nil {
			log.errorf("failed to get working directory: %v", w_err)
			os.exit(1)
		}
		dir = cwd
	}
	defer if path == "" do delete(dir)

	file_path, err := filepath.join([]string{dir, "project.toml"})
	defer delete(file_path)

	if err != .None {
		log.error("failed to join project.toml path")
		os.exit(1)
	}

	log.infof("initializing project at %q", dir)
	file_err := os.write_entire_file(file_path, replace_template(#load("../template.toml"), get_folder_name(path), path, context.allocator))

	if file_err != nil {
		log.errorf("error: failed to write project.toml: %v", file_err)
		os.exit(1)
	}
}
