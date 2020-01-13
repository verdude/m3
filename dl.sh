#!/bin/bash

set -e

opts() {
    while test $# -gt 0; do
      case "$1" in
        -h|--help)
          echo "help yourself"
          exit 0
          ;;
        -d)
          shift
          if test $# -gt 0; then
            export ts_folder=$1
          else
              echo "gimme folder pls"
              exit 1
          fi
          shift
          ;;
        -c)
          shift
          if test $# -gt 0; then
            export next_frag=$1
          else
            echo "you owe me a frag number"
            exit 1
          fi
          shift
          ;;
        *)
          break
          ;;
      esac
    done
}


baseurl=$1
urls=$(cat *.m3u8 | grep -v "^#")
opts
[[ -z "$ts_folder" ]] && ts_folder=$(openssl rand -hex 10)
tslist_file="$ts_folder/tslist.txt"
mkdir -p $ts_folder
:> $tslist_file
echo "Folder: $ts_folder"

clean() {
  if [[ $(ls $ts_folder | wc -l) -lt 3 ]]; then
    echo "cleaning... $ts_folder"
    rm -rf $ts_folder
  fi
}
trap clean EXIT

for url in $urls; do
    name=$(basename $url)
    if [ -z "$name" ]; then
        echo "Failed to get a filename for: $url"
        exit 1
    fi

    if [[ ! "$name" =~ Frag-[0-9]*-v1-a1 ]]; then
        echo "Unknown naming convention: $name"
        exit 1
    fi

    #curl -s $baseurl/$url -o $ts_folder/$name
    printf .

    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Failed with code $exit_code"
        printf "Command: [curl -s $baseurl/$url -o $ts_folder/$name]"
        exit $exit_code
    fi
    echo $name >> $tslist_file
done

echo
echo "Attempting to combine..."
while read line; do
    cat $line >> $ts_folder/combined.ts;
    if [ $? -ne 0 ]; then
      echo "Failed to combine file: $line"
    fi
done < $tslist_file

echo "Attemping to transcode..."
cd $ts_folder
ffmpeg -i combined.ts -c copy movie.mp4

