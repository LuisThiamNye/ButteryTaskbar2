package buttery_taskbar

import "core:fmt"
import "core:os"
import "core:io"
import "core:time"

enable_logging :: #config(log, false)

log_file_name :: "buttery-taskbar-log.txt"
log_file: os.Handle = os.INVALID_HANDLE
log_file_writer: io.Writer

init_logger :: proc() {
	when enable_logging {
		file, err := os.open(log_file_name, os.O_APPEND | os.O_CREATE)
		if err != os.ERROR_NONE {fmt.println("failed to open log file")}
		log_file = file
		log_file_writer = io.to_writer(os.stream_from_handle(log_file))	
	}
}

log :: proc(args: ..any) {
	when ODIN_DEBUG {
		fmt.print("Log: ")
		fmt.println(..args)
	}
	when enable_logging {
		if log_file_writer.procedure != nil {
			hours, mins, seconds := time.clock_from_time(time.now())
			n := fmt.wprint(log_file_writer, args={hours, ":", mins, ":", seconds, " "}, sep="")
			for i in n..<10 {
				fmt.wprint(log_file_writer, " ")
			}
			fmt.wprintln(log_file_writer, ..args)
		}
	}
}
