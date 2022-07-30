#!/bin/bash
# Scripts to create dt.img from Spreadtrum device tree files (dts)
# Originally edited from sprd_tool repo
# (see https://github.com/koquantam/sprd_tool)
# 2018: Edited for kernel tree support by Nguyen Tuan Quyen
# 2020: Edited by steadfasterX to fully support building as part of AOSP

filename=$(basename $0)
dtimg="dt.img"
output_prefix=$(pwd)
status="none"
declare -a dts_array
dts_path=arch/arm/boot/dts

function help() {
	echo "$filename [-h|-i <dts>|-o <img>]"
	echo "  -h: help"
	echo "  -ks: kernel source path"
	echo "  -ko: kernel out path"
	echo "  -i: input dts files"
	echo "  -o: output dt.img file"
	exit
}

function push_content {
	if [[ $status == "input" ]]; then
		dts_array[${#dts_array[@]}]=$1
	elif [[ $status == "output" ]]; then
		dtimg=$1
	fi
}

if (($#>0)); then
	while [ -n "$1" ]; do
		case $1 in
			-h) help ;;
			-i) status="input" ;;
			-o) status="output" ;;
			-ks) KERNELSOURCE=$2; shift
			[ ! -d $KERNELSOURCE ]  && echo "ERROR: $KERNELSOURCE does not exist!" && exit 88
			;;
			-ko) KERNEL_OUT=$2; shift
			[ ! -d $KERNEL_OUT ]  && echo "ERROR: $KERNEL_OUT does not exist!" && exit 88
			;;
			*) push_content $1 ;;
		esac
		shift 1
	done
else
	help
fi

if ((${#dts_array[@]} == 0)); then
	help
fi

[ -z "$KERNELSOURCE" ] && KERNELSOURCE=$(pwd)
TOOL_DTBTOOL=$KERNELSOURCE/scripts/dtbTool
dtc_path=$KERNELSOURCE/scripts/dtc

echo "input: ${dts_array[@]}"
echo "output: $dtimg"
echo "dts_path: $dts_path"
echo "ks: $KERNELSOURCE"
echo "output_prefix: $output_prefix"
echo "cur dir: $(pwd)"

# ensure all dependencies are available on AOSP builds
cp -r $KERNELSOURCE/$dts_path/* $KERNELSOURCE/$dts_path/.s* $KERNEL_OUT/$dts_path/

# remove kernel created dtb files as these will cause duplicates later
rm $KERNEL_OUT/$dts_path/*.dtb

# process all files with dtc
for dts_file in ${dts_array[@]}; do
	echo "checking: $dts_file"
	if [ -e $KERNEL_OUT/$dts_path/$dts_file ]; then
	    echo "ok: $dts_file present. starting DTC convert..."
	    $dtc_path/dtc -I dts -O dtb -o $KERNEL_OUT/$dts_path/$dts_file.dtb -i $KERNEL_OUT/$dts_path $dts_file
	    ERR=$?
	    [ $ERR -ne 0 ] && echo "ERROR: returned $ERR while processing $dts_file" && exit $ERR
	else
	    echo "ERROR NOTHING HERE: $KERNEL_OUT/$dts_file"
	    exit 99
	fi
done
echo "dtb processing finished"

# do not miss the SLASH '/' at the end !! that took me a day to find out why suddenly dt creation failed with
# parsing errors!
$TOOL_DTBTOOL -o $dtimg $KERNEL_OUT/arch/arm/boot/dts/ -p $dtc_path/
exit $?
