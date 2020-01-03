#!/bin/sh

FFMPEG_COMMAND="ffmpeg -y -v error -hide_banner -stats -i %q -map 0 -c:v h264_nvenc -preset bd -b:v %s -c:a copy -c:s copy -c:d copy -c:t copy %q/%q/%q.mkv"
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
        echo "Transcoding file #$TR_LINE... (of $FILE_COUNT)"
        CURRENT_FILE=$(cut -d "|" -f 1 $1 | sed -n "$TR_LINE"p)
        CURRENT_TITLE=$(cut -d "|" -f 2 $1 | sed -n "$TR_LINE"p)
        CURRENT_GROUP=$(cut -d "|" -f 3 $1 | sed -n "$TR_LINE"p)
        CURRENT_BITRATE=$(cut -d "|" -f 4 $1 | sed -n "$TR_LINE"p)
        if [ "$CURRENT_BITRATE" == "" ]; then
                CURRENT_BITRATE="6M"
        fi
        if [ "$CURRENT_GROUP" == "" ]; then
                CURRENT_GROUP="$CURRENT_TITLE"
        fi
        if [ ! -d "$TARGET_DIR/$CURRENT_GROUP" ]; then
                mkdir -p "$TARGET_DIR/$CURRENT_GROUP"
        fi
        CURRENT_COMMAND=$(printf "$FFMPEG_COMMAND" "$CURRENT_FILE" "$CURRENT_BITRATE" "$TARGET_DIR" "$CURRENT_GROUP" "$CURRENT_TITLE")
        echo "Transcoding file #$TR_LINE... (of $FILE_COUNT): $CURRENT_TITLE (Group: $CURRENT_GROUP | Bitrate: $CURRENT_BITRATE)"
        eval "$CURRENT_COMMAND"
        SUCCESS=$?
	if [ "$SUCCESS" -eq 0 ]; then
		echo "$(date -u): Successfully finished transcoding file: $CURRENT_FILE" >> transcode_all.log
		let "SUCCESS_COUNT++"
	else
		echo "$(date -u): Failed transcoding file: $CURRENT_FILE (error code: $SUCCESS)" >> transcode_all.log
		let "FAIL_COUNT++"
	fi
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
