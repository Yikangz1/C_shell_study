#!/bin/csh -f 
#  Script:run_test.csh
#  run the test 

setenv VCS_VERSION 2019.06sp2  #set VCS version
setenv VERDI_VERSION 2019.06sp2 # set verdi version
setenv VCS_HOME /ux/cad3/cad/tools/synopsys/vcs_inst/vcs_${VCS_VERSION} # give VCS software directory
setenv VIVADO_LIB /ux/other2/cad/Xilinx/Xilinx_Vivado_SDK_2018.1_0405_1/Vivado/2018.1/data/verilog/src/ # ??????
setenv VERDI_HOME /ux/cad3/cad/tools/synopsys/verdi_inst/verdi_${VERDI_VERSION}  # give verdi software directory
setenv DEBUSSY_HOME ${VERDI_HOME}   # why call VERDI_HOME as DEBUSSY_HOME???

set vcs_cmd = "bsub -Is -q DIPD_Cross_Department /rh/cad/bin/qsy.2010 vcs@${VCS_VERSION} -kdb " # what is the usage of vcs_cmd ?? -kdb for filelist generation

set model_suffix = "rtl"
#link debussy for fsdb
set link_debussy

setenv TEST_ROOT `pwd` 

echo "TEST_ROOT is $TEST_ROOT" # the test root is where the run_com.csh and run.csh located.

set ltex_module = "lte"
set simv_args = ""
unset ltex_fpga
unset ltex
unset not_build_sim

echo "******************show the input argvs and the num of input argvs********************************"
echo "the num of input argvs: $#argv"
echo "the input argvs are as followings: $argv[1-$#argv]"
echo " $argv[1-2]"
echo " 3:$argv[3]"
echo " 4:$argv[4]"


