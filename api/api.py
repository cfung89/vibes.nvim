#! /usr/bin/env python3

import os, sys, re, json
from typing import TypeAlias
from pathlib import Path
import googleapiclient.discovery
import googleapiclient.errors

Playlist: TypeAlias = list[dict[str, str|int]]

API_SERVICE_NAME = "youtube"
API_VERSION = "v3"
API_KEY = os.getenv("YT_API_KEY")
assert API_KEY is not None, "API key not found in YT_API_KEY environment variable."

yt = googleapiclient.discovery.build(API_SERVICE_NAME, API_VERSION, developerKey=API_KEY)

def print_error(e: googleapiclient.errors.HttpError, end: str | None = None):
    if type(e.error_details) is list and len(e.error_details) >= 0 and type(e.error_details[0]) is dict:
        print(f"Error: {e.error_details[0].get("message", e.error_details)}.", end=end)
    else:
        print(f"Error: {e.error_details}.", end=end)

def read_duration(duration: str) -> int:
    """
    Convert ISO 8601 duration to number of seconds.
    Returns -1 if error.
    """
    p = re.compile(r"^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$")
    m = p.match(duration)
    if m is None:
        return -1
    hours = int(m.group(1)) if m.group(1) else 0
    minutes = int(m.group(2)) if m.group(2) else 0
    seconds = int(m.group(3)) if m.group(3) else 0
    return hours * 3600 + minutes * 60 + seconds

def get_playlist_name(playlist_id: str) -> str:
    request = yt.playlists().list(
        part="snippet",
        id=playlist_id
    )
    response = request.execute()

    if response.get('items'):
        return response['items'][0]['snippet']['title']
    return "Unknown Playlist"

def get_playlist_vids(playlist_id: str) -> list[str]:
    video_ids = []
    next_page_token = None
    while True:
        request = yt.playlistItems().list(
            part="snippet",
            playlistId=playlist_id,
            maxResults=50,
            pageToken=next_page_token
        )

        try:
            response = request.execute()
            for item in response["items"]:
                video_ids.append(item["snippet"]["resourceId"]["videoId"])

            next_page_token = response.get("nextPageToken")

            if next_page_token is None:
                break
        except googleapiclient.errors.HttpError as e:
            print_error(e, end = "")
            print(" Check if playlist ID is correct.")
    return video_ids

def get_playlist_items(video_ids: list[str]) -> Playlist:
    playlist = []
    for i in range(0, len(video_ids), 50):
        chunk = video_ids[i:i + 50]

        video_request = yt.videos().list(
            part="contentDetails,snippet",
            id=",".join(chunk)
        )

        try:
            video_response = video_request.execute()
            for item in video_response["items"]:
                title = item["snippet"]["title"]
                video_id = item["id"]
                duration = item["contentDetails"]["duration"]
                playlist.append({"id": video_id, "title": title, "duration": read_duration(duration)})
        except googleapiclient.errors.HttpError as e:
            print_error(e)
    return playlist

def get_playlist(playlist_id: str) -> tuple[str, Playlist]:
    """
    Returns the playlist name and its contents.
    """
    name = get_playlist_name(playlist_id)
    video_ids = get_playlist_vids(playlist_id)
    playlist = get_playlist_items(video_ids)
    return name, playlist

if __name__ == "__main__":
    assert len(sys.argv) == 3, "AssertionError: Invalid number of arguments. Output directory and playlist ID required."
    assert len(sys.argv[2]) >= 2, "AssertionError: Invalid argument. Playlist ID required."
    assert sys.argv[2][0:2] == "PL", "AssertionError: Invalid argument. Playlist ID required."
    dir = sys.argv[1]
    Path(dir).mkdir(parents=True, exist_ok=True)
    playlist_id = sys.argv[2]
    name, playlist = get_playlist(playlist_id)
    with open(f"{dir.rstrip('/')}/{name}.json", "w") as f:
        json.dump({"id": playlist_id, "playlist": playlist}, f)

