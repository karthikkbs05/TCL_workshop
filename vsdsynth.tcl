#!/bin/env tclsh

set generate_sdc 1 

set working_dir [exec pwd]
set length_file [llength [split [lindex $argv 0] .]]
set extention [lindex [split [lindex $argv 0] .] $length_file-1]

if {![regexp {^csv} $extention] || $argc!=1} {
	puts "ERROR : more files or no csv file"
	exit 
} else {
	set filename [lindex $argv 0]
        package require csv
        package require struct::matrix
	struct::matrix m
        set f [open $filename]
        csv::read2matrix $f m , auto
	close $f
        m link my_arry
	set columns [m columns]
    	set no_of_rows [m rows]
	set i 0

	while {$i < $no_of_rows} {
		puts "\nINFO: creating $my_arry(0,$i) and equating it to $my_arry(1,$i)"
		if {$i == 0 } {
			 set [string map {" " ""} $my_arry(0,$i)] $my_arry(1,$i)
		 } else {
			 set [string map {" " ""} $my_arry(0,$i)] [file normalize $my_arry(1,$i)]
		 }
		 set i [expr {$i+1}]
	 }
 }

if {![file isdirectory $OutputDirectory]} {
	puts "no output directory found, so creating a output directory "
	file mkdir $OutputDirectory
}
if {![file exists $NetlistDirectory]} {
	puts "no netlist directory. exiting...."
	exit
}
if {![file exists $LateLibraryPath]} {
	puts "no late library found. exiting..."
	exit
}
if {![file exists $ConstraintsFile]} {
        puts "no constraint file found. exiting..."
        exit
}
if {![file exists $EarlyLibraryPath]} {
        puts "no early library found. exiting..."
        exit
}


