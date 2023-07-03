#run build();

build :: () {
	options: = get_build_options();
	args: = options.compile_time_command_line;

  set_build_options_dc(.{do_output=false});

	set_optimization(*options, .DEBUG);
	options.output_executable_name = "debug";
	options.backend = .X64;

	options.stack_trace = false;

	is_release: = false;
	for arg: args {
		if arg == {
			case "release";
				set_optimization(*options, .VERY_OPTIMIZED);
				options.output_executable_name = "buttery-taskbar";
				options.backend = .LLVM;
				options.array_bounds_check = .OFF;
				options.cast_bounds_check = .OFF;
				options.math_bounds_check = .OFF;
				options.null_pointer_check = .OFF;
				options.backtrace_on_crash = .OFF;
				options.dead_code_elimination = .ALL;
				is_release = true;
		}
	}


	// :nullify_print_and_log_statements
	wgen: = compiler_create_workspace("gen");
  set_build_options_dc(.{do_output=false}, wgen);
	// gen_opts: = get_build_options(wgen);
	// gen_opts.
  // set_build_options(gen_opts, wgen);
  compiler_begin_intercept(wgen);
  add_build_string("goat_returns_0::()->s64{return 0;}", wgen);
  goat_returns_0_statements: []*Code_Node;
  while 1 {
  	message: = compiler_wait_for_message();
  	if message.workspace != wgen continue;
  	if message.kind == {
  		case .COMPLETE; break;
  		case .TYPECHECKED;
  			typechecked: = cast(*Message_Typechecked) message;
  			for tc: typechecked.procedure_bodies {
  				if tc.expression.header.name == "goat_returns_0" {
  					goat_returns_0_statements = tc.expression.block.statements;
  				}
  			}
  	}
  }
  compiler_end_intercept(wgen);


  w: = compiler_create_workspace(options.output_executable_name);
  set_build_options(options, w);
  if is_release
		set_build_options_dc(.{append_linker_arguments=.["/SUBSYSTEM:windows", "/ENTRY:mainCRTStartup"]}, w);

  compiler_begin_intercept(w);
  if is_release {
  	add_build_string("RELEASE_MODE::true;", w);
  } else {
  	add_build_string("RELEASE_MODE::false;", w);
  }
  add_build_file("buttery-taskbar.jai", w);

  while 1 {
    message: = compiler_wait_for_message();
    if message.workspace != w continue;
    if message.kind == {
    	case .COMPLETE; break;
    	case .TYPECHECKED;
				typechecked: = cast(*Message_Typechecked) message;
				for tc: typechecked.procedure_bodies {
					info: = tc.expression.header;
					// :nullify_print_and_log_statements
					if is_release
						&& info.enclosing_load.enclosing_import != null
						&& info.enclosing_load.enclosing_import.module_name == "Basic"
						&& (info.name == "log" || info.name == "print")
						&& tc.expression.body_flags & .ALREADY_MODIFIED == 0 {
							block: = tc.expression.block;
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
    }
  }

  compiler_end_intercept(w);
}

#import "Compiler";
#import "Basic";
