#!/bin/sh

find /mnt/smb/0/ripomatic/Video/ -type f | grep -v oldshit > .files_list.tmp
FILE_COUNT=$(cat .files_list.tmp | wc -l)
for TR_LINE in `seq "$FILE_COUNT"`
do
        CUR_LINE=$(cat .files_list.tmp | sed -n "$TR_LINE"p)
        CUR_TITLE=$(echo "$CUR_LINE" | sed "s/.*\/\(.*\)\..*/\1/")
        CUR_PATH=$(echo "$CUR_LINE" | sed "s/.*ripomatic\/Video\/\(.*\)\/.*\..*/\1/")
        CUR_VIDEO=$(ffmpeg -i "$CUR_LINE" 2&>/dev/stdout | grep ".*Video:.* [0-9]\+x[0-9]\+.*" | grep -v "attached pic")
        CUR_BITRATE=$(ffmpeg -i "$CUR_LINE" 2&>/dev/stdout | grep "bitrate" | sed "s/.*bitrate: \([0-9]\+\) kb\/s/\1/")
        BETTER_BITRATE=$(ffmpeg -i "$CUR_LINE" &>/dev/stdout | grep -A 2 "Video:" | grep BPS-eng | sed "s/BPS-eng.*: \([0-9]\+\)/\1/")
        if [[ "$BETTER_BITRATE" -gt 0 ]]; then
                let "CUR_BITRATE=$BETTER_BITRATE/1024"
        fi
        CUR_HORIZONTAL=$(echo "$CUR_VIDEO" | sed "s/.*, \([0-9]\+\)x[0-9]\+.*/\1/")
        CUR_VERTICAL=$(echo "$CUR_VIDEO" | sed "s/.*, [0-9]\+x\([0-9]\+\).*/\1/")
        CUR_CODEC=$(echo "$CUR_VIDEO" | sed "s/.*Video: \([a-zA-Z0-9]\+\) .*/\1/")
        echo "$CUR_PATH || $CUR_TITLE: $CUR_VIDEO || $CUR_HORIZONTAL || $CUR_CODEC || $CUR_BITRATE"
        REENCODE=0
        RESIZE=0

        if [ "$CUR_HORIZONTAL" -lt 2000 ]; then
                echo "GO H264!"
                TARGET_CODEC="hevc"
        else
                echo "GO HEVC!"
                TARGET_CODEC="h264"
        fi
        # check if good aspect ratio
        if [ $(($CUR_HORIZONTAL/16*9)) -eq "$CUR_VERTICAL" ]; then
                echo "16:9 - do not resize"
        elif [ $(($CUR_HORIZONTAL/4*3)) -eq "$CUR_VERTICAL" ]; then
                echo "4:3 - do not resize"
        else
                echo "weird aspect ratio - resize!"
                let "SIXTEEN_NINE=$CUR_HORIZONTAL/16*9-$CUR_VERTICAL"
                let "SIXTEEN_NINE/=16"
                let "FOUR_THREE=$CUR_HORIZONTAL/4*3-$CUR_VERTICAL"
                let "FOUR_THREE/=4"
                if [ "$SIXTEEN_NINE" -lt 0 ]; then
                        let "SIXTEEN_NINE*=-1"
                fi
                if [ "$FOUR_THREE" -lt 0 ]; then 
                        let "FOUR_THREE*=-1"
                fi
                echo "16:9 - $SIXTEEN_NINE; 4:3 - $FOUR_THREE"
                if [ "$SIXTEEN_NINE" -le "$FOUR_THREE" ]; then
                        let "TARGET_VERTICAL=$CUR_HORIZONTAL/16*9"
                else
                        let "TARGET_VERTICAL=$CUR_HORIZONTAL/4*3"
                fi
                REENCODE=1
                RESIZE=1
        fi

        # check if good bitrate
        if [ "$CUR_HORIZONTAL" -ge 2000 ]; then
                if [ "$CUR_BITRATE" -gt 20000 ]; then
                        echo "bitrate too high--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="H15M"
                fi
                if [ "$CUR_CODEC" != "hevc" ]; then
                        echo "not hevc yet--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="H15M"
                fi
        elif [ "$CUR_HORIZONTAL" -ge 1300 ]; then
                if [ "$CUR_BITRATE" -gt 8000 ]; then
                        echo "bitrate too high--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="6M"
                fi
                if [ "$CUR_CODEC" != "h264" ]; then
                        echo "not h264 yet--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="6M"
                fi
        elif [ "$CUR_HORIZONTAL" -ge 800 ]; then
                if [ "$CUR_BITRATE" -gt 5000 ]; then
                        echo "bitrate too high--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="4M"
                fi
                if [ "$CUR_CODEC" != "h264" ]; then
                        echo "not h264 yet--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="4M"
                fi
        elif [ "$CUR_HORIZONTAL" -ge 500 ]; then
                if [ "$CUR_BITRATE" -gt 2500 ]; then
                        echo "bitrate too high--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="2M"
                fi
                if [ "$CUR_CODEC" != "h264" ]; then
                        echo "not h264 yet--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="3M"
                fi
        else
                if [ "$CUR_BITRATE" -gt 2000 ]; then
                        echo "bitrate too high--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="1500K"
                fi
                if [ "$CUR_CODEC" != "h264" ]; then
                        echo "not h264 yet--re-encode!"
                        REENCODE=1
                        TARGET_BITRATE="1500K"
                fi
        fi

        if [ "$REENCODE" -eq 0 ]; then
                echo "$CUR_LINE|$CUR_TITLE|$CUR_PATH|copy|libvorbis -qscale:a 6" >> .transcode_list.tmp
        else
                if [ "$RESIZE" -eq 0 ]; then
                        echo "$CUR_LINE|$CUR_TITLE|$CUR_PATH|$TARGET_BITRATE|libvorbis -qscale:a 6" >> .transcode_list.tmp
                else
                        echo "$CUR_LINE|$CUR_TITLE|$CUR_PATH|$TARGET_BITRATE|libvorbis -qscale:a 6||-vf \"scale=$CUR_HORIZONTAL:$TARGET_VERTICAL:force_original_aspect_ratio=decrease,pad=$CUR_HORIZONTAL:$TARGET_VERTICAL:(ow-iw)/2:(oh-ih)/2,setsar=1\"" >> .transcode_list.tmp
                fi
        fi
done
mv .transcode_list.tmp transcode_list.txt
rm .files_list.tmp
