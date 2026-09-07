#!/bin/sh

rate_stream () {
        case "$1" in
                truehd)
                        echo 99
                        ;;

                dts\ \(DTS-HD\ MA\))
                        echo 99
                        ;;

                pcm_s16le)
                        echo 95
                        ;;


                dts\ \(DTS\))
                        echo 90
                        ;;

                ac3)
                        echo 10
                        ;;

                *)
                        echo 0
                        ;;
        esac
}

get_video_stream() {
    echo $(ffmpeg -i "$1" &>/dev/stdout | grep "Stream.*: Video:" | head -n 1 | sed "s/^.*Stream #\([0-9]\+:[0-9]\+\).*/\1/g")
}

get_audio_map() {
    MAP=$(ffmpeg -i "$1" &>/dev/stdout | grep "Stream.*: Audio:" | sed "s/^.*Stream #\([0-9]\+:[0-9]\+\).*/\1/g")
    echo ${MAP//\\n/}
}

FFMPEG_COMMAND_H264_EXTRA="ffmpeg -y -v error -hide_banner -stats -threads 4 -i %q %s -c:v h264_qsv -spatial-aq 1 %s -b:v %s -an -sn -dn %q/.video/%q/%q.mkv"
FFMPEG_COMMAND_H264="$FFMPEG_COMMAND_H264_EXTRA"
#FFMPEG_COMMAND_H265="ffmpeg -init_hw_device qsv=hw -filter_hw_device hw -hwaccel qsv -hwaccel_output_format qsv -y -v error -hide_banner -stats -i %q %s -c:v hevc_qsv -spatial-aq 1 %s -b:v %s -an -sn -dn %q/.video/%q/%q.mkv"
FFMPEG_COMMAND_H265_EXTRA="ffmpeg -y -v error -hide_banner -stats -i %q %s -c:v hevc_qsv -spatial-aq 1 %s -b:v %s -an -sn -dn %q/.video/%q/%q.mkv"
FFMPEG_COMMAND_H265="$FFMPEG_COMMAND_H265_EXTRA"
#FFMPEG_COMMAND_AV1="ffmpeg -init_hw_device qsv=hw -filter_hw_device hw -hwaccel qsv -hwaccel_output_format qsv -y -v error -hide_banner -stats -i %q %s -c:v av1_qsv -spatial-aq 1 %s -b:v %s -an -sn -dn %q/.video/%q/%q.mkv"
FFMPEG_COMMAND_AV1_EXTRA="ffmpeg -y -v error -hide_banner -stats -i %q %s -c:v av1_qsv -spatial-aq 1 %s -b:v %s -an -sn -dn %q/.video/%q/%q.mkv"
FFMPEG_COMMAND_AV1="$FFMPEG_COMMAND_AV1_EXTRA"
FFMPEG_COMMAND_COPY="ffmpeg -y -v error -hide_banner -stats -threads 4 -i %q %s -c:v copy -an -sn -dn %q/.video/%q/%q.mkv"

FFMPEG_AUDIO_COMMAND="ffmpeg -y -v error -hide_banner -stats -i %q %s -c:a %s -vn -c:s copy -dn -c:t copy %q/.audio/%q/%q.mkv"

TARGET_DIR="/mnt/bigvol"

declare -A BEST_STREAMS
declare -A BEST_VALUES
CURRENT_FILE=$(echo "$1" | cut -d "|" -f 1)
CURRENT_TITLE=$(echo "$1" | cut -d "|" -f 2)
CURRENT_GROUP=$(echo "$1" | cut -d "|" -f 3)
CURRENT_BITRATE=$(echo "$1" | cut -d "|" -f 4)
CURRENT_AUDIO_PARAMS=$(echo "$1" | cut -d "|" -f 5)
CURRENT_LANG_WHITELIST=$(echo "$1" | cut -d "|" -f 6)
CURRENT_EXTRA_PARAMS=$(echo "$1" | cut -d "|" -f 7)
CURRENT_H265=0
CURRENT_AV1=0

for LANG in $CURRENT_LANG_WHITELIST; do
        BEST_VALUES[$LANG]="-1"
done

if [ "$CURRENT_TITLE" == "" ]; then
        CURRENT_FILENAME=${CURRENT_FILE##*/}
        CURRENT_TITLE=${CURRENT_FILENAME%.*}
fi
if [ "$CURRENT_BITRATE" == "" ]; then
        CURRENT_BITRATE="6M"
fi
if [ "$CURRENT_AUDIO_PARAMS" == "" ]; then
        CURRENT_AUDIO_PARAMS="copy"
fi
if [ "$CURRENT_GROUP" == "" ]; then
        CURRENT_GROUP="$CURRENT_TITLE"
fi
if [ ! -d "$TARGET_DIR/$CURRENT_GROUP" ]; then
        mkdir -p "$TARGET_DIR/$CURRENT_GROUP"
fi

if [ "$CURRENT_BITRATE" == "copy" ]; then
        FFMPEG_VIDEO_COMMAND="$FFMPEG_COMMAND_COPY"
elif [[ "$CURRENT_BITRATE" == H* ]]; then
        CURRENT_H265=1
        CURRENT_BITRATE="${CURRENT_BITRATE:1}"
        FFMPEG_VIDEO_COMMAND="$FFMPEG_COMMAND_H265"
        if [[ "$CURRENT_EXTRA_PARAMS" != "" ]]; then
                FFMPEG_VIDEO_COMMAND="$FFMPEG_COMMAND_H265_EXTRA"
        fi
elif [[ "$CURRENT_BITRATE" == A* ]]; then
        CURRENT_AV1=1
        CURRENT_BITRATE="${CURRENT_BITRATE:1}"
        FFMPEG_VIDEO_COMMAND="$FFMPEG_COMMAND_AV1"
        if [[ "$CURRENT_EXTRA_PARAMS" != "" ]]; then
                FFMPEG_VIDEO_COMMAND="$FFMPEG_COMMAND_AV1_EXTRA"
        fi
else
        FFMPEG_VIDEO_COMMAND="$FFMPEG_COMMAND_H264"
        if [[ "$CURRENT_EXTRA_PARAMS" != "" ]]; then
                FFMPEG_VIDEO_COMMAND="$FFMPEG_COMMAND_H264_EXTRA"
        fi
fi


CURRENT_VIDEO_STREAM=$(get_video_stream "$CURRENT_FILE")

if [ "$CURRENT_LANG_WHITELIST" != "" ]; then
        while read CURRENT_LINE; do
                MAP_BIGNO=$(echo "$CURRENT_LINE" | sed -r 's/Stream #([0-9]+):([0-9]+).*/\1/g')
                MAP_SMLNO=$(echo "$CURRENT_LINE" | sed -r 's/Stream #[0-9]+:([0-9]+).*/\1/g')
                MAP_LANG=$(echo "$CURRENT_LINE" | sed -r 's/Stream #[0-9]+:[0-9]+\(([a-z]+)\).*/\1/g')
                MAP_TYPE=$(echo "$CURRENT_LINE" | sed -r 's/Stream #[0-9]+:[0-9]+\(?[a-z]*\)?: ([a-zA-Z]+): .*/\1/g')
                if [ "$MAP_TYPE" != "Audio" ]; then
                        SELECTED_STREAMS+="$MAP_BIGNO:$MAP_SMLNO "
                else
                        if [[ "$CURRENT_LANG_WHITELIST" == *"$MAP_LANG"* ]]; then
                                CURRENT_CODEC=$(echo "$CURRENT_LINE" | sed -r 's/Stream #[0-9]+:[0-9]+\([a-z]+\): [a-zA-Z]+: (.*), [0-9]+ Hz.*/\1/g')
                                CURRENT_CODEC_VALUE=$(rate_stream "$CURRENT_CODEC")
                                if [ "$CURRENT_CODEC_VALUE" -gt "${BEST_VALUES[$MAP_LANG]}" ]; then
                                        BEST_VALUES[$MAP_LANG]="$CURRENT_CODEC_VALUE"
                                        BEST_STREAMS[$MAP_LANG]="$MAP_BIGNO:$MAP_SMLNO"
                                fi
                        fi
                fi
        done <<< $(ffmpeg -i "$CURRENT_FILE" &> /dev/stdout | grep "^\s*Stream #")
        for BS in "${BEST_STREAMS[@]}"; do
                SELECTED_STREAMS+="$BS "
        done
        CURRENT_MAP+=$(echo "$SELECTED_STREAMS" | tr " " "\n" | sort -t: -k 1,1n -k 2,2n | tr "\n" "-" | sed "s/-/ -map /g" | sed "s/ -map $//g")
else
        CURRENT_VIDEO_STREAM=$(get_video_stream "$CURRENT_FILE")
        CURRENT_MAP+="-map 0"
fi
CURRENT_MAP+=" -map -$CURRENT_VIDEO_STREAM "

if [ "$CURRENT_BITRATE" = "copy" ]; then
        CURRENT_VIDEO_COMMAND=$(printf "$FFMPEG_VIDEO_COMMAND" "$CURRENT_FILE" "-map $CURRENT_VIDEO_STREAM" "$TARGET_DIR" "$CURRENT_GROUP" "$CURRENT_TITLE")
else
        CURRENT_VIDEO_COMMAND=$(printf "$FFMPEG_VIDEO_COMMAND" "$CURRENT_FILE" "-map $CURRENT_VIDEO_STREAM" "$CURRENT_EXTRA_PARAMS" "$CURRENT_BITRATE" "$TARGET_DIR" "$CURRENT_GROUP" "$CURRENT_TITLE")
fi

CURRENT_AUDIO_COMMAND=$(printf "$FFMPEG_AUDIO_COMMAND" "$CURRENT_FILE" "$CURRENT_MAP" "$CURRENT_AUDIO_PARAMS" "$TARGET_DIR" "$CURRENT_GROUP" "$CURRENT_TITLE")

if [ "$CURRENT_H265" -eq 1 ]; then
        echo -ne "\t\e[96m$CURRENT_TITLE\e[0m (Group: \e[93m$CURRENT_GROUP\e[0m | Bitrate: \e[93m$CURRENT_BITRATE\e[0m \e[5m\e[91mH.265\e[0m | Audio: \e[93m$CURRENT_AUDIO_PARAMS\e[0m"
elif [ "$CURRENT_AV1" -eq 1 ]; then
        echo -ne "\t\e[96m$CURRENT_TITLE\e[0m (Group: \e[93m$CURRENT_GROUP\e[0m | Bitrate: \e[93m$CURRENT_BITRATE\e[0m \e[5m\e[32mAV1\e[0m | Audio: \e[93m$CURRENT_AUDIO_PARAMS\e[0m"
else
        echo -ne "\t\e[96m$CURRENT_TITLE\e[0m (Group: \e[93m$CURRENT_GROUP\e[0m | Bitrate: \e[93m$CURRENT_BITRATE\e[0m | Audio: \e[93m$CURRENT_AUDIO_PARAMS\e[0m"
fi
if [ "$CURRENT_LANG_WHITELIST" != "" ]; then
        echo -ne " | Languages: \e[93m$CURRENT_LANG_WHITELIST\e[0m"
fi
if [ "$CURRENT_EXTRA_PARAMS" == "" ]; then
        echo ")"
else
        echo -e " | extra prm: \e[91m$CURRENT_EXTRA_PARAMS\e[0m)"
fi
echo -e "FFMPEG video command:\n$CURRENT_VIDEO_COMMAND\n"
echo -e "FFMPEG audio command:\n$CURRENT_AUDIO_COMMAND\n"

mkdir -p "$TARGET_DIR/.video/$CURRENT_GROUP"
mkdir -p "$TARGET_DIR/.audio/$CURRENT_GROUP"

if [ "$CURRENT_BITRATE" != "copy" ]; then
        echo 1 > .transcode_block_parallel
        #echo
        #echo "!!! CURRENTLY BLOCKING !!!"
        #echo
        #sleep 100
        eval "$CURRENT_VIDEO_COMMAND"
        SUCCESS=$?
        echo 0 > .transcode_block_parallel
else
        eval "$CURRENT_VIDEO_COMMAND"
        SUCCESS=$?
fi

SUCCESS_COUNT=$(<.transcode_success)
FAIL_COUNT=$(<.transcode_fail)

if [ "$SUCCESS" -ne 0 ]; then
        echo "$(date -u): Failed transcoding video: $CURRENT_FILE (error code: $SUCCESS)" >> transcode_all.log
        let "FAIL_COUNT++"
else
        echo "$(date -u): Successfully transcoded video: $CURRENT_FILE" >> transcode_all.log
        eval "$CURRENT_AUDIO_COMMAND"
        SUCCESS=$?
        if [ "$SUCCESS" -ne 0 ]; then
                echo "$(date -u): Failed transcoding audio: $CURRENT_FILE (error code: $SUCCESS)" >> transcode_all.log
                let "FAIL_COUNT++"
        else
                echo "$(date -u): Successfully transcoded audio: $CURRENT_FILE" >> transcode_all.log
                mkvmerge -o "$TARGET_DIR/$CURRENT_GROUP/$CURRENT_TITLE.mkv" --title "$CURRENT_TITLE" "$TARGET_DIR/.video/$CURRENT_GROUP/$CURRENT_TITLE.mkv" "$TARGET_DIR/.audio/$CURRENT_GROUP/$CURRENT_TITLE.mkv"
                SUCCESS=$?
                if [ "$SUCCESS" -eq 0 ]; then
                        echo "$(date -u): Successfully merged MKV file: $CURRENT_FILE" >> transcode_all.log
                        let "SUCCESS_COUNT++"
                else
                        echo "$(date -u): Failed to merge MKV file: $CURRENT_FILE" >> transcode_all.log
                        let "FAIL_COUNT++"
                fi
        fi
fi

echo "$SUCCESS_COUNT" > .transcode_success
echo "$FAIL_COUNT" > .transcode_fail

unset BEST_STREAMS
unset BEST_VALUES
unset SELECTED_STREAMS
unset CURRENT_MAP
sleep 5