foreach run_arg ( $argv[1-$#argv] ) # as the input argvs in this script are: ltec fpga  +sub_case=CW1 +test_case=SCH_CASE001
    if ( "$run_arg" =~ "${ltex_module}?") then  # by using foreach syntax, when one of the input argv(the first) regular match "lte", set ltex =ltec/lted/lteu i.e.
	      set ltex = `echo $run_arg | sed "s;-;;"` # what's the meaning of sed ??? (????????????)
				echo "ltex: $ltex (run_arg:$run_arg)"
    else if ( "$run_arg" == "fpga" ) then# by using foreach syntax, when one of the input argv(the second) exactly match "fpga", set ltex_fpga =fpga
        set ltex_fpga = "fpga"
			  echo "ltex_fpga: $ltex_fpga (run_arg:$run_arg)"
    else if ( "$run_arg" == "only_run" ) then
        set not_build_sim
				echo "not_build_sim: $not_build_sim (run_arg:$run_arg)"
    else
	      set simv_args = "$simv_args $run_arg"
				echo "simv_args: $simv_args (run_arg:$run_arg)"	# why the third input argv are  +sub_case=CW1 instead of " +sub_case=CW1 +test_case=SCH_CASE001"			????????????????????
    endif
end

set FULL_EXE_DIR = ${PRJ_ROOT}/sim/out/"$ltex"/exe # although $ltex =ltec/lted i.e., if you wanna put variable into a directory to creat a flexible path, you must add double quatation marks "" for the added variable 

echo "FULL_EXE_DIR : $FULL_EXE_DIR" # $FULL_EXE_DIR is used to store executable files

if (! -e ${FULL_EXE_DIR}/vcs/log ) then # if the directory ${FULL_EXE_DIR}/vcs/log not exist, make this directory
    mkdir -p ${FULL_EXE_DIR}/vcs/log
endif

# set sim build macro
set simbuild_args = "+define+INITIALIZE_MEMORY +define+SIMULATION"

# set sim incdir 
set sim_incdir = "+incdir+$PRJ_ROOT/rtl/catx/lte/include"

# set file list
set complist = ${PRJ_ROOT}/flist/catx_$ltex.vlst

if ( $?ltex_fpga ) then
    set complist = ${PRJ_ROOT}/flist/catx_"$ltex"_"$ltex_fpga".vlst
endif

echo "complist  $complist"

if ( ! -f $complist ) then
    echo "Error : File $complist not exists!"
    exit 1
endif

#-----------------------------------------------------------------------------
# Create the arguments needed to link in the debussy waveform dump
# if ${DEBUSSY_HOME} is set
#-----------------------------------------------------------------------------
if ( $?link_debussy ) then
  echo "INFO: Linking in debussy FSDB dump capability"

  if ( ! $?DEBUSSY_HOME ) then
    echo "ERROR: DEBUSSY_HOME is not defined when -debussy specified."
    exit 1
  else
      if (`uname` == Linux) then
        set DEBUSSY = "${DEBUSSY_HOME}/share/PLI/VCS/LINUX64" # set the lib for VCS
        set debussy_args = " -debug_access +define+DEBUSSY  " #set the configs for VCS
        set debussy_path = ""
      else
        set DEBUSSY = "${DEBUSSY_HOME}/share/PLI/vcs/SOLARIS2/"
        set debussy_args = " -debug_access +define+DEBUSSY  "
        set debussy_path = ""
      endif
      echo "INFO: DEBUSSY_HOME is defined - linking in debussy dump capability"
  endif
else
  echo "INFO: Linking in standard VCD dump capability"
  set debussy_args = ""
  set debussy_path = ""
endif

echo "start run vcs"

if ( ! $?not_build_sim) then # where is the testbench ???? only filelist???
$vcs_cmd -Mupdate  -Mmakeprogram=gmake \ # ?????????????????????????????????
+plusarg_save +libext+.v+.V  \        # ?????????????????????????????????
+vcs+lic+wait \# wait for the license
-full64 \ # the simulation enviroment is 64 bit system
+nospecify   \  # no path delay and timing checking
+notimingcheck \ # no timing checking in specify block
+v2k    \ # IEEE 1364-2001 verilog syntax
+error+100  \ # num of error less than 100
-Mdir=${FULL_EXE_DIR}/vcs/csrc_$model_suffix \ # allocate a directory to store the compiled files generated by VCS
+systemverilogext+.sv \ # assign the suffix for systemverilog files
-o ${FULL_EXE_DIR}/vcs/vcs_$model_suffix \  # this is the executable file generated by VCS(because only after VCS using verilog generates the executable file, then run this executable file to conduct simulation)
-l ${FULL_EXE_DIR}/vcs/log/vcs_${model_suffix}.log\  # give the directory and name of the .log file to record the compiled and simlation results. 
$simbuild_args \  #"+define+INITIALIZE_MEMORY +define+SIMULATION"
$sim_incdir \  #"+incdir+$PRJ_ROOT/rtl/catx/lte/include"
$debussy_args \ # " -debug_access +define+DEBUSSY  " 
-f $complist # give the filelist
endif

echo "******************************before pushd command****************************************"
echo "the current directory pwd (before pushd ):`pwd`"

# run sim
pushd $outpath
echo "the current directory pwd (after pushd ):`pwd`"

echo "run sim"

#
# Create the arguments needed to link in the debussy waveform dump
# if ${DEBUSSY_HOME} is set
#

if ( $?DEBUSSY_HOME ) then
        echo "INFO: DEBUSSY_HOME is defined - linking in debussy dump capability"
        set debussy_path_vcs = ${DEBUSSY_HOME}/share/PLI/VCS/LINUX
else
        echo "INFO: DEBUSSY_HOME is not defined - linking in vcd dump capability"
        set debussy_path_vcs = ""
endif

setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:$debussy_path_vcs
set simv = "bsub -Is -q DIPD_Cross_Department ${FULL_EXE_DIR}/vcs/vcs_${model_suffix}"

$simv +vcs+lic+wait \
      +notimingchecks +warn=noSTASKW_CO \
      +$simv_args \
      `if ( -e ${testpath}/test_plusargs ) cat ${testpath}/test_plusargs | perl -pe 's/-[^\s]+//g' ` \
      -l ${FULL_EXE_DIR}/vcs/log/vcs_run_${model_suffix}.log
echo ${FULL_EXE_DIR}/vcs/log/vcs_run_${model_suffix}.log


echo "========================================="
echo "$ltex test finished"
echo "=========================================" 
exit
