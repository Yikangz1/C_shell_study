#!/bin/csh -f

set CURDIR=`dirname $0`
set PRJDIR = `cd $CURDIR/../.. && pwd`

setenv PRJ_ROOT ${PRJDIR}
set ini_name = $argv[1]
unset report_append
unset use_cfg
if ( "$ini_name" =~ "lte?_*.ini") then
	if(2 == $#argv) then
		if("append" == $argv[2]) then
		set report_append
		endif
	endif
	#set lte_x = `echo $ini_name | sed "s;_test*.ini;"`
	# get ltex from configuration file.
	set lte_x = `echo $ini_name | awk -F '_' '{print $1}'`

	setenv testpath ${PRJ_ROOT}/sim/tests/$lte_x
	setenv outpath  ${PRJ_ROOT}/sim/out/$lte_x

	#set datapath
	set datapath=${PRJ_ROOT}/sim/tests/$lte_x/data/input/

	if ( ! -e ${testpath}/config/${ini_name} ) then
		echo "ERROR: test flie $testpath/config/$ini_name not found by $0"
	    set usage
	endif
	set use_cfg
	set ini_file = ${testpath}/config/${ini_name}
	echo "ltex:$lte_x,testpath:$testpath"
	echo "file path:$ini_file"
	
else
	setenv testpath ${PRJ_ROOT}/sim/tests/$argv[1]
	setenv outpath  ${PRJ_ROOT}/sim/out/$argv[1]
endif

if ( ( ! -d $testpath ) && !(( "$1" == "-h" ) || ( "$1" == "-help" )) ) then
	echo "ERROR: test directory $testpath not found by $0"
    set usage
endif

if ( $#argv == 0 ) then
    set usage
endif

if ( ( $?usage ) || ( "$1" == "-h" ) || ( "$1" == "-help" )) then
        cat <<EOU
Usage:
  run_com <test name> [options] [other plusargs]

    run_com launches a vcs simulation executable on the test
    specified by the argument <test name>

  Options:
     -help        - Display helpful messages.
     ltex         - ltex test module
     fpga         - use fpga ip
     run          - only run sim, not build sim.

  The resulting output is placed in the directory:
      sim/out/<argv[1]>/result/
EOU
	exit 1
endif


#if ( ! -d $outpath/) then
#mddir output/result output/diff ,copy data from tests/xxx/ to  out/xxx/
    mkdir -p $outpath
    cp -rf $testpath/data ${outpath}/
    mkdir -p $outpath/data/diff
    mkdir -p $outpath/data/result
#    rm -rf $outpath/result/*
#    rm -rf $outpath/diff/*
#endif
    cp  $PRJ_ROOT/rtl/catx/lte/include/*.rcf $outpath/
# Set simulation result output path
setenv sim_result_path $outpath/data/result/

# Set expect result path
setenv exp_result_path $outpath/data/expect/

# Set compare simulation result with expect result output path
setenv com_result_path $outpath/data/diff/

# Final report file
setenv report_file ${PRJ_ROOT}/sim/out/report.txt

if ($?report_append) then
	echo "Catx simulation: $argv[1]" >> $report_file
else
	echo "Catx simulation: $argv[1]" > $report_file
endif
echo "" >> $report_file
echo "Start run time:" >> $report_file
date >> $report_file

if ( $?use_cfg ) then
   set section = Module
   set key = module

   #set key_module = `awk -F '=' '/\['$section'\]/{a=1} a==1&&$1~/'$key'/ {print $2;exit}' $ini_file` 
   #alias get_key 'awk -F '\''='\'' '\''/['\''$section'\'']/{a=1} a==1&&$1~/'\''$key'\''/ {print $2;exit}'\'' $ini_file'
   # get_key is get vaule of $1-section : $2-param 
   alias get_key 'awk -F '\''='\''  '\''/\['\''\!:1'\''\]/{a=1} a==1&&$1~/'\''\!:2'\''/ {print $2;exit}'\'' $ini_file'
   # get_simop is get simulation options, use :=
   alias get_simop 'awk -F '\'':='\''  '\''/\['\''\!:1'\''\]/{a=1} a==1&&$1~/'\''\!:2'\''/ {print $2;exit}'\'' $ini_file'

   alias get_key_sub 'awk -F '\''[+=]'\''  '\''/\['\''\!:1'\''\]/{a=1} a==1&&$3~/'\''\!:2'\''/ {print $4;exit}'\'' $ini_file'
   alias get_key_test 'awk -F '\''[+=]'\''  '\''/\['\''\!:1'\''\]/{a=1} a==1&&$5~/'\''\!:2'\''/ {print $6;exit}'\'' $ini_file'
   
   # get ltex module
   set  key_module = `get_key $section $key`
   echo "module is: $key_module"
   
   # get fpga param, NULL:use asic ram, FPGA:use fpga ram
   set key_fpga = `get_key Module fpga`
   echo "fpga is :$key_fpga"

   # get run_all flag
   set key_runall = `get_key Module run_all`
   echo "runall is :$key_runall"

   # get test-case count
   set case_num = `get_key Module case_cnt`
   echo "the case_num is $case_num"

   set j = 0
   set i = 0
   
   if( "1" == $key_runall) then
	set sub_case =  `ls $datapath`
	set key_simop = ""
	set key_run = ""
	foreach sub_test  ( $sub_case )

		echo $sub_test
		set test_case_path=${PRJ_ROOT}/sim/tests/$lte_x/data/input/$sub_test
		set test_cases =  `ls $test_case_path`
		foreach test_case  ( $test_cases )
			# only build simulation in first testcase
			@ j = $j + 1
			if( "2" == $j ) then
			    set key_run = "only_run"
			endif
			echo $test_case
			set key_simop = "+sub_case=$sub_test +test_case=$test_case"

			echo "./run.csh $key_module $key_fpga $key_run $key_simop"
			#./run.csh $key_module $key_fpga $key_run $key_simop
		end
	end
   else
	   # get all test-case in config.ini
	   set key_run = ""
	   set j = 1
	   while( $j <= $case_num)
		#echo "j is $j, case_num is $case_num"
		# get simulation options
		#set key_simop = `get_simop Case$j sim_op`
		if( "2" == $j ) then
		    set key_run = "only_run"
		endif
		set sub_test = `get_key_sub Case$j sub_case`
		set test_case = `get_key_test Case$j test_case`

		echo "test_case is $test_case"
		if ("" == $test_case) then
			echo "$sub_test"
			set test_case_path=${PRJ_ROOT}/sim/tests/$lte_x/data/input/$sub_test
			set test_cases =  `ls $test_case_path`
			foreach test_case  ( $test_cases )
				# only build simulation in first testcase
				@ i += 1
				if( "2" == $i ) then
				    set key_run = "only_run"
				endif
				echo "$test_case"
				set key_simop = "+sub_case=$sub_test +test_case=$test_case"

				echo "./run.csh $key_module $key_fpga $key_run $key_simop"
				./run.csh $key_module $key_fpga $key_run $key_simop
			end
		else
			set key_simop = `get_simop Case$j sim_op`
			echo "./run.csh $key_module $key_fpga $key_run $key_simop"
			./run.csh $key_module $key_fpga $key_run $key_simop
		endif
		@ j++

	   end
   endif
else
    ./run.csh $argv[1-$#argv]
endif

echo "Finish run time:" >> $report_file
date >> $report_file
echo "" >> $report_file

echo "Catx: Check $argv[1] simulation result."
echo "Catx: Check $argv[1] simulation result." >> $report_file

set sys_testcases =  `ls $sim_result_path`

set err_num = 0
set i = 0

foreach sys_test  ( $sys_testcases ) 
  @ i = $i + 1
  echo ""
  echo "" >> $report_file
  echo "Simulation result compare file $i."
  echo "Simulation result compare file $i." >> $report_file

  if ( -f $sim_result_path$sys_test ) then 

#  	if($sys_test =~ "CASE*_PCFICH_RAM.dat") then
#        sed -n '3,10p' $sim_result_path$sys_test >> $sim_result_path$sys_test
#        sed -n '1p'    $sim_result_path$sys_test >> $sim_result_path$sys_test
#        sed -i '1,10d' $sim_result_path$sys_test	
#        diff -b $sim_result_path$sys_test $exp_result_path$sys_test > $com_result_path$sys_test
#    
#
#	else
        diff -b $sim_result_path$sys_test $exp_result_path$sys_test > $com_result_path$sys_test
	#endif
  else
    echo "Error : File $sim_result_path$sys_test not exists!"
    echo "Error : File $sim_result_path$sys_test not exists!" >> $report_file
    exit
  endif

  if ( -f $com_result_path$sys_test ) then 
    echo "File $com_result_path$sys_test exists."
    echo "File $com_result_path$sys_test exists." >> $report_file
    test -s $com_result_path$sys_test || echo "Simulation PASS."
    test -s $com_result_path$sys_test || echo "Simulation PASS." >> $report_file
    test -s $com_result_path$sys_test && echo "Simulation Error!"
    test -s $com_result_path$sys_test && echo "Simulation Error!" >> $report_file 
    test -s $com_result_path$sys_test && @ err_num = $err_num + 1

  else
    echo "File $com_result_path$sys_test not exists!"
    echo "File $com_result_path$sys_test not exists!" >> $report_file
    exit
  endif
end


if ($err_num != 0) then
    echo "Simulation ERROR !"
    echo "Simulation ERROR !" >> $report_file
else
    echo "Simulation All PASS !"
    echo "Simulation All PASS !" >> $report_file
endif
