#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd "$SCRIPT_DIR/../.." && pwd)
FIXTURE_ROOT="$REPO_ROOT/Tests/Fixtures/Audio/AppleSpeech"
MANIFEST_PATH="$FIXTURE_ROOT/fixtures.json"

BASE_URL=${SIRIOUS_SPEAK_SWIFTLY_BASE_URL:-http://127.0.0.1:7337}
MP3_BITRATE_KBPS=${SIRIOUS_FIXTURE_MP3_BITRATE_KBPS:-64}
POLL_LIMIT=${SIRIOUS_FIXTURE_POLL_LIMIT:-120}
POLL_SECONDS=${SIRIOUS_FIXTURE_POLL_SECONDS:-1}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Sirious audio fixture generation requires `%s`, but it was not found in PATH.\n' "$1" >&2
        exit 1
    fi
}

http_get() {
    path=$1
    curl --fail --silent --show-error "$BASE_URL$path"
}

post_json_file() {
    path=$1
    payload_path=$2
    curl --fail --silent --show-error \
        --header 'Content-Type: application/json' \
        --data-binary "@$payload_path" \
        "$BASE_URL$path"
}

wait_for_request() {
    request_id=$1
    count=0

    while [ "$count" -lt "$POLL_LIMIT" ]; do
        snapshot=$(http_get "/requests/$request_id")
        status=$(printf '%s' "$snapshot" | jq -r '.status // empty')

        case "$status" in
            completed)
                ok=$(printf '%s' "$snapshot" | jq -r '.terminal_event.ok // true')
                if [ "$ok" != "true" ]; then
                    printf 'SpeakSwiftlyServer request %s completed with a failed terminal event.\n%s\n' "$request_id" "$snapshot" >&2
                    return 1
                fi
                printf '%s' "$snapshot"
                return 0
                ;;
            failed|cancelled)
                printf 'SpeakSwiftlyServer request %s ended with status %s.\n%s\n' "$request_id" "$status" "$snapshot" >&2
                return 1
                ;;
        esac

        count=$((count + 1))
        sleep "$POLL_SECONDS"
    done

    printf 'Timed out waiting for SpeakSwiftlyServer request %s after %s polls.\n' "$request_id" "$POLL_LIMIT" >&2
    return 1
}

duration_seconds() {
    audio_path=$1
    afinfo "$audio_path" | awk -F': ' '
        /estimated duration/ {
            split($2, fields, " ")
            printf "%.3f", fields[1]
            found = 1
        }
        END {
            if (found != 1) {
                exit 1
            }
        }
    '
}

update_manifest_fixture() {
    fixture_id=$1
    duration=$2
    byte_count=$3
    sha256=$4
    temp_manifest=$(mktemp)

    jq \
        --arg id "$fixture_id" \
        --arg sha256 "$sha256" \
        --argjson durationSeconds "$duration" \
        --argjson byteCount "$byte_count" \
        '.fixtures |= map(
            if .id == $id then
                .durationSeconds = $durationSeconds
                | .byteCount = $byteCount
                | .sha256 = $sha256
            else
                .
            end
        )' "$MANIFEST_PATH" >"$temp_manifest"

    mv "$temp_manifest" "$MANIFEST_PATH"
}

require_command afinfo
require_command curl
require_command jq
require_command lame
require_command mktemp
require_command shasum
require_command stat

if [ ! -f "$MANIFEST_PATH" ]; then
    printf 'Sirious audio fixture manifest is missing at %s.\n' "$MANIFEST_PATH" >&2
    exit 1
fi

status_json=$(http_get /status)
backend=$(printf '%s' "$status_json" | jq -r '.speech_backend // "unknown"')
generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
run_id=$(date -u '+%Y%m%dT%H%M%SZ')
sample_rate=""

