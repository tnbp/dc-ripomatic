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

FFMPEG_COMMAND="ffmpeg -y -v error -hide_banner -stats -i %q %s -c:v h264_nvenc -preset bd -spatial-aq 1 -pix_fmt yuv420p %s -b:v %s -c:a %s -c:s copy -c:d copy -c:t copy %q/%q/%q.mkv"
TARGET_DIR="/mnt/bigvol"

if [ "$1" == "" ]; then
        echo "Usage: transcode_all.sh [LIST_FILE] [[SHUTDOWN=n]]"
        exit 1
fi
if [ ! -f "$1" ]; then
        echo "File not found: $1"
        exit 1
fi

let "SUCCESS_COUNT=0"
let "FAIL_COUNT=0"

FILE_COUNT=$(wc -l < "$1")
echo "### Starting batch of $FILE_COUNT files: $(date -u)" >> transcode_all.log

for TR_LINE in `seq "$FILE_COUNT"`
do
        declare -A BEST_STREAMS
        declare -A BEST_VALUES
        CURRENT_FILE=$(cut -d "|" -f 1 $1 | sed -n "$TR_LINE"p)
        CURRENT_TITLE=$(cut -d "|" -f 2 $1 | sed -n "$TR_LINE"p)
        CURRENT_GROUP=$(cut -d "|" -f 3 $1 | sed -n "$TR_LINE"p)
        CURRENT_BITRATE=$(cut -d "|" -f 4 $1 | sed -n "$TR_LINE"p)
        CURRENT_AUDIO_PARAMS=$(cut -d "|" -f 5 $1 | sed -n "$TR_LINE"p)
        CURRENT_LANG_WHITELIST=$(cut -d "|" -f 6 $1 | sed -n "$TR_LINE"p)
        CURRENT_EXTRA_PARAMS=$(cut -d "|" -f 7 $1 | sed -n "$TR_LINE"p)

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
                CURRENT_MAP="-map 0"
        fi

        CURRENT_COMMAND=$(printf "$FFMPEG_COMMAND" "$CURRENT_FILE" "$CURRENT_MAP" "$CURRENT_EXTRA_PARAMS" "$CURRENT_BITRATE" "$CURRENT_AUDIO_PARAMS" "$TARGET_DIR" "$CURRENT_GROUP" "$CURRENT_TITLE")
        echo -ne "Transcoding file \e[32m#$TR_LINE\e[0m... (of \e[32m$FILE_COUNT\e[0m): \e[96m$CURRENT_TITLE\e[0m (Group: \e[93m$CURRENT_GROUP\e[0m | Bitrate: \e[93m$CURRENT_BITRATE\e[0m | Audio: \e[93m$CURRENT_AUDIO_PARAMS\e[0m"
        if [ "$CURRENT_LANG_WHITELIST" != "" ]; then
                echo -ne " | Languages: \e[93m$CURRENT_LANG_WHITELIST\e[0m"
        fi
        if [ "$CURRENT_EXTRA_PARAMS" == "" ]; then
                echo ")"
        else
                echo -e " | extra prm: \e[91m$CURRENT_EXTRA_PARAMS\e[0m)"
        fi
        #echo "$CURRENT_COMMAND"
        eval "$CURRENT_COMMAND"
        SUCCESS=$?
        if [ "$SUCCESS" -eq 0 ]; then
                echo "$(date -u): Successfully finished transcoding file: $CURRENT_FILE" >> transcode_all.log
                let "SUCCESS_COUNT++"
        else
                echo "$(date -u): Failed transcoding file: $CURRENT_FILE (error code: $SUCCESS)" >> transcode_all.log
                let "FAIL_COUNT++"
        fi
        mkvpropedit "$TARGET_DIR/$CURRENT_GROUP/$CURRENT_TITLE.mkv" --edit info --set "title=$CURRENT_TITLE"
        SUCCESS=$?
        if [ "$SUCCESS" -eq 0 ]; then
                echo "$(date -u): Successfully set title: $CURRENT_TITLE" >> transcode_all.log
        else
                echo "$(date -u): Failed to set title: $CURRENT_TITLE (error code: $SUCCESS)" >> transcode_all.log
        fi
        unset BEST_STREAMS
        unset BEST_VALUES
        unset SELECTED_STREAMS
        unset CURRENT_MAP
        sleep 5
done

echo "### Ending batch of $FILE_COUNT files on $(date -u):" >> transcode_all.log
echo "### SUCCESS: $SUCCESS_COUNT files; FAILED: $FAIL_COUNT files" >> transcode_all.log

if [ "$2" == "n" ]; then
        echo "All done--goodbye! :)"
        exit 0
fi
echo "All done--going to sleep! :)"
sleep 60
echo "### AUTOMATIC SHUTDOWN on $(date -u)"
sudo shutdown -h now
