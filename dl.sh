#!/usr/bin/env bash

baseurl=""
next_frag=""

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



clean() {
  if [[ $(ls $ts_folder | wc -l) -lt 3 ]]; then
    echo "cleaning... $ts_folder"
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

    if [[ ! "$name" =~ Frag-[0-9]*-v1-a1 ]]; then
      echo "Unknown naming convention: $name"
      exit 1
    fi

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

opts $@
if [[ -z "$baseurl" ]]; then
  echo "gimme baseurl"
  exit 1
fi
urls=$(cat *.m3u8 | grep -v "^#")
[[ -z "$ts_folder" ]] && ts_folder=$(openssl rand -hex 10)
tslist_file="$ts_folder/tslist.txt"
mkdir -p $ts_folder
if [[ -z "$skip_dl" ]] && [[ -z "$next_frag" ]]; then
  :> $tslist_file
fi
echo "Folder: $ts_folder"
[[ -z "$skip_dl" ]] && dl
combine
transcode
mv *.m3u8 $ts_folder