if {$generate_sdc == 1} {
	puts "INFO : generating SDC file for $DesignName using $ConstraintsFile"
	::struct::matrix constraints
	set cons_file [open $ConstraintsFile]
	csv::read2matrix $cons_file constraints , auto
	close $cons_file
	set cons_columns [constraints columns]
	set cons_rows [constraints rows]
	puts "done creating matrix" 

	set clock_start [lindex [lindex [constraints search all CLOCKS] 0] 1]
	set clock_column [lindex [lindex [constraints search all CLOCKS] 0] 0]

	set output_start [lindex [lindex [constraints search all OUTPUTS] 0] 1]
	set input_start [lindex [lindex [constraints search all INPUTS] 0] 1]
	puts " $clock_start , $clock_column , $output_start, $input_start"

	puts "opening SDC file"
	set sdc_file [open $OutputDirectory/$DesignName.sdc "w"]

	set clock_early_rise_delay_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] early_rise_delay] 0] 0]
	set clock_early_fall_delay_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] early_fall_delay] 0] 0]
	set clock_late_rise_delay_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] late_rise_delay] 0] 0]
	set clock_late_fall_delay_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] late_fall_delay] 0] 0]

	set clock_early_rise_slew_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] early_rise_slew] 0] 0]
	set clock_early_fall_slew_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] early_fall_slew] 0] 0]
	set clock_late_rise_slew_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] late_rise_slew] 0] 0]
	set clock_late_fall_slew_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] late_fall_slew] 0] 0]

	#set frequency_start [lindex [lindex [constraints search rec $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] frequency] 0] 0]

	puts "clock_early_rise_delay_start = $clock_early_rise_delay_start"
	set i [expr {$clock_start+1}]
	set e [expr {$input_start-1}]
	while {$i < $e} {
		puts -nonewline $sdc_file "\nset_clock_latency source -early -rise [constraints get cell $clock_early_rise_delay_start $i] \[get_ports [constraints get cell $clock_start $i]\]"
		puts -nonewline $sdc_file "\nset_clock_latency source -early -fall [constraints get cell $clock_early_fall_delay_start $i] \[get_ports [constraints get cell $clock_start $i]\]"
		puts -nonewline $sdc_file "\nset_clock_latency source -late -rise [constraints get cell $clock_late_rise_delay_start $i] \[get_ports [constraints get cell $clock_start $i]\]"
		puts -nonewline $sdc_file "\nset_clock_latency source -late -fall [constraints get cell $clock_late_fall_delay_start $i] \[get_ports [constraints get cell $clock_start $i]\]"

		puts -nonewline $sdc_file "\nset_clock_transition -rise -min [constraints get cell $clock_early_rise_slew_start $i] \[get_ports [constraints get cell $clock_start $i]\]"
		puts -nonewline $sdc_file "\nset_clock_transition -fall -min [constraints get cell $clock_early_fall_slew_start $i] \[get_ports [constraints get cell $clock_start $i]\]"
		puts -nonewline $sdc_file "\nset_clock_transition -rise -max [constraints get cell $clock_late_rise_slew_start $i] \[get_ports [constraints get cell $clock_start $i]\]"
		puts -nonewline $sdc_file "\nset_clock_transition -fall -max [constraints get cell $clock_late_fall_slew_start $i] \[get_ports [constraints get cell $clock_start $i]\]"

		puts -nonewline $sdc_file "\ncreate_clock -name [constraints get cell $clock_start $i] -period [constraints get cell 1 $i] -waveform {0 [expr {[constraints get cell 1 $i]*[constraints get cell 2 $i]/100}]} \[get_ports [constraints get cell $clock_column $i]\]"
		set i [expr {$i+1}]
	}

	set input_early_rise_delay_start [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] early_rise_delay] 0] 0]
	set input_early_fall_delay_start [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] early_fall_delay] 0] 0]
        set input_late_rise_delay_start [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] late_rise_delay] 0] 0]
	set input_late_fall_delay_start [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] late_fall_delay] 0] 0]
	set input_early_rise_slew_start [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] early_rise_slew] 0] 0]
        set input_early_fall_slew_start [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] early_fall_slew] 0] 0]
        set input_late_rise_slew_start [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] late_rise_slew] 0] 0]
        set input_late_fall_slew_start [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] late_fall_slew] 0] 0]
	set clock_early_rise_slew_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] early_rise_slew] 0] 0]
        set clock_early_fall_slew_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] early_fall_slew] 0] 0]
        set clock_late_rise_slew_start [lindex [lindex [constraints search rect $clock_column $clock_start [expr {$cons_columns-1}] [expr {$input_start-1}] late_rise_slew] 0] 0]
        set related_clock [lindex [lindex [constraints search rect $clock_column $input_start [expr {$cons_columns-1}] [expr {$output_start-1}] clocks] 0] 0]

	puts "extracting the ports"
	set i [expr {$input_start+1}]
	set e [expr {$output_start-1}]
	while {$i < $e} {
		 puts "iteration $i"
		 set netlists [glob -dir $NetlistDirectory *.v]
       		 set temp_file [open temp/tb w]
       		 foreach f $netlists {
			 puts "reading $f"
               		 set fb [open $f]
               		 while {[gets $fb line] != -1} {
                	       set pattern1 " [constraints get cell $clock_column $i];"
                      	       if { [regexp -all -- $pattern1 $line] } {
				         puts "pattern $pattern1 found"
                              		 set pattern2 [lindex [split $line ";"] 0]
                              		 if {[regexp -all {input} [lindex [split $pattern2 "\S+"] 0]]} {
						 puts "pattern $pattern1 as input"
                                      		 set s1 "[lindex [split $pattern2 "\S+"] 0] [lindex [split pattern2 "\S+"] 1] [lindex [split pattern2 "\S+"] 2]"
                                      		 puts -nonewline $temp_file "\n[regsub -all {\s+} $s1 " "]"
						 puts "updated"
					 }
				 }
			 }
			 close $fb
		 }
		 close $temp_file
		 
		 set temp_file [open temp/tb r]
		 set temp_file2 [open temp/tb2 w]
		 puts -nonewline $temp_file2 "[join [lsort -unique [split [read $temp_file] \n]] \n]"
		 close $temp_file2
		 close $temp_file

		 set temp_file2 [open temp/tb2 r]
		 set count [llength [read $temp_file2]]
		 if {$count > 2} {
			 set inp_ports [concat [constraints get cell 0 $i]*]
			 puts "$inp_ports is bussed"
		 } else {
			 set inp_ports [constraints get cell 0 $i]
			 puts "$inp_ports is not busses"
		 }

		 puts -nonewline $sdc_file "\nset_input_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -rise -source_latency_included [constraints get cell $input_early_rise_delay_start $i] \[get_ports $inp_ports\]"
		 puts -nonewline $sdc_file "\nset_input_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -fall -source_latency_included [constraints get cell $input_early_fall_delay_start $i] \[get_ports $inp_ports\]"
		 puts -nonewline $sdc_file "\nset_input_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -rise -source_latency_included [constraints get cell $input_late_rise_delay_start $i] \[get_ports $inp_ports\]"
		 puts -nonewline $sdc_file "\nset_input_delay -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -fall -source_latency_included [constraints get cell $input_late_rise_delay_start $i] \[get_ports $inp_ports\]"

		 puts -nonewline $sdc_file "\nset_input_transition -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -rise -source_latency_included [constraints get cell $input_early_rise_slew_start $i] \[get_ports $inp_ports\]"
                 puts -nonewline $sdc_file "\nset_input_transition -clock \[get_clocks [constraints get cell $related_clock $i]\] -min -fall -source_latency_included [constraints get cell $input_early_fall_slew_start $i] \[get_ports $inp_ports\]"
                 puts -nonewline $sdc_file "\nset_input_transition -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -rise -source_latency_included [constraints get cell $input_late_rise_slew_start $i] \[get_ports $inp_ports\]"
                 puts -nonewline $sdc_file "\nset_input_transition -clock \[get_clocks [constraints get cell $related_clock $i]\] -max -fall -source_latency_included [constraints get cell $input_late_rise_slew_start $i] \[get_ports $inp_ports\]"

		 set i [expr {$i+1}]


	 }
				                 		 
	 

}



	


