from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import yt_dlp
import re
import requests
import urllib.parse


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ExtractRequest(BaseModel):
    url_text: str


def find_first_url(text: str) -> str | None:
    pattern = re.compile(r"https?://[^\s]+")
    match = pattern.search(text)
    return match.group(0) if match else None


@app.get("/")
def root():
    return {"status": "ok", "message": "Video extractor backend is running"}


@app.post("/api/extract")
def extract_video(request: ExtractRequest):
    target_url = find_first_url(request.url_text)

    if not target_url:
        raise HTTPException(status_code=400, detail="没有找到有效链接")

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "nocheckcertificate": True,
        "format": "best[ext=mp4]/best",
        "skip_download": True,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(target_url, download=False)

        video_url = info.get("url")

        if not video_url and info.get("formats"):
            formats = info["formats"]
            usable_formats = [
                f for f in formats
                if f.get("url") and f.get("vcodec") != "none"
            ]

            if usable_formats:
                usable_formats.sort(
                    key=lambda f: f.get("height") or 0,
                    reverse=True
                )
                video_url = usable_formats[0].get("url")

        if not video_url:
            raise HTTPException(status_code=400, detail="解析成功，但没有找到可播放视频地址")

        return {
            "title": info.get("title") or "未命名视频",
            "cover_url": info.get("thumbnail") or "",
            "video_url": video_url,
            "source_url": target_url,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"解析失败: {str(e)}")


@app.get("/api/download")
def proxy_download(url: str, title: str = "video"):
    headers = {
        "User-Agent": "Mozilla/5.0",
    }

    try:
        req = requests.get(url, headers=headers, stream=True, timeout=30)
        req.raise_for_status()

        def iterfile():
            for chunk in req.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    yield chunk

        safe_title = urllib.parse.quote(title)

        return StreamingResponse(
            iterfile(),
            media_type="application/octet-stream",
            headers={
                "Content-Disposition": f"attachment; filename*=UTF-8''{safe_title}.mp4"
            },
        )

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"下载失败: {str(e)}")
