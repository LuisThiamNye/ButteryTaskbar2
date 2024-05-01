#run build();

build :: () {
	options:= get_build_options();
	args:= options.compile_time_command_line;

	set_build_options_dc(.{do_output=false});

	set_optimization(*options, .VERY_DEBUG);
	options.output_path = "out";
	options.output_executable_name = "debug";
	options.backend = .X64;

	should_execute:= false;
	debug_mode:= false;
	is_release:= false;
	for arg: args {
		if arg == {
			case "debug";
				debug_mode = true;
			case "dev";
				options.text_output_flags = 0;
				should_execute = true;
			case "norun";
				should_execute = false;
			case "release";
				log("Building release-mode, version %", app_version);
				set_optimization(*options, .VERY_OPTIMIZED);
				options.output_executable_name = "buttery-taskbar";
				options.backend = .LLVM;
				options.array_bounds_check = .OFF;
				options.cast_bounds_check = .OFF;
				options.arithmetic_overflow_check = .OFF;
				options.null_pointer_check = .OFF;
				options.backtrace_on_crash = .OFF;
				options.dead_code_elimination = .ALL;
				options.stack_trace = false;
				is_release = true;
		}
	}


	// :nullify_print_and_log_statements
	// This is probably not needed anymore now that empty macros are used instead.
	wgen:= compiler_create_workspace("gen");
	set_build_options_dc(.{do_output=false}, wgen);
	compiler_begin_intercept(wgen);
	add_build_string("goat_returns_0::()->s64{return 0;}", wgen);
	goat_returns_0_statements: []*Code_Node;
	while 1 {
		message:= compiler_wait_for_message();
		if message.workspace != wgen continue;
		if message.kind == {
			case .COMPLETE; break;
			case .TYPECHECKED;
				typechecked:= cast(*Message_Typechecked) message;
				for tc: typechecked.procedure_bodies {
					if tc.expression.header.name == "goat_returns_0" {
						goat_returns_0_statements = tc.expression.block.statements;
					}
				}
		}
	}
	compiler_end_intercept(wgen);


	w:= compiler_create_workspace(options.output_executable_name);
	set_build_options(options, w);
	if is_release
		set_build_options_dc(.{append_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup"]}, w);

	intercept_flags: Intercept_Flags;

	compiler_begin_intercept(w, intercept_flags);

	calendar_time:= to_calendar(current_time_consensus());
	month_names :: string.["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
	build_date_string:= tprint("% % %", calendar_time.day_of_month_starting_at_0+1, month_names[calendar_time.month_starting_at_0], calendar_time.year);
	add_build_string(tprint("BUILD_DATE_STRING::\"%\";", build_date_string), w);

	if is_release {
		add_build_string("RELEASE_MODE::true;", w);
	} else {
		add_build_string("RELEASE_MODE::false;", w);
	}
	add_build_file("main.jai", w);

	#import "Ico_File";
	ico_data := create_ico_file_from_bitmap_filename(LOCAL_ENV_ICON_FILE_PATH);
	if ico_data {
		add_build_string("USE_DEFAULT_ICON::false;", w);
	} else {
		add_build_string("USE_DEFAULT_ICON::true;", w);
	}

	there_were_errors:= false;
	while 1 {
		message:= compiler_wait_for_message();
		if message.workspace != w continue;
		if message.kind == {

			case .COMPLETE;
				complete := cast(*Message_Complete) message;
				if complete.error_code != .NONE {
						there_were_errors = true;
				}
				break;

			case .TYPECHECKED;
				typechecked:= cast(*Message_Typechecked) message;
				for tc: typechecked.procedure_bodies {
					info:= tc.expression.header;
					// :nullify_print_and_log_statements
					if is_release
						&& info.enclosing_load.enclosing_import
						&& info.enclosing_load.enclosing_import.module_name == "Basic"
						&& (info.name == "log" || info.name == "log_error" || info.name == "print")
						&& !(tc.expression.body_flags & .ALREADY_MODIFIED) {
							block:= tc.expression.block;
							if info.name=="print" {
								block.statements = goat_returns_0_statements;
							} else {
								block.statements = .[];
							}

							// I doubt this does anything...
							info.procedure_flags += .MACRO;
							compiler_make_procedure_live(w, info);

							compiler_modify_procedure(w, tc.expression);
					}
				}

			case .PHASE;
				phase:= cast(*Message_Phase) message;
				if phase.phase == .POST_WRITE_EXECUTABLE {
					#import "Windows_Resources";
					exe_path:= join(options.output_path, "/", phase.executable_name);
					if ico_data {
						#import "File";
						if !set_icon_by_data(exe_path, ico_data, ICON_RESOURCE_ID) {
							log_error("Failed to set icon % for the exe file %", LOCAL_ENV_ICON_FILE_PATH, exe_path);
							there_were_errors = true;
						}
					}
					manifest_options:= Manifest_Options.{dpi_aware = true};
					if !add_manifest_to_executable(exe_path, manifest_options) {
						log_error("Failed to add manifest to exe file %\n", exe_path);
						there_were_errors = true;
					}
				}
		}
	}

	compiler_end_intercept(w);

	if !there_were_errors && should_execute  autorun_the_exe(w, debug_mode);
}

autorun_the_exe :: (w: Workspace, use_debugger: bool) {
	using options := get_build_options(w);
	if output_type == .EXECUTABLE {
		run_string := ifx output_path then join(output_path, "/", output_executable_name,, temp) else output_executable_name;
		log("Running: %\n", run_string);
		result := ifx use_debugger
			then Process.run_command("remedybg.exe", "-g", "-q", "Buttery_Taskbar.rdbg")
			else Process.run_command(run_string);
		if result.exit_code != 0 {
			if result.type == {
				case .FAILED_TO_LAUNCH; log_error("Program failed to launch.");
				case .EXITED;           log_error(tprint("Program exited with code %.", result.exit_code));
				case .SIGNALED;         log_error(tprint("Program quit due to signal %.", result.signal));
				case;                   log_error(tprint("Unexpected result from running the program: %", result));
			}
		}
	}
}

#load "local_environment.jai";
#load "shared.jai";
#import "Compiler";
#import "Basic";
#import "String";
Process :: #import "Process";