voices=$(jq -r '[.fixtures[].source.voiceProfile] | unique[]' "$MANIFEST_PATH")
for voice in $voices; do
    payload_path=$(mktemp)
    jq \
        --arg voice "$voice" \
        --arg cwd "$REPO_ROOT" \
        --arg repoRoot "$REPO_ROOT" \
        --arg runID "$run_id" \
        '{
            profile_name: $voice,
            items: [
                .fixtures[]
                | select(.source.voiceProfile == $voice)
                | {
                    artifact_id: ("sirious-" + .id + "-" + $runID),
                    text: .source.text,
                    cwd: $cwd,
                    repo_root: $repoRoot,
                    request_context: {
                        source: "Sirious audio fixture generation",
                        topic: "sirious-audio-fixtures",
                        cwd: $cwd,
                        repo_root: $repoRoot,
                        prefacePolicy: "never",
                        attributes: {
                            "fixture.id": .id,
                            "fixture.voice": .source.voiceProfile,
                            "fixture.phrase": .expectedPhrase,
                            "fixture.route": .intendedRoute
                        }
                    }
                }
            ]
        }' "$MANIFEST_PATH" >"$payload_path"

    response=$(post_json_file /speech/batches "$payload_path")
    rm -f "$payload_path"

    request_id=$(printf '%s' "$response" | jq -r '.request_id')
    printf 'Queued %s fixture batch as SpeakSwiftlyServer request %s.\n' "$voice" "$request_id"
    wait_for_request "$request_id" >/dev/null

    job_json=$(http_get "/generation/jobs/$request_id")
    fixture_ids=$(jq -r --arg voice "$voice" '.fixtures[] | select(.source.voiceProfile == $voice) | .id' "$MANIFEST_PATH")

    for fixture_id in $fixture_ids; do
        fixture_json=$(jq -c --arg id "$fixture_id" '.fixtures[] | select(.id == $id)' "$MANIFEST_PATH")
        artifact_id="sirious-$fixture_id-$run_id"
        output_file=$(printf '%s' "$fixture_json" | jq -r '.file')
        output_path="$FIXTURE_ROOT/$output_file"
        artifact_json=$(printf '%s' "$job_json" | jq -c --arg artifactID "$artifact_id" '.artifacts[] | select(.artifact_id == $artifactID)')
        wav_path=$(printf '%s' "$artifact_json" | jq -r '.file_path')
        artifact_sample_rate=$(printf '%s' "$artifact_json" | jq -r '.sample_rate // empty')

        if [ -z "$wav_path" ] || [ "$wav_path" = "null" ]; then
            printf 'SpeakSwiftlyServer did not return artifact %s for fixture %s.\n' "$artifact_id" "$fixture_id" >&2
            exit 1
        fi
        if [ ! -f "$wav_path" ]; then
            printf 'SpeakSwiftlyServer artifact file for fixture %s does not exist at %s.\n' "$fixture_id" "$wav_path" >&2
            exit 1
        fi

        lame --silent -b "$MP3_BITRATE_KBPS" "$wav_path" "$output_path"
        duration=$(duration_seconds "$output_path")
        byte_count=$(stat -f '%z' "$output_path")
        sha256=$(shasum -a 256 "$output_path" | awk '{ print $1 }')

        update_manifest_fixture "$fixture_id" "$duration" "$byte_count" "$sha256"
        temp_manifest=$(mktemp)
        jq \
            --arg id "$fixture_id" \
            --arg artifactID "$artifact_id" \
            '.fixtures |= map(
                if .id == $id then
                    .source.artifactId = $artifactID
                else
                    .
                end
            )' "$MANIFEST_PATH" >"$temp_manifest"
        mv "$temp_manifest" "$MANIFEST_PATH"

        if [ -n "$artifact_sample_rate" ] && [ "$artifact_sample_rate" != "null" ]; then
            sample_rate="$artifact_sample_rate"
        fi

        printf 'Updated %s from %s.\n' "$fixture_id" "$artifact_id"
    done
done

if [ -z "$sample_rate" ]; then
    sample_rate=$(jq -r '.generator.sampleRate // 24000' "$MANIFEST_PATH")
fi

temp_manifest=$(mktemp)
jq \
    --arg generatedAt "$generated_at" \
    --arg backend "$backend" \
    --argjson sampleRate "$sample_rate" \
    --argjson mp3BitrateKbps "$MP3_BITRATE_KBPS" \
    '.generatedAt = $generatedAt
    | .generator.service = "SpeakSwiftlyServer"
    | .generator.backend = $backend
    | .generator.sampleRate = $sampleRate
    | .generator.sourceFormat = "wav"
    | .generator.checkedInFormat = "mp3"
    | .generator.mp3BitrateKbps = $mp3BitrateKbps' "$MANIFEST_PATH" >"$temp_manifest"
mv "$temp_manifest" "$MANIFEST_PATH"

printf 'Generated Apple Speech fixtures with %s and refreshed %s.\n' "$backend" "$MANIFEST_PATH"
