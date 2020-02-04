#!/usr/bin/env bash

baseurl=""
next_frag=""
dl_m3u8=""
naming=""

opts() {
  while test $# -gt 0; do
    case "$1" in
      -h|--help)
        echo "help yourself"
        exit 0
        ;;
      -m)
        shift
        if test $# -gt 0; then
          manifest_link=$1
        else
          echo "wot. gimme m3u link."
          exit 1
        fi
        shift
        ;;
      -d)
        shift
        if test $# -gt 0; then
          ts_folder=$1
        else
            echo "gimme folder pls"
            exit 1
        fi
        shift
        ;;
      -c)
        shift
        if test $# -gt 0; then
          next_frag=$1
        else
          echo "you owe me a frag number"
          exit 1
        fi
        shift
        ;;
      -s)
        shift
        skip_dl="true"
        ;;
      -u)
        shift
        if test $# -gt 0; then
          baseurl=$1
        else
          echo "where the baseurl?"
        fi
        shift
        ;;
      *)
        break
        ;;
    esac
  done
}

naming() {
  name=$1
  if [[ "$name" =~ Frag-[0-9]*-v1-a1 ]]; then
    naming="Frag"
  elif [[ "$name" =~ part[0-9]*.ts ]]; then
    naming="part"
  else
    echo "Unknown naming convention: $name"
    exit 1
  fi
}

clean() {
  if [[ $(ls $ts_folder 2>/dev/null | wc -l) -lt 3 ]]; then
    echo "cleaning dir: $ts_folder"
    rm -rf $ts_folder
  fi
}
trap clean EXIT

combine() {
  echo
  echo "Attempting to combine..."
  while read line; do
    cat $ts_folder/$line >> $ts_folder/combined.ts;
    if [ $? -ne 0 ]; then
      echo "Failed to combine file: $line"
    else
      echo combine: $line
    fi
  done < $tslist_file
}

transcode() {
  echo "Attemping to transcode..."
  pushd $ts_folder
  ffmpeg -i combined.ts -c copy movie.mp4
  popd
}

dl() {
  for url in $urls; do
    name=$(basename $url)
    if [ -z "$name" ]; then
      echo "Failed to get a filename for: $url"
      exit 1
    fi

    naming $name

    curl -s $baseurl/$url -o $ts_folder/$name
    exit_code=$?
    printf .

    if [ $exit_code -ne 0 ]; then
      echo "Failed with code $exit_code"
      printf "Command: [curl -s $baseurl/$url -o $ts_folder/$name]"
        exit $exit_code
    fi
    echo $name >> $tslist_file
  done
}

dl_manifest() {
  curl -s $manifest_link -o manny.m3u8
  if [[ -z "$baseurl" ]]; then
    baseurl=$(dirname $manifest_link)
  fi
}

opts $@
urls=$(cat *.m3u8 | grep -v "^#")
[[ -z "$ts_folder" ]] && ts_folder=$(openssl rand -hex 10)
tslist_file="$ts_folder/tslist.txt"
mkdir -p $ts_folder
if [[ -z "$skip_dl" ]] && [[ -z "$next_frag" ]]; then
  :> $tslist_file
fi
echo "Folder: $ts_folder"
[[ -n "$manifest_link" ]] && dl_manifest
if [[ -z "$baseurl" ]]; then
  echo "gimme baseurl"
  exit 1
fi
[[ -z "$skip_dl" ]] && dl
combine
transcode

