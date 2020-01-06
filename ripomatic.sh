#!/bin/sh

is_audio_cd=$(cdda2wav -J -H -D /dev/sr0 2&>/dev/stdout | grep 'disk has no audio tracks' | wc -c)
if [ "$is_audio_cd" -le 1 ]; then
	echo "That's an audio CD!"
	abcde -N
	exitcode="$?"
	chmod 0770 -R /mnt/servervol/ripomatic/Musik/
	exit "$exitcode"
else
	echo "That's not an audio CD!"
fi

is_dvd=$(dvd+rw-mediainfo /dev/sr0 | grep "DVD-ROM book" | wc -c)
if [ "$is_dvd" -gt 1 ]; then
	echo "That's a DVD!"
	is_video_dvd=$(mplayer -identify -frames 0 /dev/sr0 2>&1 | grep VIDEO: | grep MPEG2 | wc -c)
	if [ "$is_video_dvd" -le 1 ]; then
		is_video_dvd=$(ffmpeg -i /dev/sr0 2>&1 | grep dvd_nav_packet | wc -c)
		if [ "$is_video_dvd" -le 1 ]; then
			echo "Uuh... I can't tell if it is a video DVD..."
			is_video_dvd=$(ls /mnt/sr0/VIDEO_TS | wc -l)
			if [ "$is_video_dvd" -gt 0 ]; then
				echo "But it seems to have the files for a video DVD, so... I'll try my best! >:3"
				is_video_dvd="99"
			else
				echo "That's not a video DVD!"
			fi
		fi
	fi
fi
if [ "$is_video_dvd" -gt 1 ]; then
	echo "That's a video DVD!"
	targetdir="/mnt/servervol/ripomatic/Video/$(date +%s)-dvd"
	mkdir -p "$targetdir"
	makemkvcon --decrypt --minlength=1000 mkv disc:0 all "$targetdir"
	exitcode="$?"
	chmod 0777 "$targetdir"
	exit "$exitcode"
else
	echo "That's not a video DVD!"
fi

is_bluray=$(dvd+rw-mediainfo /dev/sr0 2>&1 | grep BD-ROM | wc -c)
if [ "$is_bluray" -gt 1 ]; then
	echo "That's a Blu-ray!"
	if [ -d /mnt/sr0/BDMV ]; then
		echo "That's a Blu-ray video disc!"
		targetdir="/mnt/servervol/ripomatic/Video/$(date +%s)-bluray"
        	mkdir -p "$targetdir"
        	makemkvcon --decrypt --minlength=1000 mkv disc:0 all "$targetdir"
		exitcode="$?"
		chmod 0777 "$targetdir"
		exit "$exitcode"
	else
		echo "But it's not a Blu-ray video disc!"
	fi
else
	echo "That's not a Blu-ray!"
fi

echo "Sorry, I don't know what to do with this thing... :("
exit 1
