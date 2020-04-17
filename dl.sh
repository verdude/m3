#!/usr/bin/env bash

set -e

baseurl=""
next_frag=""
dl_m3u8=""
naming=""
manifest="$(find . -type f -name "*.m3u8" | head -1)"

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

cleaners() {
  set +e
  if [[ $(ls $ts_folder 2>/dev/null | wc -l) -lt 3 ]]; then
    echo "cleaning dir: $ts_folder"
    rm -rif $ts_folder
  fi
}
trap cleaners EXIT

combine() {
  echo
  echo "Attempting to combine..."
  if [[ ! -f "$tslist_file" ]]; then
    echo "no $tslist_file"
    exit 1
  fi
  while read line; do
    cat $ts_folder/$line >> $ts_folder/combined.ts;
    if [ $? -ne 0 ]; then
      echo "Failed to combine file: $line"
    else
      printf "+"
    fi
  done < $tslist_file
  echo
}

transcode() {
  echo "Attempting to transcode..."
  cd $ts_folder
  ffmpeg -i combined.ts -c copy movie.mp4
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
  if [[ ! -d "$ts_folder" ]]; then
    echo "dir doesn't exist: $ts_folder"
    exit 1
  fi
  manifest="$ts_folder/manny.m3u8"
  curl -s $manifest_link -o "$manifest"
  if [[ -z "$baseurl" ]]; then
    baseurl=$(dirname $manifest_link)
  fi
}

setupdir() {
  [[ -z "$ts_folder" ]] && ts_folder=$(openssl rand -hex 10)
  tslist_file="$ts_folder/tslist.txt"
  mkdir -p $ts_folder
  if [[ -z "$skip_dl" ]] && [[ -z "$next_frag" ]]; then
    :> $tslist_file
  fi
  echo "Folder: $ts_folder"
}

opts $@
setupdir

if [[ -z "$next_frag" ]]; then
  [[ -n "$manifest_link" ]] && dl_manifest
  if [[ -z "$baseurl" ]]; then
    echo "gimme baseurl"
    exit 1
  fi
else
  manifest="$(find $ts_folder -type f -name '*.m3u8' | head -1)"
fi

if [[ -n "$manifest" ]]; then
  if [[ -n "$next_frag" ]]; then
    urls=$(cat "$manifest" | grep -v "^#" | tail -n +$next_frag)
  else
    urls=$(cat "$manifest" | grep -v "^#")
  fi
  echo "#baseurl# $baseurl" >> $manifest
else
  echo "No Manifest found."
  exit 1
fi

if [[ -z "$skip_dl" ]]; then
  dl
fi

combine
transcode
