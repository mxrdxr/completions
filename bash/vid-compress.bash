#!/usr/bin/env bash

vid-compress() {
  local speed=1.25
  local crf=28
  local height=1080
  local disable_audio=true

  local OPTIND opt
  while getopts ":s:c:y:ah-:" opt; do
    if [[ "$opt" == "-" ]]; then
      case "${OPTARG}" in
        help)
          echo "Usage: vid-compress [-s speed] [-c crf] [-y height] [-a] input.mp4 output.mp4"
          echo "Options:"
          echo "  -s SPEED    Set playback speed (default: 1.25)"
          echo "  -c CRF      Set compression level (0-51, higher = more compression, default: 28)"
          echo "  -y HEIGHT   Set output height (default: 1080)"
          echo "  -a          Keep audio (default: no audio)"
          echo "  -h, --help  Show this help"
          return 0
          ;;
        *)
          echo "Invalid option: --${OPTARG}"
          return 1
          ;;
      esac
    fi

    case "$opt" in
      s) speed="$OPTARG" ;;
      c) crf="$OPTARG" ;;
      y)
        if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
          height="$OPTARG"
        else
          echo "Error: Height must be a number"
          return 1
        fi
        ;;
      a) disable_audio=false ;;
      h)
        echo "Usage: vid-compress [-s speed] [-c crf] [-y height] [-a] input.mp4 output.mp4"
        echo "Options:"
        echo "  -s SPEED    Set playback speed (default: 1.25)"
        echo "  -c CRF      Set compression level (0-51, higher = more compression, default: 28)"
        echo "  -y HEIGHT   Set output height (default: 1080)"
        echo "  -a          Keep audio (default: no audio)"
        echo "  -h, --help  Show this help"
        return 0
        ;;
      :)
        echo "Error: Option -$OPTARG requires an argument"
        return 1
        ;;
      \?)
        echo "Invalid option: -$OPTARG"
        return 1
        ;;
    esac
  done

  shift $((OPTIND - 1))

  if [[ $# -lt 1 ]]; then
    echo "Error: Missing input or output file"
    echo "Usage: vid-compress [-s speed] [-c crf] [-y height] [-a] input.mp4 output.mp4"
    return 1
  fi

  local input="$1"
  local output="${2:-${input%.*}-compressed.mp4}"

  if [[ ! -f "$input" ]]; then
    echo "Error: Input file '$input' does not exist"
    return 1
  fi

  local setpts
  setpts=$(awk "BEGIN {printf \"%.3f\", 1/${speed}}")

  local dimensions width height_orig
  dimensions=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$input")
  width=$(echo "$dimensions" | cut -d',' -f1)
  height_orig=$(echo "$dimensions" | cut -d',' -f2)

  echo "Compressing $input to $output..."
  echo "Original dimensions: ${width}x${height_orig}"
  echo "Speed: ${speed}x (setpts: ${setpts})"
  echo "Compression level (CRF): $crf"

  local scale_filter="scale='-2:${height}:force_original_aspect_ratio=decrease:force_divisible_by=2'"
  local pad_filter="pad='width=ceil(iw/2)*2:height=ceil(ih/2)*2:x=(ow-iw)/2:y=(oh-ih)/2'"
  local speed_filter="setpts=${setpts}*PTS"
  local filter_complex="${scale_filter},${pad_filter},${speed_filter}"

  echo "filter_complex: ${filter_complex}"

  local -a audio_opts
  if [[ "$disable_audio" == true ]]; then
    audio_opts=(-an)
  else
    audio_opts=(-c:a aac -b:a 128k -af "atempo=${speed}")
  fi

  ffmpeg -i "$input" \
    -filter_complex "${filter_complex}" \
    -r 30 \
    "${audio_opts[@]}" \
    -c:v libx264 \
    -crf "$crf" \
    -preset fast \
    -profile:v main \
    -level 4.0 \
    -maxrate 1M \
    -bufsize 2M \
    -x264-params "ref=2:weightp=1:subme=6:vbv-bufsize=31250:vbv-maxrate=25000:rc-lookahead=30" \
    -movflags +faststart \
    -threads 0 \
    -y \
    "$output" 2> >(grep -v "deprecated" >&2)

  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    local orig_size new_size
    orig_size=$(du -h "$input" | awk '{print $1}')
    new_size=$(du -h "$output" | awk '{print $1}')

    echo "OK! Compression complete"
    echo "Original: $orig_size → New: $new_size"
  else
    echo "X: Error: FFmpeg exited with status $exit_code"
    return $exit_code
  fi
}

_vid_compress_completions() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  case "$prev" in
    -s) COMPREPLY=($(compgen -W "0.5 0.75 1 1.25 1.5 2" -- "$cur")); return ;;
    -c) COMPREPLY=($(compgen -W "18 20 23 26 28 30 32" -- "$cur")); return ;;
    -y) COMPREPLY=($(compgen -W "480 720 1080 1440 2160" -- "$cur")); return ;;
  esac

  case "$cur" in
    -*)
      COMPREPLY=($(compgen -W "-s -c -y -a -h --help" -- "$cur"))
      return
      ;;
  esac

  COMPREPLY=($(compgen -f -X '!*.@(mp4|mov|mkv|avi)' -- "$cur"))
}

complete -o filenames -F _vid_compress_completions vid-compress
