# dc-ripomatic
Collection of BASH scripts that automatically rip and transcode audio CDs, video DVDs and Blu-ray discs; uses makemkv for video, abcde for audio CDs

## ripomatic.sh
*Automatically identify the type of optical medium in the drive and "rip" to file(s) automatically.*
**requires:** cdda2wav, abcde, ffmpeg, makemkv
**optical drive must be auto-mounted!**
Simply running the script will cause it to try and find out the type of medium, but you can also hint the medium type:
`ripomatic.sh cdda` or `ripomatic.sh dvd` or `ripomatic.sh bluray`
Please edit the script if your optical drive is not found at `/dev/sr0` or to change the target directory.

## transcode_all.sh
*Batch-transcodes a list of video files*
**requires:** ffmpeg with nvenc, mkvpropedit
Script should be invoked followed by a plain-text file containing all files to be transcoded and the transcoding settings.
See [example_filelist.txt](https://github.com/tnbp/dc-ripomatic/blob/master/example_filelist.txt); general format as follows:
`absolute/path/to/file.mkv|Target File Title without Extension|Target/Folder/e.g./Season 1|Quality - H prefix denotes H.265 encoding|audio encoding|languages to be included|additional options`
Please edit the main script (`transcode_all.sh`) to set maximum number of parallel processes (`MAX_NPROC`), the worker script (`.run_transcode.sh`) to change the target directory (`TARGET_DIR`).
