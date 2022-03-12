#!/bin/sh

MAX_NPROC=4

if [ "$1" == "" ]; then
        echo "Usage: transcode_all.sh [LIST_FILE] [[SHUTDOWN=n]]"
        exit 1
fi
if [ ! -f "$1" ]; then
        echo "File not found: $1"
        exit 1
fi
if [ "$2" == "n" ]; then
        echo "WARNING: SHUTDOWN=n set, remaining powered on after finishing!"
else
        touch .transcode_shutdown
fi

echo "0" > .transcode_success
echo "0" > .transcode_fail
PARALLEL_BLOCKED=0
echo "$PARALLEL_BLOCKED" > .transcode_block_parallel

CUR_NPROC=0

FILE_COUNT=$(wc -l < "$1")
echo "### Starting batch of $FILE_COUNT files: $(date -u)" >> transcode_all.log
echo "--- --- --- --- ---"
echo

for TR_LINE in `seq "$FILE_COUNT"`
do
        echo -e "Transcoding file \e[32m#$TR_LINE\e[0m... (of \e[32m$FILE_COUNT\e[0m):"
        CUR_LINE=$(cat "$1" | sed -n "$TR_LINE"p)
        ./.run_transcode.sh "$CUR_LINE" &
        sleep 2
        PARALLEL_BLOCKED=$(<.transcode_block_parallel)
        CUR_NPROC=$(jobs | grep run_transcode.sh | wc -l)
        while [ "$CUR_NPROC" -ge "$MAX_NPROC" -o "$PARALLEL_BLOCKED" -eq "1" ]
        do
                sleep 5
                CUR_NPROC=$(jobs | grep run_transcode.sh | wc -l)
                PARALLEL_BLOCKED=$(<.transcode_block_parallel)
        done
        echo
        echo
done

while true
do
        FFMPEG_RUNNING="$(pidof ffmpeg)$(pidof mkvpropedit)"
        if [ -z "$FFMPEG_RUNNING" ]; then
                break
        fi
        sleep 5
done

echo
echo "--- --- --- --- ---"
echo "### Ending batch of $FILE_COUNT files on $(date -u):" >> transcode_all.log
SUCCESS_COUNT=$(<.transcode_success)
SUCCESS_FAIL=$(<.transcode_fail)
rm .transcode_success .transcode_fail
echo "### SUCCESS: $SUCCESS_COUNT files; FAILED: $FAIL_COUNT files" >> transcode_all.log

if [ -f .transcode_shutdown ]; then
        rm .transcode*
        echo "All done--going to sleep! :)"
        sleep 60
        echo "### AUTOMATIC SHUTDOWN on $(date -u)"
        sudo shutdown -h now
fi
rm .transcode*
echo "All done--goodbye! :)"
exit 0